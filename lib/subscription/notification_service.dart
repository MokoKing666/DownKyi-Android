import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/logger.dart';

/// 订阅更新通知。
///
/// **为什么用 flutter_local_notifications，而不是复用现有的自建 MethodChannel**：
/// 周期检查跑在 WorkManager 创建的后台 isolate 里。那个 isolate 的 `FlutterEngine`
/// 是 workmanager 插件自己 `new` 出来的（见 `workmanager_android` 的 `BackgroundWorker`），
/// 里面**没有 MainActivity**——而 `com.moko.downkyi/native` 通道正是注册在
/// `MainActivity.configureFlutterEngine` 里的。从后台调用它会抛
/// `MissingPluginException`，通知静默丢失。workmanager 也没有提供 engine 创建回调
/// 让我们补注册（已确认其 Android 端没有 `setPluginRegistrantCallback` 之类的钩子）。
///
/// 而 `flutter_local_notifications` 是随包发布的插件，后台 engine 会自动注册它，
/// 于是前台与后台能用同一套代码发通知。
///
/// 渠道用独立的 `downkyi_subscription`（IMPORTANCE_DEFAULT），不复用下载进度那条：
/// 那条是 `IMPORTANCE_LOW` 的前台服务渠道，**渠道重要性创建后 App 无法修改**
/// （只能用户在系统设置里改），放进去等于没有声音、没有横幅；而且会和常驻的
/// 下载进度条混在一起，让用户误读成「一个卡住的下载」。这不影响通知体系的一致性：
/// 同一个通知中心、同一个图标、同样的点击进 App，只是多了一个渠道 id。
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  static const String channelId = 'downkyi_subscription';
  static const String channelName = '订阅更新';
  static const String channelDescription = '订阅的 UP 主 / 合集 / 收藏夹 / 番剧有更新时提醒';
  static const String payloadPrefix = 'sub:';

  /// 通知 id 偏移，避开 DownloadsService 占用的前台通知 10086
  static const int _notificationBase = 20000;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// 用户点击通知想要跳转的订阅 id（由启动参数带入，消费后清零）
  int _pendingSubscriptionId = 0;

  /// App 已启动时收到点击的回调（冷启动走 [consumePendingSubscriptionId]）
  void Function(int subscriptionId)? onOpenSubscription;

  Future<void> init() async {
    if (_ready) return;
    try {
      const settings = InitializationSettings(
        // 注意：资源名与 DownloadService 里的 R.drawable.ic_stat_downkyi 必须一致。
        // 之前用 ic_stat_download 时，因为资源名没变，SystemUI 会按名字复用
        // 缓存下来的旧图标位图，表现为「换了图标但通知栏没变」，所以这里改名。
        android: AndroidInitializationSettings('ic_stat_downkyi'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _ready = true;
      await _readLaunchPayload();
      AppLog.d('Notify', '通知插件初始化完成');
    } catch (error) {
      AppLog.e('Notify', '通知插件初始化失败', error);
    }
  }

  /// 发一条「订阅有更新」的提醒
  Future<void> notifySubscription({
    required int subscriptionId,
    required String title,
    required String body,
  }) async {
    try {
      if (!_ready) await init();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
          autoCancel: true,
        ),
      );
      await _plugin.show(
        id: _notificationBase + subscriptionId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: '$payloadPrefix$subscriptionId',
      );
    } catch (error) {
      AppLog.e('Notify', '发送订阅通知失败', error);
    }
  }

  /// 取出并清空「因点击通知而启动」的订阅 id，0 表示没有
  int consumePendingSubscriptionId() {
    final value = _pendingSubscriptionId;
    _pendingSubscriptionId = 0;
    return value;
  }

  void _handleResponse(NotificationResponse response) {
    final id = _parsePayload(response.payload);
    if (id == 0) return;
    final handler = onOpenSubscription;
    if (handler == null) {
      _pendingSubscriptionId = id;
      return;
    }
    handler(id);
  }

  Future<void> _readLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || details.didNotificationLaunchApp != true) return;
      final id = _parsePayload(details.notificationResponse?.payload);
      if (id != 0) _pendingSubscriptionId = id;
    } catch (error) {
      AppLog.e('Notify', '读取启动通知失败', error);
    }
  }

  int _parsePayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return 0;
    return int.tryParse(payload.substring(payloadPrefix.length)) ?? 0;
  }
}
