import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../core/logger.dart';
import '../data/http_client.dart';
import 'speed_limiter.dart';

/// 取消令牌：暂停 / 删除任务时置位，下载循环会尽快退出。
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class SegmentResult {
  const SegmentResult({
    required this.totalBytes,
    required this.downloadedBytes,
    required this.supportRange,
    this.fallbackReason,
  });

  final int totalBytes;
  final int downloadedBytes;
  final bool supportRange;

  /// 回退单线程下载时的原因（探测证据），正常分片下载为 null。
  final String? fallbackReason;
}

/// 服务器忽略了 Range 请求、返回了完整文件。
///
/// 响应体本身就是完整文件，由 [SegmentDownloader.download] 统一回退成
/// 单线程下载消费掉，而不是把整文件错当分片追加出损坏产物。
class _RangeIgnored implements Exception {
  _RangeIgnored(this.response);

  final HttpClientResponse response;
}

/// HTTP 错误分类：决定「立刻失败 / 退避重试 / 刷新 URL」。
enum DownloadErrorKind {
  /// 退避后重试
  retryable,

  /// 播放地址可能过期，应重新解析 playurl
  urlExpired,

  /// 重试也没用，直接失败（如磁盘满、权限错误、4xx 参数错误）
  fatal,
}

class _Part {
  _Part(
      {required this.index,
      required this.start,
      required this.end,
      required this.path});

  final int index;
  final int start;
  final int end;
  final String path;
  int done = 0;

  int get size => end - start + 1;
}

class _Probe {
  _Probe({required this.totalBytes, this.pending});

  final int totalBytes;

  /// 服务端不支持 Range 时，直接把探测用的响应体消费掉
  final HttpClientResponse? pending;
}

/// 单文件多线程分片下载器。
///
/// 每个分片写入独立的 `.partN` 文件，全部完成后再顺序拼接到目标文件。
/// 断点续传只需看 part 文件大小，天然避免多线程写同一文件句柄的错位问题。
///
/// v1.8 强化的四件事（都是「文件损坏但 UI 显示成功」的源头）：
/// 1. **Range 响应严格校验**：206 必须核对 `Content-Range` 的起止与总长；
///    除「单分片且从 0 开始」外，收到 200 一律判为错误——那是完整文件，
///    追加进 `.part` 会直接产出损坏文件。
/// 2. **拼接前校验每个分片**：缺失或长度不符立即中止，绝不静默跳过；
///    拼接后再核对输出长度，不一致就删掉损坏产物并抛错。
/// 3. **读空闲超时**：连接成功但服务端停止发送数据（TCP 不断开）时，
///    30 秒无数据即断开重连，而不是无限等待。
/// 4. **URL 过期自动刷新**：403 / 404 / 410 时调用 [refreshUrl] 拿新地址，
///    **保留已完成的 part**，从断点继续，不重下已下载的数据。
class SegmentDownloader {
  SegmentDownloader({
    required String url,
    required this.filePath,
    required this.segmentCount,
    required this.concurrency,
    this.referer,
    this.resumeState = '',
    this.refreshUrl,
    this.readIdleTimeout = defaultReadIdleTimeout,
    this.responseTimeout = defaultResponseTimeout,
    this.maxAttempts = defaultMaxAttempts,
    this.baseBackoff = defaultBaseBackoff,
    this.limiter,
  }) : _url = url;

  String _url;
  final String filePath;
  final int segmentCount;
  final int concurrency;
  final String? referer;

  /// 限速器（所有分片共用一个实例，限的是整个任务的总速度）
  final SpeedLimiter? limiter;

  /// 上次下载时记录的签名（总大小:分片大小:分片数），不一致则丢弃旧分片。
  final String resumeState;

  /// URL 过期时的刷新回调，返回新的播放地址；返回 null 表示无法刷新。
  final Future<String?> Function()? refreshUrl;

  /// 读空闲超时：连续这么久没有收到任何数据就断开重连
  final Duration readIdleTimeout;

  /// 等待响应头的超时
  final Duration responseTimeout;

  /// 单个分片的最大尝试次数
  final int maxAttempts;

  /// 指数退避的基准间隔（实际会叠加 0~500ms 抖动）
  final Duration baseBackoff;

  // 生产默认值。做成可注入是为了能单测「读空闲超时」与「重试耗尽」这两条路径——
  // 默认参数下一次测试要跑一分多钟，不现实。
  static const Duration defaultReadIdleTimeout = Duration(seconds: 30);
  static const Duration defaultResponseTimeout = Duration(seconds: 30);
  static const int defaultMaxAttempts = 8;
  static const Duration defaultBaseBackoff = Duration(milliseconds: 500);

  final math.Random _random = math.Random();

  int _total = 0;
  Future<bool>? _refreshing;
  Uri get _uri => Uri.parse(_url);

  String _partPath(int index) => '$filePath.part$index';

  /// 按 HTTP 状态码判定处理方式
  static DownloadErrorKind classifyStatus(int status) {
    return switch (status) {
      403 || 404 || 410 => DownloadErrorKind.urlExpired,
      408 || 429 || 500 || 502 || 503 || 504 => DownloadErrorKind.retryable,
      416 => DownloadErrorKind.retryable,
      _ =>
        status >= 500 ? DownloadErrorKind.retryable : DownloadErrorKind.fatal,
    };
  }

  Future<SegmentResult> download({
    required void Function(int total) onTotal,
    required void Function(int downloaded) onProgress,
    required void Function(String state) onState,
    required CancelToken token,
  }) async {
    final client = AppHttp.instance
        .createDownloadClient(maxConnectionsPerHost: concurrency + 2);
    final parts = <_Part>[];
    try {
      final probe = await _probe(client);
      final total = probe.totalBytes;
      _total = total;

      if (probe.pending != null) {
        // 探测收到 200：服务器不支持 Range。保留证据后回退单线程下载，
        // 产物写入 .part0（中断后保留，支持续传的服务器上可从断点继续）。
        const reason = '服务器不支持 Range（探测返回 200），已回退单线程下载';
        AppLog.w('Download', reason);
        final (written, completed) = await _consumeStream(
          probe.pending!,
          onProgress,
          token,
          expectedLength: probe.pending!.headers.contentLength,
        );
        onTotal(written);
        if (!completed && !token.isCancelled) {
          // 服务端提前断流：宁可报错重试，也不能把半截文件当成功
          throw ApiException(-1, '下载不完整（收到 $written 字节），请重试', _url);
        }
        if (completed) await _finishSequential();
        return SegmentResult(
            totalBytes: written,
            downloadedBytes: written,
            supportRange: false,
            fallbackReason: reason);
      }

      onTotal(total);
      if (total <= 0) {
        // 没拿到文件长度：单线程下载（.part0 支持断点续传）
        final (written, completed) =
            await _downloadSequential(client, onProgress, token);
        onTotal(written);
        if (!completed && !token.isCancelled) {
          throw ApiException(-1, '下载不完整（收到 $written 字节），请重试', _url);
        }
        if (completed) await _finishSequential();
        return SegmentResult(
            totalBytes: written,
            downloadedBytes: written,
            supportRange: false,
            fallbackReason: completed ? '服务器未返回文件长度，已用单线程下载' : null);
      }

      final count = math.max(1, math.min(segmentCount, 16));
      final chunk = (total + count - 1) ~/ count;
      final signature = '$total:$chunk:$count';
      onState(signature);

      for (var index = 0; index < count; index++) {
        final start = index * chunk;
        if (start >= total) break;
        final end = math.min(total - 1, start + chunk - 1);
        parts.add(_Part(
            index: index, start: start, end: end, path: _partPath(index)));
      }

      if (resumeState != signature) {
        // 播放地址变了（总大小不同），旧分片作废
        for (final part in parts) {
          part.done = 0;
          await _safeDelete(part.path);
        }
      } else {
        for (final part in parts) {
          part.done = await _lengthOf(part.path);
          if (part.done > part.size) {
            await _safeDelete(part.path);
            part.done = 0;
          }
        }
      }

      var lastReport = 0;
      void report() {
        final downloaded = parts.fold<int>(0, (sum, part) => sum + part.done);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (downloaded - lastReport > 64 * 1024 || now - lastReport > 0) {
          lastReport = downloaded;
          onProgress(downloaded);
        }
      }

      report();
      _RangeIgnored? rangeIgnored;
      try {
        await _runPool<_Part>(parts, concurrency, (part) async {
          if (part.done >= part.size) return;
          await _downloadPart(client, part, token, report);
        });
      } on _RangeIgnored catch (error) {
        rangeIgnored = error;
      }

      if (rangeIgnored != null) {
        // 下载途中服务器开始忽略 Range（返回完整文件）：丢弃全部分片，
        // 把已拿到的完整响应体回退成单线程下载落盘（对应桌面版的
        // 「媒体拒绝 Range 时回退，顺序回退保留断点」）。
        const reason = '下载途中服务器忽略 Range，已回退单线程下载';
        AppLog.w('Download', reason);
        for (final part in parts) {
          await _safeDelete(part.path);
        }
        final (written, completed) = await _consumeStream(
          rangeIgnored.response,
          onProgress,
          token,
          expectedLength: _total,
        );
        onTotal(written);
        if (!completed && !token.isCancelled) {
          throw ApiException(-1, '下载不完整（收到 $written 字节），请重试', _url);
        }
        if (completed) await _finishSequential();
        return SegmentResult(
            totalBytes: written,
            downloadedBytes: written,
            supportRange: false,
            fallbackReason: reason);
      }

      if (token.isCancelled) {
        return SegmentResult(
          totalBytes: total,
          downloadedBytes: parts.fold<int>(0, (sum, part) => sum + part.done),
          supportRange: true,
        );
      }

      // 拼接前会逐片校验，拼接后再核对总长；任何不一致都会抛错而不是「成功」
      await _concat(parts, filePath, total);
      return SegmentResult(
          totalBytes: total, downloadedBytes: total, supportRange: true);
    } finally {
      client.close(force: true);
    }
  }

  // ------------------------------------------------------------------
  // 内部实现
  // ------------------------------------------------------------------

  Future<_Probe> _probe(HttpClient client) async {
    // 探测阶段同样要处理 URL 过期：播放地址在「解析出地址」到「真正开始下载」
    // 之间就可能失效（尤其订阅的后台任务、用户点下载后又等了很久），
    // 这里直接抛错的话刷新逻辑（写在 _downloadPart 里）永远走不到。
    var refreshes = 0;
    while (true) {
      final request = await AppHttp.instance.openRequest(
        client,
        _uri,
        rangeStart: 0,
        rangeEnd: 0,
        referer: referer,
      );
      final response = await request.close().timeout(responseTimeout);
      final status = response.statusCode;

      if (classifyStatus(status) == DownloadErrorKind.urlExpired &&
          refreshes < 3) {
        await response.drain<void>();
        if (await _tryRefreshUrl()) {
          refreshes++;
          continue;
        }
        throw ApiException(status, 'HTTP $status', _url);
      }

      final contentRange =
          response.headers.value(HttpHeaders.contentRangeHeader);
      if (status == 206) {
        var total = 0;
        if (contentRange != null && contentRange.contains('/')) {
          total = int.tryParse(contentRange.split('/').last) ?? 0;
        }
        await response.drain<void>();
        return _Probe(totalBytes: total);
      }
      if (status != 200) {
        await response.drain<void>();
        throw ApiException(status, 'HTTP $status', _url);
      }
      // 不支持 Range：保留响应体，直接顺序下载
      return _Probe(totalBytes: 0, pending: response);
    }
  }

  /// 顺序写入 `.part0`，完整收完后由 [_finishSequential] 改名成目标文件。
  ///
  /// [resumeFrom] > 0 表示从该字节数续传（追加写）；否则从头写（截断）。
  /// 中断时保留 `.part0`，下次下载可尝试续传——对应桌面版
  /// 「顺序回退时保留断点续传状态」。[expectedLength] > 0 时会核对总字节数，
  /// 收不够不算完成（防止「服务端提前断开却当成功」）。
  Future<(int, bool)> _consumeStream(
    Stream<List<int>> stream,
    void Function(int downloaded) onProgress,
    CancelToken token, {
    int resumeFrom = 0,
    int expectedLength = 0,
  }) async {
    final partFile = File(_partPath(0));
    await partFile.parent.create(recursive: true);
    final sink = partFile.openWrite(
        mode: resumeFrom > 0 ? FileMode.append : FileMode.write);
    var written = resumeFrom;
    var cancelled = false;
    try {
      await for (final chunk in stream.timeout(readIdleTimeout)) {
        if (token.isCancelled) {
          cancelled = true;
          break;
        }
        sink.add(chunk);
        written += chunk.length;
        onProgress(written);
        final wait = limiter?.consume(chunk.length) ?? Duration.zero;
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
      }
    } finally {
      try {
        await sink.flush();
      } catch (_) {
        // 忽略
      }
      try {
        await sink.close();
      } catch (_) {
        // 忽略
      }
    }
    if (cancelled || token.isCancelled) return (written, false);
    if (expectedLength > 0 && written != expectedLength) {
      // 服务端提前断开：保留 .part0 供续传，但不能算完成
      return (written, false);
    }
    return (written, true);
  }

  /// 顺序单线程下载：`.part0` 已有数据时先尝试 Range 续传；
  /// 服务器不支持（200 或起点不符）就重头下载，绝不会拼出损坏文件。
  Future<(int, bool)> _downloadSequential(
    HttpClient client,
    void Function(int downloaded) onProgress,
    CancelToken token, {
    int refreshes = 0,
  }) async {
    final have = await _lengthOf(_partPath(0));
    if (have > 0) {
      final request = await AppHttp.instance.openRequest(
        client,
        _uri,
        rangeStart: have,
        referer: referer,
      );
      final response = await request.close().timeout(responseTimeout);
      final status = response.statusCode;
      if (status == 206) {
        final contentRange =
            response.headers.value(HttpHeaders.contentRangeHeader);
        final parsed =
            contentRange == null ? null : _parseContentRange(contentRange);
        if (parsed != null && parsed.start == have) {
          AppLog.d('Download', '顺序下载从 $have 字节处续传');
          return _consumeStream(response, onProgress, token, resumeFrom: have);
        }
        // 起点不符：当作无法续传，重头下载
        await response.drain<void>();
      } else if (status == 200) {
        // 服务器忽略 Range：重头下载（数据从 0 重新写，不会拼坏）
        return _consumeStream(response, onProgress, token);
      } else if (classifyStatus(status) == DownloadErrorKind.urlExpired &&
          refreshes < 3 &&
          await _tryRefreshUrl()) {
        return _downloadSequential(client, onProgress, token,
            refreshes: refreshes + 1);
      } else {
        await response.drain<void>();
        throw ApiException(status, 'HTTP $status', _url);
      }
    }
    final request =
        await AppHttp.instance.openRequest(client, _uri, referer: referer);
    final response = await request.close().timeout(responseTimeout);
    if (response.statusCode != 200 && response.statusCode != 206) {
      await response.drain<void>();
      throw ApiException(
          response.statusCode, 'HTTP ${response.statusCode}', _url);
    }
    return _consumeStream(response, onProgress, token);
  }

  /// 顺序下载完整收完后，把 `.part0` 改名成目标文件。
  Future<void> _finishSequential() async {
    final partFile = File(_partPath(0));
    if (!await partFile.exists()) return;
    if (await File(filePath).exists()) {
      await _safeDelete(filePath);
    }
    await partFile.rename(filePath);
  }

  Future<void> _downloadPart(
    HttpClient client,
    _Part part,
    CancelToken token,
    void Function() report,
  ) async {
    var attempts = 0;
    var refreshes = 0;
    while (part.done < part.size && !token.isCancelled) {
      try {
        final start = part.start + part.done;
        final request = await AppHttp.instance.openRequest(
          client,
          _uri,
          rangeStart: start,
          rangeEnd: part.end,
          referer: referer,
        );
        final response = await request.close().timeout(responseTimeout);
        _validateRange(response, part, start);

        final sink = File(part.path).openWrite(mode: FileMode.append);
        try {
          // 读空闲超时：服务端停止发送数据时断开，而不是无限挂住
          await for (final chunk in response.timeout(readIdleTimeout)) {
            if (token.isCancelled) break;
            sink.add(chunk);
            part.done += chunk.length;
            if (part.done > part.size) {
              throw ApiException(-1, '分片 ${part.index} 收到的数据超出了请求范围', _url);
            }
            report();
            final wait = limiter?.consume(chunk.length) ?? Duration.zero;
            if (wait > Duration.zero) {
              await Future<void>.delayed(wait);
            }
          }
          await sink.flush();
        } finally {
          try {
            await sink.close();
          } catch (_) {
            // 忽略
          }
        }
        if (token.isCancelled) return;
        if (part.done >= part.size) return;
        // 服务端提前结束但数据不足：以磁盘实际长度为准后重试
        part.done = await _lengthOf(part.path);
        await _discardOversized(part);
        attempts++;
        if (attempts >= maxAttempts) {
          throw ApiException(
              -1, '分片 ${part.index} 数据不足（${part.done}/${part.size}）', _url);
        }
        await Future<void>.delayed(_backoff(attempts));
      } catch (error) {
        if (token.isCancelled) return;

        // 服务器忽略 Range：交给 download() 统一回退，不在这里重试
        if (error is _RangeIgnored) rethrow;

        // 416：本地分片可能已经完整，核对后直接放过
        if (error is ApiException && error.code == 416) {
          final length = await _lengthOf(part.path);
          if (length == part.size) {
            part.done = length;
            report();
            return;
          }
          await _safeDelete(part.path);
          part.done = 0;
        }

        // URL 过期：刷新地址后保留已下载分片继续
        final kind = error is ApiException
            ? classifyStatus(error.code)
            : DownloadErrorKind.retryable;
        if (kind == DownloadErrorKind.urlExpired && refreshes < 3) {
          final refreshed = await _tryRefreshUrl();
          if (refreshed) {
            refreshes++;
            attempts = 0;
            AppLog.d('Download', '分片 ${part.index} 改用刷新后的播放地址继续');
            continue;
          }
        }
        if (kind == DownloadErrorKind.fatal) {
          AppLog.e('Download', '分片 ${part.index} 不可重试的错误', error);
          rethrow;
        }

        attempts++;
        AppLog.e('Download', '分片 ${part.index} 第 $attempts 次重试', error);
        if (attempts >= maxAttempts) throw _normalize(error, part);
        await Future<void>.delayed(_backoff(attempts));
        // 以磁盘实际长度为准，避免失败时账目偏移
        part.done = await _lengthOf(part.path);
        await _discardOversized(part);
        report();
      }
    }
  }

  /// 严格校验 Range 响应
  ///
  /// - `206`：必须带 `Content-Range`，其 START 必须等于请求的 START，
  ///   END 不能超出请求的 END，TOTAL 必须与探测结果一致；
  /// - `200`：那是**完整文件**。只有「单分片、从 0 开始、且分片长度等于总长」
  ///   这一种情况可以接受，其余情况抛 [_RangeIgnored]（携带响应体），
  ///   由 download() 回退成单线程下载消费掉，绝不把完整文件追加进 `.part`；
  /// - 其它状态码交给错误分类处理。
  void _validateRange(
      HttpClientResponse response, _Part part, int requestedStart) {
    final status = response.statusCode;
    if (status == 200) {
      final isWholeFileSinglePart = part.index == 0 &&
          requestedStart == 0 &&
          part.size == _total &&
          _total > 0;
      if (!isWholeFileSinglePart) {
        // 响应体就是完整文件：交给 download() 回退单线程消费
        throw _RangeIgnored(response);
      }
      return;
    }
    if (status != 206) {
      throw ApiException(status, 'HTTP $status', _url);
    }

    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange == null) {
      throw ApiException(206, '206 响应缺少 Content-Range 头', _url);
    }
    final parsed = _parseContentRange(contentRange);
    if (parsed == null) {
      throw ApiException(206, 'Content-Range 格式无法解析：$contentRange', _url);
    }
    if (parsed.start != requestedStart) {
      throw ApiException(
        206,
        'Content-Range 起点不符：请求 $requestedStart，返回 ${parsed.start}',
        _url,
      );
    }
    if (parsed.end > part.end) {
      throw ApiException(
        206,
        'Content-Range 终点越界：请求到 ${part.end}，返回 ${parsed.end}',
        _url,
      );
    }
    if (parsed.total > 0 && _total > 0 && parsed.total != _total) {
      throw ApiException(
        206,
        'Content-Range 总长变化：原 $_total，现 ${parsed.total}',
        _url,
      );
    }
  }

  static ({int start, int end, int total})? _parseContentRange(String value) {
    // bytes 1000-1999/3000
    final match = RegExp(r'bytes\s+(\d+)-(\d+)/(\d+|\*)').firstMatch(value);
    if (match == null) return null;
    final start = int.tryParse(match.group(1) ?? '');
    final end = int.tryParse(match.group(2) ?? '');
    if (start == null || end == null) return null;
    final total = int.tryParse(match.group(3) ?? '') ?? 0;
    return (start: start, end: end, total: total);
  }

  /// 把底层异常统一成带可读信息的 [ApiException]。
  ///
  /// `Stream.timeout` 抛的是裸 `TimeoutException`，直接冒泡到上层的话，
  /// 用户在任务列表里看到的是 `TimeoutException after 0:00:00.4: No stream event`，
  /// 既看不懂也不知道该做什么。文档明确要求这种情况提示「下载停滞，正在重新连接」。
  ApiException _normalize(Object error, _Part part) {
    if (error is ApiException) return error;
    if (error is TimeoutException) {
      return ApiException(
        -3,
        '分片 ${part.index} 下载停滞（${readIdleTimeout.inMilliseconds} 毫秒无数据），已断开重连',
        _url,
      );
    }
    return ApiException(-2, '分片 ${part.index} 下载失败：$error', _url);
  }

  Future<void> _discardOversized(_Part part) async {
    if (part.done > part.size) {
      await _safeDelete(part.path);
      part.done = 0;
    }
  }

  /// 指数退避 + 抖动，避免多分片同时重试打爆服务端。
  ///
  /// 抖动幅度跟随基准间隔缩放，这样把 baseBackoff 调小时整条退避链路
  /// 跟着变快（测试用），而线上仍是「基准的 0~1 倍」随机抖动。
  Duration _backoff(int attempt) {
    final step = math.max(1, baseBackoff.inMilliseconds);
    final exponent = math.min(attempt - 1, 6);
    final base = math.min(step * 64, step * (1 << exponent));
    return Duration(milliseconds: base + _random.nextInt(step));
  }

  Future<bool> _tryRefreshUrl() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final future = _doRefreshUrl();
    _refreshing = future;
    future.whenComplete(() {
      _refreshing = null;
    });
    return future;
  }

  Future<bool> _doRefreshUrl() async {
    final callback = refreshUrl;
    if (callback == null) return false;
    try {
      final fresh = await callback();
      if (fresh == null || fresh.isEmpty || fresh == _url) return false;
      _url = fresh;
      return true;
    } catch (error) {
      AppLog.e('Download', '刷新播放地址失败', error);
      return false;
    }
  }

  /// 拼接分片，并在拼接前后做完整性校验。
  ///
  /// 早先的实现对缺失分片直接 `continue`，于是 `part0 + part1 + part3` 也会被
  /// 当成成功文件交付。现在任何一片缺失或长度不符都会中止，拼接后再核对总长。
  Future<void> _concat(
      List<_Part> parts, String outputPath, int expectedTotal) async {
    final broken = <String>[];
    for (final part in parts) {
      final file = File(part.path);
      if (!await file.exists()) {
        broken.add('分片 ${part.index} 缺失');
        continue;
      }
      final length = await file.length();
      if (length != part.size) {
        broken.add('分片 ${part.index} 长度异常（$length ≠ ${part.size}）');
      }
    }
    if (broken.isNotEmpty) {
      throw ApiException(-1, '分片不完整，已中止合并：${broken.take(4).join('、')}', _url);
    }

    final output = File(outputPath);
    await output.parent.create(recursive: true);
    final sink = output.openWrite();
    try {
      for (final part in parts) {
        await sink.addStream(File(part.path).openRead());
      }
      await sink.flush();
    } finally {
      try {
        await sink.close();
      } catch (_) {
        // 忽略
      }
    }

    final actual = await output.length();
    if (actual != expectedTotal) {
      await _safeDelete(outputPath);
      throw ApiException(
        -1,
        '合并后文件大小异常（$actual ≠ $expectedTotal），已丢弃损坏文件',
        _url,
      );
    }

    for (final part in parts) {
      await _safeDelete(part.path);
    }
  }

  /// 简易协程池：concurrency 个 worker 抢任务
  Future<void> _runPool<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) worker,
  ) async {
    if (items.isEmpty) return;
    var cursor = 0;
    final workers = <Future<void>>[];
    final workerCount = math.max(1, math.min(concurrency, items.length));
    for (var index = 0; index < workerCount; index++) {
      workers.add(() async {
        while (cursor < items.length) {
          final item = items[cursor++];
          await worker(item);
        }
      }());
    }
    await Future.wait(workers);
  }

  Future<int> _lengthOf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 0;
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略
    }
  }

  /// 清理所有分片（任务被删除时调用）
  static Future<void> cleanParts(String filePath, {int maxParts = 16}) async {
    for (var index = 0; index < maxParts; index++) {
      try {
        final file = File('$filePath.part$index');
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 忽略
      }
    }
  }
}
