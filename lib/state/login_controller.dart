import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/logger.dart';
import '../bili/bili_api.dart';
import '../data/http_client.dart';
import '../bili/models.dart';
import '../data/settings_store.dart';

/// 登录态：二维码登录 + Cookie 粘贴登录。
class LoginController extends ChangeNotifier {
  LoginController({required this.api, required this.settings});

  final BiliApi api;
  final SettingsStore settings;

  NavInfo? navInfo;
  QrLogin? qr;
  QrPollResult? poll;
  bool loading = false;
  bool polling = false;
  String? error;

  bool get isLogin => navInfo?.isLogin ?? AppHttp.instance.isLogin;

  Timer? _timer;

  Future<void> refreshNav() async {
    try {
      navInfo = await api.nav();
      error = null;
    } catch (exception) {
      AppLog.e('Login', '获取用户信息失败', exception);
      error = exception.toString();
    }
    notifyListeners();
  }

  Future<void> startQrLogin() async {
    loading = true;
    error = null;
    poll = null;
    notifyListeners();
    try {
      qr = await api.qrGenerate();
      _startPolling();
    } catch (exception) {
      error = exception.toString();
      qr = null;
    }
    loading = false;
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    polling = true;
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final key = qr?.key;
      if (key == null || key.isEmpty) {
        timer.cancel();
        polling = false;
        return;
      }
      try {
        final result = await api.qrPoll(key);
        poll = result;
        notifyListeners();
        if (result.success) {
          timer.cancel();
          polling = false;
          if (result.cookie != null) {
            api.applyLoginUrl(result.cookie!);
          }
          await api.ensureBuvid();
          await settings.saveCookies();
          await refreshNav();
        } else if (result.expired) {
          timer.cancel();
          polling = false;
          notifyListeners();
        }
      } catch (exception) {
        AppLog.e('Login', '轮询二维码失败', exception);
      }
    });
  }

  Future<bool> loginWithCookie(String rawCookie) async {
    loading = true;
    error = null;
    notifyListeners();
    AppHttp.instance.setCookieHeader(rawCookie);
    await api.ensureBuvid();
    var success = false;
    try {
      final info = await api.nav();
      if (info.isLogin) {
        navInfo = info;
        success = true;
        await settings.saveCookies();
        if (!api.wbi.ready) {
          await api.ensureWbiKeys(force: true);
        }
      } else {
        error = 'Cookie 无效或已过期，请重新复制';
        AppHttp.instance.clearCookies();
      }
    } catch (exception) {
      error = exception.toString();
    }
    loading = false;
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    _timer?.cancel();
    polling = false;
    qr = null;
    poll = null;
    navInfo = null;
    await settings.clearCookies();
    api.wbi.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
