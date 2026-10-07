import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../core/logger.dart';
import '../data/http_client.dart';

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
  });

  final int totalBytes;
  final int downloadedBytes;
  final bool supportRange;
}

class _Part {
  _Part({required this.index, required this.start, required this.end, required this.path});

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
/// 这样做的好处：断点续传只需要看 part 文件的大小，天然避免多线程写同一文件句柄的错位问题。
class SegmentDownloader {
  SegmentDownloader({
    required this.url,
    required this.filePath,
    required this.segmentCount,
    required this.concurrency,
    this.referer,
    this.resumeState = '',
  });

  final String url;
  final String filePath;
  final int segmentCount;
  final int concurrency;
  final String? referer;

  /// 上次下载时记录的签名（总大小:分片大小:分片数），不一致则丢弃旧分片。
  final String resumeState;

  Uri get _uri => Uri.parse(url);

  String _partPath(int index) => '$filePath.part$index';

  Future<SegmentResult> download({
    required void Function(int total) onTotal,
    required void Function(int downloaded) onProgress,
    required void Function(String state) onState,
    required CancelToken token,
  }) async {
    final client = AppHttp.instance.createDownloadClient(maxConnectionsPerHost: concurrency + 2);
    final parts = <_Part>[];
    try {
      final probe = await _probe(client);
      final total = probe.totalBytes;

      if (probe.pending != null) {
        // 不支持分片：直接消费已有响应
        final written = await _consumeWhole(probe.pending!, onProgress, token);
        onTotal(written);
        return SegmentResult(totalBytes: written, downloadedBytes: written, supportRange: false);
      }

      onTotal(total);
      if (total <= 0) {
        final written = await _downloadSequential(client, onProgress, token);
        onTotal(written);
        return SegmentResult(totalBytes: written, downloadedBytes: written, supportRange: false);
      }

      final count = math.max(1, math.min(segmentCount, 16));
      final chunk = (total + count - 1) ~/ count;
      final signature = '$total:$chunk:$count';
      onState(signature);

      for (var index = 0; index < count; index++) {
        final start = index * chunk;
        if (start >= total) break;
        final end = math.min(total - 1, start + chunk - 1);
        parts.add(_Part(index: index, start: start, end: end, path: _partPath(index)));
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
          // 已下满的分片直接跳过
          if (part.done == part.size) part.done = part.size;
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
      await _runPool<_Part>(parts, concurrency, (part) async {
        if (part.done >= part.size) return;
        await _downloadPart(client, part, token, report);
      });

      if (token.isCancelled) {
        return SegmentResult(
          totalBytes: total,
          downloadedBytes: parts.fold<int>(0, (sum, part) => sum + part.done),
          supportRange: true,
        );
      }

      await _concat(parts, filePath);
      return SegmentResult(
        totalBytes: total,
        downloadedBytes: total,
        supportRange: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  // ------------------------------------------------------------------
  // 内部实现
  // ------------------------------------------------------------------

  Future<_Probe> _probe(HttpClient client) async {
    final request = await AppHttp.instance.openRequest(
      client,
      _uri,
      rangeStart: 0,
      rangeEnd: 0,
      referer: referer,
    );
    final response = await request.close();
    final status = response.statusCode;
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
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
      throw ApiException(status, 'HTTP $status', url);
    }
    // 不支持 Range：保留响应体，直接顺序下载
    return _Probe(totalBytes: 0, pending: response);
  }

  Future<int> _consumeWhole(
    Stream<List<int>> stream,
    void Function(int downloaded) onProgress,
    CancelToken token,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var written = 0;
    try {
      await for (final chunk in stream) {
        if (token.isCancelled) break;
        sink.add(chunk);
        written += chunk.length;
        onProgress(written);
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
    return written;
  }

  Future<int> _downloadSequential(
    HttpClient client,
    void Function(int downloaded) onProgress,
    CancelToken token,
  ) async {
    final request = await AppHttp.instance.openRequest(client, _uri, referer: referer);
    final response = await request.close();
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw ApiException(response.statusCode, 'HTTP ${response.statusCode}', url);
    }
    return _consumeWhole(response, onProgress, token);
  }

  Future<void> _downloadPart(
    HttpClient client,
    _Part part,
    CancelToken token,
    void Function() report,
  ) async {
    var attempts = 0;
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
        final response = await request.close();
        if (response.statusCode != 206 && response.statusCode != 200) {
          await response.drain<void>();
          throw ApiException(response.statusCode, 'HTTP ${response.statusCode}', url);
        }
        final sink = File(part.path).openWrite(mode: FileMode.append);
        try {
          await for (final chunk in response) {
            if (token.isCancelled) break;
            sink.add(chunk);
            part.done += chunk.length;
            report();
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
        attempts = 0;
      } catch (error) {
        if (token.isCancelled) return;
        attempts++;
        AppLog.e('Download', '分片 ${part.index} 重试 $attempts', error);
        if (attempts >= 6) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempts));
        // 以磁盘实际长度为准，避免失败时账目偏移
        part.done = await _lengthOf(part.path);
        if (part.done > part.size) {
          await _safeDelete(part.path);
          part.done = 0;
        }
        report();
      }
    }
  }

  Future<void> _concat(List<_Part> parts, String outputPath) async {
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    final sink = output.openWrite();
    try {
      for (final part in parts) {
        final file = File(part.path);
        if (!await file.exists()) continue;
        await sink.addStream(file.openRead());
      }
      await sink.flush();
    } finally {
      try {
        await sink.close();
      } catch (_) {
        // 忽略
      }
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
