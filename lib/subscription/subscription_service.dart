import '../core/constants.dart';
import '../core/logger.dart';
import '../data/bili_api.dart';
import '../data/http_client.dart';
import '../data/models.dart';
import '../data/subscription.dart';
import '../data/subscription_dao.dart';
import '../download/download_manager.dart';
import 'notification_service.dart';

/// 一次订阅检查的结果。
class SubscriptionCheckResult {
  const SubscriptionCheckResult({
    required this.subscription,
    this.newItems = const <MediaItem>[],
    this.error,
    this.seeded = false,
    this.queued = 0,
  });

  final Subscription subscription;
  final List<MediaItem> newItems;
  final String? error;

  /// true 表示这是首次检查（只播种已知内容，不通知、不下载）
  final bool seeded;

  /// 自动下载模式下成功创建的任务数
  final int queued;

  bool get hasNew => newItems.isNotEmpty;
  bool get failed => error != null;
}

/// 订阅增量检查。
///
/// 职责边界很窄：**取第 1 页 → 与已发现集合做差 → 落库 → 通知 / 建任务**。
/// 不含调度（见 `SubscriptionScheduler`），不含 UI。
///
/// 之所以只拉第 1 页：订阅关心的是「有没有新增」，
/// 全量翻页既慢又会随订阅增多线性放大开销；第 1 页按时间倒序，
/// 新内容必然出现在这里（合集需要 `newestFirst: true`，见 `_fetch`）。
class SubscriptionService {
  SubscriptionService({
    required this.api,
    required this.dao,
    this.manager,
    this.pageSize = 25,
  });

  final BiliApi api;
  final SubscriptionDao dao;

  /// 自动下载时才需要；后台检查场景可以不传
  final DownloadManager? manager;

  final int pageSize;

  /// 检查全部启用的订阅
  Future<List<SubscriptionCheckResult>> checkAll() async {
    if (!api.http.isLogin) {
      AppLog.d('Sub', '未登录，跳过订阅检查');
      return <SubscriptionCheckResult>[];
    }
    final subscriptions = await dao.loadAll();
    final results = <SubscriptionCheckResult>[];
    for (final subscription in subscriptions) {
      if (!subscription.enabled) continue;
      results.add(await check(subscription));
      // 稍微错开，避免一次唤醒瞬间打出一长串请求
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return results;
  }

  /// 检查单个订阅
  Future<SubscriptionCheckResult> check(Subscription subscription) async {
    if (subscription.id == 0) {
      return SubscriptionCheckResult(
          subscription: subscription, error: '订阅尚未入库');
    }
    try {
      final fetched = await _fetch(subscription);
      final items = fetched.items;
      subscription.lastCheckedAt = DateTime.now().millisecondsSinceEpoch;

      // 新订阅还没有名字，用服务端返回的标题补上
      if (subscription.title.isEmpty && fetched.title.isNotEmpty) {
        subscription.title = fetched.title;
      }

      if (items.isEmpty) {
        // 空结果不当作「内容全没了」，只更新时间，避免把已发现记录误清
        await dao.update(subscription);
        return SubscriptionCheckResult(subscription: subscription);
      }

      final seen = await dao.seenKeys(subscription.id);
      final firstRun = seen.isEmpty;

      // 各入口的“最新一条”位置不同：番剧是整季列表，最新在末尾
      final newest = subscription.kind == SubscriptionKind.bangumi
          ? items.last
          : items.first;
      subscription.lastBvid =
          newest.bvid.isEmpty ? 'ep${newest.epId ?? 0}' : newest.bvid;

      if (firstRun) {
        // 首次检查只播种：否则整页存量内容会被当成「新内容」全部通知一遍
        await dao.insertSeen(_toSeen(subscription, items));
        await dao.update(subscription);
        AppLog.d('Sub', '首次检查已完成播种：${subscription.title}（${items.length} 条）');
        return SubscriptionCheckResult(
          subscription: subscription,
          seeded: true,
        );
      }

      final newItems = <MediaItem>[];
      for (final item in items) {
        if (seen.contains('${item.bvid}|${item.epId ?? 0}')) continue;
        newItems.add(item);
      }

      if (newItems.isEmpty) {
        await dao.update(subscription);
        return SubscriptionCheckResult(subscription: subscription);
      }

      await dao.insertSeen(_toSeen(subscription, newItems));

      var queued = 0;
      if (subscription.autoDownload) {
        queued = await _autoDownload(subscription, newItems);
      } else {
        await _notify(subscription, newItems);
      }
      await dao.update(subscription);
      AppLog.d(
          'Sub', '${subscription.title} 发现 ${newItems.length} 个新内容，入队 $queued');
      return SubscriptionCheckResult(
        subscription: subscription,
        newItems: newItems,
        queued: queued,
      );
    } catch (error) {
      subscription.lastCheckedAt = DateTime.now().millisecondsSinceEpoch;
      await dao.update(subscription);
      final message = error is ApiException ? error.message : '$error';
      AppLog.e('Sub', '检查订阅失败：${subscription.title}', error);
      return SubscriptionCheckResult(
          subscription: subscription, error: message);
    }
  }

  // ------------------------------------------------------------------
  // 取数
  // ------------------------------------------------------------------

  /// 取第 1 页并顺带带回服务端的标题（用于给新订阅命名）
  Future<({List<MediaItem> items, String title})> _fetch(
      Subscription subscription) async {
    switch (subscription.kind) {
      case SubscriptionKind.space:
        final mid = int.tryParse(subscription.sourceId) ?? 0;
        if (mid <= 0)
          throw ApiException(-1, 'UP 主 UID 无效：${subscription.sourceId}');
        // order=pubdate 倒序，第 1 页第一条就是最新投稿
        final result =
            await api.spaceArchives(mid: mid, page: 1, pageSize: pageSize);
        return (items: result.items, title: result.title);

      case SubscriptionKind.season:
        final parts = subscription.sourceId.split(':');
        if (parts.length != 2)
          throw ApiException(-1, '合集标识无效：${subscription.sourceId}');
        final mid = int.tryParse(parts[0]) ?? 0;
        final seasonId = int.tryParse(parts[1]) ?? 0;
        if (mid <= 0 || seasonId <= 0) {
          throw ApiException(-1, '合集标识无效：${subscription.sourceId}');
        }
        // 合集默认按发布时间升序（第 1 页最旧），必须倒序拉才能拿到最新
        final result = await api.seasonArchives(
          mid: mid,
          seasonId: seasonId,
          page: 1,
          pageSize: pageSize,
          newestFirst: true,
        );
        return (items: result.items, title: result.title);

      case SubscriptionKind.favorites:
        final mediaId = int.tryParse(subscription.sourceId) ?? 0;
        if (mediaId <= 0)
          throw ApiException(-1, '收藏夹 id 无效：${subscription.sourceId}');
        // order=mtime 倒序，第 1 页第一条就是最新收藏
        final result = await api.favResources(
            mediaId: mediaId, page: 1, pageSize: pageSize);
        return (items: result.items, title: result.title);

      case SubscriptionKind.bangumi:
        final seasonId = int.tryParse(subscription.sourceId) ?? 0;
        if (seasonId <= 0)
          throw ApiException(-1, '番剧 ssId 无效：${subscription.sourceId}');
        // 追番直接取整季剧集列表一次比对，比翻页可靠
        final result =
            await api.seasonInfo(isCheese: false, seasonId: seasonId);
        return (
          items: result.items,
          title:
              asString(result.season['title'], '番剧 ${subscription.sourceId}'),
        );
    }
  }

  // ------------------------------------------------------------------
  // 动作
  // ------------------------------------------------------------------

  List<SeenItem> _toSeen(Subscription subscription, List<MediaItem> items) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return items
        .map((item) => SeenItem(
              subscriptionId: subscription.id,
              bvid: item.bvid,
              epId: item.epId,
              title: item.title,
              cover: item.cover,
              durationMs: item.durationMs,
              cid: item.cid,
              discoveredAt: now,
            ))
        .toList();
  }

  Future<void> _notify(Subscription subscription, List<MediaItem> items) async {
    final head = items.first.title;
    final body = items.length == 1 ? head : '$head（等 ${items.length} 个）';
    await NotificationService.instance.notifySubscription(
      subscriptionId: subscription.id,
      title: '${subscription.title} 更新了 ${items.length} 个内容',
      body: body,
    );
  }

  Future<int> _autoDownload(
      Subscription subscription, List<MediaItem> items) async {
    final downloader = manager;
    if (downloader == null) return 0;
    if (!subscription.wantAny) {
      AppLog.d('Sub', '${subscription.title} 未勾选视频 / 音频，跳过自动下载');
      return 0;
    }
    var queued = 0;
    final keys = <String>[];
    for (final item in items) {
      final task = await downloader.enqueue(
        item: item,
        quality: subscription.quality,
        qualityName: BiliConst.qualityNames[subscription.quality] ??
            '${subscription.quality}',
        codec: subscription.codec,
        flags: subscription.flags,
      );
      if (task != null) queued++;
      keys.add('${item.bvid}|${item.epId ?? 0}');
    }
    await dao.markDownloaded(subscription.id, keys);
    return queued;
  }
}
