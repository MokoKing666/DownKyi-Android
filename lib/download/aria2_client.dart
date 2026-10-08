import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/logger.dart';
import '../data/http_client.dart';

/// aria2 的一次任务状态（aria2.tellStatus 的结果子集）。
class Aria2Status {
  const Aria2Status({
    required this.gid,
    required this.status,
    required this.totalLength,
    required this.completedLength,
    required this.downloadSpeed,
    required this.filePath,
    required this.errorMessage,
  });

  final String gid;

  /// active / waiting / paused / error / complete / removed
  final String status;
  final int totalLength;
  final int completedLength;
  final int downloadSpeed;

  /// aria2 落盘后的本地路径（files[0].path），合并阶段要用
  final String filePath;
  final String errorMessage;

  bool get isComplete => status == 'complete';
  bool get isError => status == 'error' || status == 'removed';
  bool get isPaused => status == 'paused';
  bool get isWaiting => status == 'waiting';

  factory Aria2Status.fromJson(Map<String, dynamic> json) {
    var path = '';
    final files = json['files'];
    if (files is List && files.isNotEmpty) {
      final first = files.first;
      if (first is Map) {
        path = '${first['path'] ?? ''}';
      }
    }
    return Aria2Status(
      gid: '${json['gid'] ?? ''}',
      status: '${json['status'] ?? ''}',
      totalLength: int.tryParse('${json['totalLength'] ?? 0}') ?? 0,
      completedLength: int.tryParse('${json['completedLength'] ?? 0}') ?? 0,
      downloadSpeed: int.tryParse('${json['downloadSpeed'] ?? 0}') ?? 0,
      filePath: path,
      errorMessage: '${json['errorMessage'] ?? ''}',
    );
  }
}

/// aria2 JSON-RPC 2.0 客户端。
///
/// 只依赖 dart:io，可以直接连本机（Termux 等）或局域网 / NAS 上运行的 aria2。
/// 注意：aria2 的 RPC 请求不应带上哔哩哔哩的 Cookie/Referer，
/// 因此这里单独用一个干净的 HttpClient，而不是复用 AppHttp。
class Aria2Client {
  Aria2Client({required this.rpcUrl, this.secret = ''});

  final String rpcUrl;
  final String secret;

  HttpClient? _client;
  int _id = 0;

  bool get hasSecret => secret.isNotEmpty;

  Future<dynamic> _call(String method,
      [List<dynamic> params = const <dynamic>[]]) async {
    final Uri uri;
    try {
      uri = Uri.parse(rpcUrl.trim());
    } on FormatException {
      throw ApiException(-1, 'aria2 RPC 地址格式不正确：$rpcUrl');
    }
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw ApiException(
          -1, 'aria2 RPC 地址不完整（示例：http://127.0.0.1:6800/jsonrpc）');
    }

    final client = _client ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final payload = jsonEncode(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': 'downkyi-${++_id}',
      'method': method,
      'params': <dynamic>[
        if (hasSecret) 'token:$secret',
        ...params,
      ],
    });

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(payload);
      final response =
          await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join();
      if (body.trim().isEmpty) {
        throw ApiException(
            response.statusCode, 'aria2 返回空响应（HTTP ${response.statusCode}）');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw ApiException(-1, 'aria2 返回内容不是 JSON-RPC 格式');
      }
      final error = decoded['error'];
      if (error != null) {
        final message =
            error is Map ? '${error['message'] ?? '未知错误'}' : '$error';
        throw ApiException(-1, 'aria2 错误：$message');
      }
      return decoded['result'];
    } on SocketException catch (error) {
      throw ApiException(-1, '无法连接 aria2（$rpcUrl）：${error.message}');
    } on TimeoutException {
      throw ApiException(-1, 'aria2 响应超时：$rpcUrl');
    } on FormatException catch (error) {
      throw ApiException(-1, 'aria2 返回内容解析失败：${error.message}');
    }
  }

  /// 探测连通性，返回版本号
  Future<String> getVersion() async {
    final result = await _call('aria2.getVersion');
    if (result is Map) {
      return '${result['version'] ?? 'unknown'}';
    }
    return 'unknown';
  }

  /// 全局统计：返回 (下载速度, 活动数, 等待数)
  Future<({int downloadSpeed, int active, int waiting})> getGlobalStat() async {
    final result = await _call('aria2.getGlobalStat');
    if (result is Map) {
      return (
        downloadSpeed: int.tryParse('${result['downloadSpeed'] ?? 0}') ?? 0,
        active: int.tryParse('${result['numActive'] ?? 0}') ?? 0,
        waiting: int.tryParse('${result['numWaiting'] ?? 0}') ?? 0,
      );
    }
    return (downloadSpeed: 0, active: 0, waiting: 0);
  }

  /// 新增任务，返回 gid
  Future<String> addUri({
    required String url,
    required Map<String, dynamic> options,
  }) async {
    final result = await _call('aria2.addUri', <dynamic>[
      <String>[url],
      options,
    ]);
    return '$result';
  }

  Future<Aria2Status> tellStatus(String gid) async {
    final result = await _call('aria2.tellStatus', <dynamic>[gid]);
    if (result is Map<String, dynamic>) {
      return Aria2Status.fromJson(result);
    }
    if (result is Map) {
      return Aria2Status.fromJson(Map<String, dynamic>.from(result));
    }
    throw ApiException(-1, 'aria2.tellStatus 返回格式异常');
  }

  Future<void> pause(String gid) async {
    try {
      await _call('aria2.pause', <dynamic>[gid]);
    } catch (error) {
      AppLog.d('Aria2', '暂停失败（任务可能已结束）：$error');
    }
  }

  Future<void> unpause(String gid) async {
    try {
      await _call('aria2.unpause', <dynamic>[gid]);
    } catch (error) {
      AppLog.d('Aria2', '恢复失败：$error');
    }
  }

  /// 移除任务但保留已下载文件
  Future<void> remove(String gid) async {
    try {
      await _call('aria2.remove', <dynamic>[gid]);
    } catch (error) {
      AppLog.d('Aria2', '移除失败：$error');
    }
  }

  /// 清理已结束的任务记录
  Future<void> purgeDownloadResult() async {
    try {
      await _call('aria2.purgeDownloadResult');
    } catch (error) {
      AppLog.d('Aria2', '清理记录失败：$error');
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }

  /// 构造交给 aria2 的下载参数。
  ///
  /// referer / user-agent 用 aria2 的一等选项；Cookie 只能通过 header 传。
  static Map<String, dynamic> optionsFor({
    required String dir,
    required String out,
    required String referer,
    required String userAgent,
    String? cookie,
    int split = 16,
  }) {
    final connections = split.clamp(1, 16);
    return <String, dynamic>{
      'dir': dir,
      'out': out,
      'split': '$connections',
      'max-connection-per-server': '$connections',
      'min-split-size': '1M',
      'continue': 'true',
      'allow-overwrite': 'true',
      'auto-file-renaming': 'false',
      'referer': referer,
      'user-agent': userAgent,
      if (cookie != null && cookie.isNotEmpty)
        'header': <String>['Cookie: $cookie'],
    };
  }
}
