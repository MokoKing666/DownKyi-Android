import 'dart:async';
import 'dart:io';

import 'package:downkyi/data/http_client.dart';
import 'package:downkyi/download/segment_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 分片下载器测试。
///
/// **为什么用真实本地 HttpServer 而不是 mock Response**：
/// 文档列的验收标准全都和 HTTP 语义本身有关——206 的 Content-Range 校验、
/// 服务器忽略 Range 却返回 200、416、连接半途静默停滞、chunked 提前结束。
/// 拿一个假的 Response 对象测，测的是「我以为的 HTTP」；只有真开一个本地端口，
/// 才能同时覆盖「真实 socket 行为」与「我们的解析」之间的差异。
///
/// 覆盖文档「验收标准」清单：正常 206 / 错误 200 / 错误 Content-Range / 416 /
/// 网络中断后恢复 / 分片已存在（断点续传）/ 分片长度异常 / URL 过期。
void main() {
  late Directory tempDir;
  late HttpServer server;
  late _FakeServer behavior;
  late String url;
  late String output;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('downkyi_seg_');
    output = '${tempDir.path}/out.m4s';
    behavior = _FakeServer();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/video.m4s';
    unawaited(_serve(server, behavior));
  });

  tearDown(() async {
    await server.close(force: true);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SegmentDownloader build({
    int segments = 4,
    int concurrency = 4,
    String resumeState = '',
    Future<String?> Function()? refreshUrl,
    Duration readIdle = const Duration(milliseconds: 400),
    int maxAttempts = 2,
    String? target,
  }) =>
      SegmentDownloader(
        url: url,
        filePath: target ?? output,
        segmentCount: segments,
        concurrency: concurrency,
        resumeState: resumeState,
        refreshUrl: refreshUrl,
        readIdleTimeout: readIdle,
        responseTimeout: const Duration(seconds: 5),
        maxAttempts: maxAttempts,
        baseBackoff: const Duration(milliseconds: 1),
      );

  Future<SegmentResult> run(SegmentDownloader downloader) =>
      downloader.download(
        onTotal: (_) {},
        onProgress: (_) {},
        onState: (_) {},
        token: CancelToken(),
      );

  group('正常路径', () {
    test('206 分片下载：产出完整文件、内容逐字节正确、分片被清理', () async {
      behavior.size = 4000;

      final result = await run(build());

      expect(result.supportRange, isTrue);
      expect(result.totalBytes, 4000);
      expect(await File(output).length(), 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
      for (var i = 0; i < 4; i++) {
        expect(File('$output.part$i').existsSync(), isFalse,
            reason: '分片 $i 未被清理');
      }
    });

    test('服务端完全不支持 Range 时退回顺序下载', () async {
      behavior.size = 3000;
      behavior.noRangeSupport = true;

      final result = await run(build());

      expect(result.supportRange, isFalse);
      expect(await File(output).readAsBytes(), payload(0, 3000));
    });

    test('单分片配置也能正确拼出文件', () async {
      behavior.size = 2500;
      final result = await run(build(segments: 1, concurrency: 1));
      expect(result.totalBytes, 2500);
      expect(await File(output).readAsBytes(), payload(0, 2500));
    });
  });

  group('Range 严格校验（P0）', () {
    test('服务器对分片请求忽略 Range 返回 200：必须失败，不能产出损坏文件', () async {
      behavior.size = 4000;
      behavior.ignoreRangeAfterProbe = true;

      await expectLater(run(build()), throwsA(isA<ApiException>()));

      // 关键：绝不允许「把完整文件追加进 .part 后拼出一个更大的坏文件」
      expect(File(output).existsSync(), isFalse, reason: '不应产出任何成品文件');
    });

    test('分片响应的 206 缺少 Content-Range 头：失败', () async {
      // 探测能拿到总大小（所以会走分片），但分片响应不带 Content-Range——
      // 这时无法确认服务端返回的区间是否正确，必须中止而不是盲目拼接。
      behavior.size = 4000;
      behavior.omitContentRangeAfterProbe = true;

      await expectLater(
        run(build()),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('Content-Range'))),
      );
      expect(File(output).existsSync(), isFalse);
    });

    test('探测响应就没有 Content-Range：退回顺序下载，文件仍然正确', () async {
      // 探测拿不到总大小时无法切分，只能单线程下。
      // 这里退化为顺序下载是安全的——成品依然逐字节正确，
      // 只是失去多线程加速；直接报错反而更差。
      behavior.size = 4000;
      behavior.omitContentRange = true;

      final result = await run(build());

      expect(result.supportRange, isFalse);
      expect(await File(output).readAsBytes(), payload(0, 4000));
    });

    test('206 的 Content-Range 起点与请求不符：失败', () async {
      behavior.size = 4000;
      behavior.rangeStartOffset = 64;

      await expectLater(
        run(build()),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('起点'))),
      );
      expect(File(output).existsSync(), isFalse);
    });

    test('206 的 Content-Range 总长与探测结果不一致：失败', () async {
      behavior.size = 4000;
      behavior.totalOverrideAfterProbe = 9999;

      await expectLater(
        run(build()),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('总长'))),
      );
      expect(File(output).existsSync(), isFalse);
    });

    test('收到的数据超过请求范围：失败', () async {
      behavior.size = 4000;
      behavior.overSendBytes = 200;

      await expectLater(run(build(segments: 4)), throwsA(isA<ApiException>()));
      expect(File(output).existsSync(), isFalse);
    });

    test('探测阶段就返回 416：失败且不留成品', () async {
      behavior.size = 4000;
      behavior.forceStatus = 416;

      await expectLater(run(build()), throwsA(isA<ApiException>()));
      expect(File(output).existsSync(), isFalse);
    });

    test('分片阶段持续 416：最终失败，不会静默成功', () async {
      behavior.size = 4000;
      behavior.status416AfterProbe = true;

      await expectLater(
          run(build(maxAttempts: 2)), throwsA(isA<ApiException>()));
      expect(File(output).existsSync(), isFalse);
    });
  });

  group('拼接完整性（P0）', () {
    test('任一分片下载失败就不能产出成品', () async {
      behavior.size = 4000;
      // 第二片（start=1000）开始一律 500，且不可重试成功
      behavior.failFromOffset = 1000;
      behavior.failStatus = 500;

      await expectLater(
          run(build(maxAttempts: 2)), throwsA(isA<ApiException>()));
      expect(File(output).existsSync(), isFalse, reason: '缺分片时绝不允许产出成品');
    });
  });

  group('断点续传', () {
    test('已存在的分片会被复用，只补缺失的部分', () async {
      behavior.size = 4000;
      // 与下载器内部签名一致：total:chunk:count = 4000:1000:4
      const signature = '4000:1000:4';

      // part0 已完整，part1 下载到一半
      await File('$output.part0').writeAsBytes(payload(0, 1000));
      await File('$output.part1').writeAsBytes(payload(1000, 1500));

      final result = await run(build(resumeState: signature));

      expect(result.totalBytes, 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
      // part0 完整，不应再请求它
      expect(behavior.ranges, isNot(contains('bytes=0-999')));
      // part1 应当从 1500 续起
      expect(behavior.ranges, contains('bytes=1500-1999'));
    });

    test('签名不一致（总大小变了）会丢弃旧分片重下', () async {
      behavior.size = 4000;
      await File('$output.part0').writeAsBytes(List<int>.filled(1000, 7));

      final result = await run(build(resumeState: '9999:2500:4'));

      expect(result.totalBytes, 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
    });

    test('分片文件比预期更长时会被丢弃重下', () async {
      behavior.size = 4000;
      // part0 超出了它应有的 1000 字节
      await File('$output.part0').writeAsBytes(List<int>.filled(1800, 9));

      final result = await run(build(resumeState: '4000:1000:4'));

      expect(result.totalBytes, 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
    });
  });

  group('读空闲超时（P1）', () {
    test('服务端停止发送数据时会断开重连，而不是无限挂住', () async {
      behavior.size = 4000;
      behavior.stallAfterHalf = const Duration(seconds: 3);

      final stopwatch = Stopwatch()..start();
      await expectLater(
          run(build(maxAttempts: 2)), throwsA(isA<ApiException>()));
      stopwatch.stop();

      // 读空闲超时是 400ms，maxAttempts=2 —— 若没有超时机制，
      // 这里会一直等到服务端 3 秒后才结束，甚至更久。
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
      expect(File(output).existsSync(), isFalse);
    });
  });

  group('URL 过期自动刷新（P0）', () {
    test('探测阶段遇到 403：刷新地址后继续，不重下任何数据', () async {
      behavior.size = 4000;
      behavior.failFirstRequests = 1; // 只让探测那一次 403
      var refreshCalls = 0;

      // 必须每次返回不同的地址：下载器把「刷新出来的地址与当前地址相同」
      // 视为刷新失败（否则会无限循环重试）。线上重新解析 playurl 拿到的是
      // 带新 wts/sign 的地址，天然不同。
      final result = await run(build(
        refreshUrl: () async {
          refreshCalls++;
          return '$url?token=fresh$refreshCalls';
        },
      ));

      expect(refreshCalls, 1, reason: '应当触发一次地址刷新');
      expect(result.totalBytes, 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
    });

    test('分片下载中途 403：刷新后保留已完成分片继续', () async {
      behavior.size = 4000;
      // 探测 + 前 2 个分片请求返回 403
      behavior.failFirstRequests = 3;
      var refreshCalls = 0;

      final result = await run(build(
        refreshUrl: () async {
          refreshCalls++;
          return '$url?token=fresh$refreshCalls';
        },
      ));

      expect(refreshCalls, greaterThanOrEqualTo(1));
      expect(result.totalBytes, 4000);
      expect(await File(output).readAsBytes(), payload(0, 4000));
    });

    test('403 且无法刷新时失败，不会产出成品', () async {
      behavior.size = 4000;
      behavior.failFirstRequests = 999;

      await expectLater(
          run(build(maxAttempts: 2)), throwsA(isA<ApiException>()));
      expect(File(output).existsSync(), isFalse);
    });

    test('刷新回调抛异常时按刷新失败处理', () async {
      behavior.size = 4000;
      behavior.failFirstRequests = 999;

      await expectLater(
        run(build(refreshUrl: () async => throw StateError('刷新接口挂了'))),
        throwsA(isA<ApiException>()),
      );
      expect(File(output).existsSync(), isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// 测试替身：一个可编程行为的本地 HTTP 服务器
// ---------------------------------------------------------------------------

/// 生成确定性的字节内容，便于逐字节比对
List<int> payload(int start, int end) =>
    List<int>.generate(end - start, (i) => (start + i) % 251);

class _FakeServer {
  int size = 4000;

  /// 探测请求正常，之后所有分片请求忽略 Range 返回 200（不同 CDN 节点行为不一致）
  bool ignoreRangeAfterProbe = false;

  /// 206 但不带 Content-Range（探测与分片都不带）
  bool omitContentRange = false;

  /// 只在分片响应里省略 Content-Range
  bool omitContentRangeAfterProbe = false;

  /// 伪造 Content-Range 起点偏移
  int? rangeStartOffset;

  /// 伪造 Content-Range 总长（探测与分片都伪造）
  int? totalOverride;

  /// 只在探测之后的响应里伪造总长。
  /// 用于单独验证「总长变化」这条校验——否则探测阶段就拿到错误总长，
  /// 分片边界会跟着错，最后撞到的是越界 416 而不是总长校验。
  int? totalOverrideAfterProbe;

  /// 206 但实际多发这么多字节
  int overSendBytes = 0;

  /// 前 N 个请求返回 403（模拟播放地址过期）
  int failFirstRequests = 0;

  /// 从该偏移起的分片请求一律失败
  int? failFromOffset;
  int failStatus = 500;

  /// 探测之后所有请求返回 416
  bool status416AfterProbe = false;

  /// 强制所有请求返回该状态码
  int? forceStatus;

  /// 完全不支持 Range（探测就返回 200）
  bool noRangeSupport = false;

  /// 只发一半数据后正常结束（chunked，不设 Content-Length）
  bool truncateHalf = false;

  /// 发一半数据后挂住不结束
  Duration? stallAfterHalf;

  int requestCount = 0;
  final List<String> ranges = <String>[];

  bool get _isProbe => requestCount == 1;
}

Future<void> _serve(HttpServer server, _FakeServer behavior) async {
  await for (final request in server) {
    unawaited(_handle(request, behavior));
  }
}

Future<void> _handle(HttpRequest request, _FakeServer behavior) async {
  behavior.requestCount++;
  final response = request.response;
  final wasProbe = behavior._isProbe;
  try {
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null) behavior.ranges.add(rangeHeader);

    if (behavior.failFirstRequests > 0 &&
        behavior.requestCount <= behavior.failFirstRequests) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    if (behavior.forceStatus != null) {
      response.statusCode = behavior.forceStatus!;
      if (behavior.forceStatus == HttpStatus.requestedRangeNotSatisfiable) {
        response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes */${behavior.size}');
      }
      await response.close();
      return;
    }
    if (behavior.status416AfterProbe && !wasProbe) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes */${behavior.size}');
      await response.close();
      return;
    }

    // 不支持 Range：整份返回
    if (behavior.noRangeSupport ||
        (behavior.ignoreRangeAfterProbe && !wasProbe) ||
        rangeHeader == null) {
      response.statusCode = HttpStatus.ok;
      response.headers.contentLength = behavior.size;
      response.add(payload(0, behavior.size));
      await response.close();
      return;
    }

    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (match == null) {
      response.statusCode = HttpStatus.ok;
      response.headers.contentLength = behavior.size;
      response.add(payload(0, behavior.size));
      await response.close();
      return;
    }
    final start = int.parse(match.group(1)!);
    final requestedEnd = match.group(2)!.isEmpty
        ? behavior.size - 1
        : int.parse(match.group(2)!);

    if (behavior.failFromOffset != null && start >= behavior.failFromOffset!) {
      response.statusCode = behavior.failStatus;
      await response.close();
      return;
    }

    if (start >= behavior.size) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes */${behavior.size}');
      await response.close();
      return;
    }

    final end =
        requestedEnd >= behavior.size ? behavior.size - 1 : requestedEnd;
    response.statusCode = HttpStatus.partialContent;
    final skipContentRange = behavior.omitContentRange ||
        (behavior.omitContentRangeAfterProbe && !wasProbe);
    if (!skipContentRange) {
      final total = (!wasProbe ? behavior.totalOverrideAfterProbe : null) ??
          behavior.totalOverride ??
          behavior.size;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${start + (behavior.rangeStartOffset ?? 0)}-$end/$total',
      );
    }

    if (behavior.stallAfterHalf != null) {
      // 不设 Content-Length（走 chunked），发一半后挂住
      response.add(payload(start, start + (end - start + 1) ~/ 2));
      await response.flush();
      await Future<void>.delayed(behavior.stallAfterHalf!);
      await response.close();
      return;
    }
    if (behavior.truncateHalf) {
      response.add(payload(start, start + (end - start + 1) ~/ 2));
      await response.close(); // chunked 正常结束，但数据不足
      return;
    }
    if (behavior.overSendBytes > 0) {
      response.add(payload(start, end + 1 + behavior.overSendBytes));
      await response.close();
      return;
    }

    response.headers.contentLength = end - start + 1;
    response.add(payload(start, end + 1));
    await response.close();
  } catch (_) {
    // 客户端断开是正常现象
    try {
      await response.close();
    } catch (_) {
      // 忽略
    }
  }
}
