import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import '../core/logger.dart';
import '../data/bili_api.dart';
import '../data/http_client.dart';
import '../data/settings_store.dart';
import '../data/subscription_dao.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

/// 周期任务在 WorkManager 里的唯一名与任务名
const String subscriptionUniqueName = 'downkyi.subscription.periodic';
const String subscriptionTaskName = 'downkyi.subscription.check';

/// WorkManager 的后台入口。
///
/// 必须是**顶层函数**并标注 `@pragma('vm:entry-point')`，
/// 否则 release 构建的 tree-shaking 会把它删掉，后台任务永远不触发。
@pragma('vm:entry-point')
void subscriptionCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      return await runBackgroundSubscriptionCheck();
    } catch (error) {
      AppLog.e('Sub', '后台订阅检查异常', error);
      return false;
    }
  });
}

/// 在后台 isolate 里重建依赖并跑一次检查。
///
/// 后台 isolate 是**全新的 Dart 环境**：`main()` 里建好的对象图全都不存在，
/// 所以这里必须自己装配一遍。Cookie 由 [SettingsStore.load] 从
/// SharedPreferences 恢复进 [AppHttp]，因此登录态是拿得到的。
Future<bool> runBackgroundSubscriptionCheck() async {
  // 后台 isolate 需要显式注册一次 Dart 端插件实现，否则 sqflite /
  // shared_preferences 的通道调用会失败
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {
    // 个别平台没有注册器，忽略
  }

  final settings = SettingsStore();
  await settings.load();
  await NotificationService.instance.init();

  final api = BiliApi(AppHttp.instance);
  final service = SubscriptionService(api: api, dao: SubscriptionDao.instance);
  final results = await service.checkAll();
  final found = results.fold<int>(0, (sum, item) => sum + item.newItems.length);
  final failed = results.where((item) => item.failed).length;
  AppLog.d('Sub', '后台检查完成：${results.length} 个订阅，发现 $found 个新内容，失败 $failed 个');
  return true;
}

/// 周期检查的注册与开关。
class SubscriptionScheduler {
  SubscriptionScheduler._internal();

  static final SubscriptionScheduler instance = SubscriptionScheduler._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(subscriptionCallbackDispatcher);
      _initialized = true;
      AppLog.d('Sub', 'WorkManager 初始化完成');
    } catch (error) {
      // 初始化失败不能让 App 起不来：周期检查降级为「打开 App 时补一次检查」
      AppLog.e('Sub', 'WorkManager 初始化失败，周期检查不可用', error);
    }
  }

  /// 按设置应用周期任务；关闭时不注册
  Future<void> apply({required bool enabled, required int intervalHours}) async {
    await init();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(subscriptionUniqueName);
      if (!enabled) {
        AppLog.d('Sub', '周期检查已关闭');
        return;
      }
      await Workmanager().registerPeriodicTask(
        subscriptionUniqueName,
        subscriptionTaskName,
        // WorkManager 的周期下限是 15 分钟（系统限制），这里最短 1 小时
        frequency: Duration(hours: intervalHours.clamp(1, 48)),
        // 首次不立刻跑：App 启动时前台本来就会补一次检查
        initialDelay: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
      AppLog.d('Sub', '周期检查已注册：每 $intervalHours 小时');
    } catch (error) {
      AppLog.e('Sub', '注册周期检查失败', error);
    }
  }

  Future<bool> isScheduled() async {
    await init();
    if (!_initialized) return false;
    try {
      return await Workmanager().isScheduledByUniqueName(subscriptionUniqueName);
    } catch (_) {
      return false;
    }
  }
}
