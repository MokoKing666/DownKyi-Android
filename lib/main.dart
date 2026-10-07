import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/logger.dart';
import 'data/bili_api.dart';
import 'data/http_client.dart';
import 'data/settings_store.dart';
import 'download/download_manager.dart';
import 'native/bridge.dart';
import 'state/login_controller.dart';
import 'state/parse_controller.dart';
import 'state/shell_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsStore();
  await settings.load();

  final api = BiliApi(AppHttp.instance);
  await api.ensureBuvid();

  final manager = DownloadManager(settings: settings, api: api);
  await manager.init();

  final login = LoginController(api: api, settings: settings);
  final parse = ParseController(api: api, manager: manager, settings: settings);

  unawaited(login.refreshNav());
  unawaited(NativeBridge.requestNotificationPermission());
  AppLog.d('App', '启动完成');

  runApp(
    MultiProvider(
      providers: [
        Provider<BiliApi>.value(value: api),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<LoginController>.value(value: login),
        ChangeNotifierProvider<DownloadManager>.value(value: manager),
        ChangeNotifierProvider<ParseController>.value(value: parse),
        ChangeNotifierProvider<ShellController>(create: (_) => ShellController()),
      ],
      child: const DownKyiApp(),
    ),
  );
}
