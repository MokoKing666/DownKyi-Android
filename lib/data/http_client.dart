import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants.dart';
import '../core/logger.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message, [this.url = '']);

  final int code;
  final String message;
  final String url;

  /// 需要登录的典型返回码
  bool get needLogin => code == -101 || code == -403 || code == -400;

  @override
  String toString() => '[$code] $message';
}

/// 统一网络层：dart:io 的 HttpClient（无需任何三方依赖），
/// 自带 Cookie 管理、Referer/UA 注入、WBI 参数拼接。
class AppHttp {
  AppHttp._internal();

  static final AppHttp instance = AppHttp._internal();

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent = BiliConst.userAgent
    ..autoUncompress = true
    ..maxConnectionsPerHost = 16;

  final Map<String, String> _cookies = <String, String>{};

  Map<String, String> get cookies => Map<String, String>.unmodifiable(_cookies);

  bool get isLogin => (_cookies['SESSDATA'] ?? '').isNotEmpty;

  String get cookieHeader =>
      _cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

  void setCookie(String name, String value) {
    if (name.isEmpty || value.isEmpty) return;
    _cookies[name] = value;
  }

  /// 解析浏览器里复制的 Cookie 字符串
  void setCookieHeader(String raw) {
    for (final part in raw.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final name = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      setCookie(name, value);
    }
  }

  void clearCookies() => _cookies.clear();

  Uri buildUri(String path, [Map<String, String>? query]) {
    final base = path.startsWith('http') ? Uri.parse(path) : Uri.parse('${BiliConst.apiBase}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: <String, String>{
      ...base.queryParameters,
      ...query,
    });
  }

  Map<String, String> headers({String? referer}) {
    return <String, String>{
      HttpHeaders.userAgentHeader: BiliConst.userAgent,
      // dart:io 没有 referer / origin 常量，直接用字符串
      'Referer': referer ?? BiliConst.webBase,
      'Origin': BiliConst.webBase,
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      if (_cookies.isNotEmpty) HttpHeaders.cookieHeader: cookieHeader,
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool checkCode = true,
    String? referer,
    String host = BiliConst.apiBase,
  }) async {
    final uri = path.startsWith('http')
        ? buildUri(path, query)
        : buildUri('$host$path', query);
    final body = await getString(uri, referer: referer);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(-1, '接口返回格式异常', uri.toString());
    }
    if (checkCode) {
      final code = asInt(decoded['code'], -1);
      if (code != 0) {
        final message = asString(decoded['message'] ?? decoded['msg'], '请求失败');
        throw ApiException(code, message, uri.toString());
      }
    }
    return decoded;
  }

  Future<dynamic> getData(
    String path, {
    Map<String, String>? query,
    String? referer,
    String host = BiliConst.apiBase,
  }) async {
    final json = await getJson(path, query: query, referer: referer, host: host);
    return json['data'];
  }

  Future<String> getString(Uri uri, {String? referer}) async {
    final response = await _open(uri, referer: referer);
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'HTTP ${response.statusCode}', uri.toString());
    }
    return body;
  }

  Future<List<int>> getBytes(Uri uri, {String? referer}) async {
    final response = await _open(uri, referer: referer);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'HTTP ${response.statusCode}', uri.toString());
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<HttpClientResponse> _open(Uri uri, {String? referer}) async {
    try {
      final request = await _client.getUrl(uri);
      headers(referer: referer).forEach((key, value) => request.headers.set(key, value));
      final response = await request.close();
      for (final cookie in response.cookies) {
        _cookies[cookie.name] = cookie.value;
      }
      AppLog.d('HTTP', 'GET $uri -> ${response.statusCode}');
      return response;
    } on ApiException {
      rethrow;
    } catch (error) {
      AppLog.e('HTTP', 'GET $uri 失败', error);
      throw ApiException(-2, '网络请求失败：$error', uri.toString());
    }
  }

  /// 生成一个带 B 站请求头的请求（下载器使用）
  Future<HttpClientRequest> openRequest(
    HttpClient client,
    Uri uri, {
    int? rangeStart,
    int? rangeEnd,
    String? referer,
  }) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, BiliConst.userAgent);
    request.headers.set('Referer', referer ?? BiliConst.webBase);
    request.headers.set('Origin', BiliConst.webBase);
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (_cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    }
    if (rangeStart != null) {
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=$rangeStart-${rangeEnd ?? ''}',
      );
    }
    return request;
  }

  /// 为下载器创建独立的连接池
  HttpClient createDownloadClient({int maxConnectionsPerHost = 8}) {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = BiliConst.userAgent
      ..autoUncompress = true
      ..maxConnectionsPerHost = maxConnectionsPerHost
      ..idleTimeout = const Duration(seconds: 30);
  }

  void close() {
    _client.close(force: true);
  }
}
