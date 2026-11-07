import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/logger.dart';
import 'bili/bili_api.dart';
import 'data/http_client.dart';
import 'data/settings_store.dart';
import 'data/subscription_dao.dart';
import 'download/download_manager.dart';
import 'download/download_session.dart';
import 'native/bridge.dart';
import 'state/login_controller.dart';
import 'state/parse_controller.dart';
import 'state/shell_controller.dart';
import 'subscription/notification_service.dart';
import 'subscription/subscription_scheduler.dart';
import 'subscription/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsStore();
  await settings.load();

  final api = BiliApi(AppHttp.instance);
  await api.ensureBuvid();

  final manager = DownloadManager(settings: settings, api: api);
  await manager.init();

  // 进程被系统回收会留下「显示下载中、实际没在下载」的任务（数据库里还是 running），
  // 启动时统一重新入队——分片文件还在，会接着断点续传，不丢已下载的数据。
  await DownloadSession.instance.recoverInterrupted(manager);
  // 前台服务时长预算守护（Android 15+ 对 dataSync 有累计运行时长上限）
  DownloadSession.instance.start(manager);

  final login = LoginController(api: api, settings: settings);
  final parse = ParseController(api: api, manager: manager, settings: settings);

  // 订阅：初始化通知插件，并按设置登记周期后台检查
  await NotificationService.instance.init();
  await SubscriptionScheduler.instance.apply(
    enabled: settings.subscriptionCheckEnabled,
    intervalHours: settings.subscriptionIntervalHours,
  );

  unawaited(login.refreshNav());
  unawaited(NativeBridge.requestNotificationPermission());
  unawaited(_catchUpSubscriptionCheck(api, manager, settings));
  AppLog.d('App', '启动完成');

  runApp(
    MultiProvider(
      providers: [
        Provider<BiliApi>.value(value: api),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<LoginController>.value(value: login),
        ChangeNotifierProvider<DownloadManager>.value(value: manager),
        ChangeNotifierProvider<ParseController>.value(value: parse),
        ChangeNotifierProvider<ShellController>(
            create: (_) => ShellController()),
      ],
      child: const DownKyiApp(),
    ),
  );
}

/// 打开 App 时补做一次订阅检查。
///
/// WorkManager 的周期任务由系统调度，**不保证准时**（可能被推迟甚至跳过），
/// 所以每次前台启动都补一次；后台检查只是「App 没开着时也不漏掉」的补充手段。
Future<void> _catchUpSubscriptionCheck(
  BiliApi api,
  DownloadManager manager,
  SettingsStore settings,
) async {
  if (!settings.subscriptionCheckEnabled) return;
  try {
    // 稍等再跑，避免和启动时的 nav / buvid 请求抢带宽
    await Future<void>.delayed(const Duration(seconds: 5));
    final service = SubscriptionService(
      api: api,
      dao: SubscriptionDao.instance,
      manager: manager,
    );
    final results = await service.checkAll();
    final found =
        results.fold<int>(0, (sum, item) => sum + item.newItems.length);
    if (found > 0) AppLog.d('Sub', '前台补检查发现 $found 个新内容');
  } catch (error) {
    AppLog.e('Sub', '前台补检查失败', error);
  }
}
