/// 订阅：把「一次性解析的批量列表」变成可持久跟踪的对象。
library;

import '../core/constants.dart';
import '../core/link_parser.dart';

/// 可长期跟踪的订阅类型。
///
/// 与 [LinkKind] 的对应关系见 [SubscriptionKind.ofLink]：
/// 只有「会持续新增内容」的资源才值得订阅，`video` / `bangumiEp` 这类单集链接不构成订阅。
enum SubscriptionKind {
  /// UP 主投稿（space.bilibili.com/<mid>）
  space,

  /// UP 主合集（space.bilibili.com/<mid>/lists/<seasonId>）
  season,

  /// 收藏夹（favlist?fid=<mediaId>）
  favorites,

  /// 番剧 / 剧集整季（bangumi/play/ss<seasonId>）
  bangumi;

  String get label => switch (this) {
        SubscriptionKind.space => 'UP 主投稿',
        SubscriptionKind.season => '合集',
        SubscriptionKind.favorites => '收藏夹',
        SubscriptionKind.bangumi => '番剧',
      };

  String get description => switch (this) {
        SubscriptionKind.space => '按发布时间倒序，第一页第一条就是最新投稿',
        SubscriptionKind.season => '按发布时间升序，检查时用倒序拉第一页取最新',
        SubscriptionKind.favorites => '按收藏时间倒序，第一页第一条就是最新收藏',
        SubscriptionKind.bangumi => '直接取整季剧集列表，按集数比对',
      };

  static SubscriptionKind? fromName(String? name) {
    for (final value in SubscriptionKind.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// 把解析出的链接映射成订阅类型；返回 null 表示这类链接不该被订阅。
  ///
  /// 注意 `bangumiEp`（单集 ep 链接）不映射——单集不会新增内容，
  /// 需要用户改成整季链接（ss）再订阅。
  static SubscriptionKind? ofLink(LinkKind kind) => switch (kind) {
        LinkKind.space => SubscriptionKind.space,
        LinkKind.season => SubscriptionKind.season,
        LinkKind.favorites => SubscriptionKind.favorites,
        LinkKind.bangumiSeason => SubscriptionKind.bangumi,
        _ => null,
      };
}

/// 一条订阅。
class Subscription {
  Subscription({
    this.id = 0,
    required this.kind,
    required this.sourceId,
    this.title = '',
    this.cover = '',
    this.lastCheckedAt = 0,
    this.lastBvid = '',
    this.enabled = true,
    this.autoDownload = false,
    this.quality = 80,
    this.codec = 'avc',
    this.wantVideo = true,
    this.wantAudio = true,
    this.wantCover = false,
    this.wantDanmaku = true,
    this.wantSubtitle = false,
  });

  int id;
  SubscriptionKind kind;

  /// mid / mid:seasonId / mediaId / ssId，与订阅类型配合唯一确定资源
  String sourceId;

  String title;
  String cover;

  /// 上次检查时间（毫秒）
  int lastCheckedAt;

  /// 上次发现的最新一条的内容标识，仅用于快速展示与排查
  String lastBvid;

  bool enabled;

  /// false（默认）= 只发通知；true = 发现新内容后自动创建下载任务
  bool autoDownload;

  int quality;
  String codec;
  bool wantVideo;
  bool wantAudio;
  bool wantCover;
  bool wantDanmaku;
  bool wantSubtitle;

  int get flags {
    var value = 0;
    if (wantVideo) value |= DownloadFlags.video;
    if (wantAudio) value |= DownloadFlags.audio;
    if (wantCover) value |= DownloadFlags.cover;
    if (wantDanmaku) value |= DownloadFlags.danmaku;
    if (wantSubtitle) value |= DownloadFlags.subtitle;
    return value;
  }

  bool get wantAny => wantVideo || wantAudio;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id == 0 ? null : id,
        'kind': kind.name,
        'source_id': sourceId,
        'title': title,
        'cover': cover,
        'last_checked_at': lastCheckedAt,
        'last_bvid': lastBvid,
        'enabled': enabled ? 1 : 0,
        'auto_download': autoDownload ? 1 : 0,
        'quality': quality,
        'codec': codec,
        'want_video': wantVideo ? 1 : 0,
        'want_audio': wantAudio ? 1 : 0,
        'want_cover': wantCover ? 1 : 0,
        'want_danmaku': wantDanmaku ? 1 : 0,
        'want_subtitle': wantSubtitle ? 1 : 0,
      };

  static Subscription fromMap(Map<String, Object?> map) {
    return Subscription(
      id: (map['id'] as int?) ?? 0,
      kind: SubscriptionKind.fromName(map['kind'] as String?) ??
          SubscriptionKind.space,
      sourceId: (map['source_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      cover: (map['cover'] as String?) ?? '',
      lastCheckedAt: (map['last_checked_at'] as int?) ?? 0,
      lastBvid: (map['last_bvid'] as String?) ?? '',
      enabled: ((map['enabled'] as int?) ?? 1) == 1,
      autoDownload: ((map['auto_download'] as int?) ?? 0) == 1,
      quality: (map['quality'] as int?) ?? 80,
      codec: (map['codec'] as String?) ?? 'avc',
      wantVideo: ((map['want_video'] as int?) ?? 1) == 1,
      wantAudio: ((map['want_audio'] as int?) ?? 1) == 1,
      wantCover: ((map['want_cover'] as int?) ?? 0) == 1,
      wantDanmaku: ((map['want_danmaku'] as int?) ?? 1) == 1,
      wantSubtitle: ((map['want_subtitle'] as int?) ?? 0) == 1,
    );
  }
}

/// 订阅已发现的一条内容。
///
/// 判重键是 `bvid + epId` 的组合，而不是单独的 bvid——
/// 番剧条目 **没有 bvid**（见 `BiliApi.history()` 里 `business == 'pgc'` 的分支，
/// 那里只能写 `bvid: ''` 并靠 `epId` 标识），只存 bvid 会让所有番剧条目互相覆盖。
class SeenItem {
  SeenItem({
    required this.subscriptionId,
    required this.bvid,
    this.epId,
    this.title = '',
    this.cover = '',
    this.durationMs = 0,
    this.cid = 0,
    this.discoveredAt = 0,
    this.downloaded = false,
  });

  final int subscriptionId;
  final String bvid;
  final int? epId;
  final String title;
  final String cover;
  final int durationMs;
  final int cid;
  final int discoveredAt;
  final bool downloaded;

  /// 与数据库主键一致的判重键
  String get key => '$bvid|${epId ?? 0}';

  Map<String, Object?> toMap() => <String, Object?>{
        'subscription_id': subscriptionId,
        'bvid': bvid,
        // 存 0 而不是 NULL：SQLite 的联合主键里 NULL 互不相等，
        // 用 NULL 会让同一条番剧记录被反复插入
        'ep_id': epId ?? 0,
        'title': title,
        'cover': cover,
        'duration_ms': durationMs,
        'cid': cid,
        'discovered_at': discoveredAt,
        'downloaded': downloaded ? 1 : 0,
      };

  static SeenItem fromMap(Map<String, Object?> map) {
    final epId = (map['ep_id'] as int?) ?? 0;
    return SeenItem(
      subscriptionId: (map['subscription_id'] as int?) ?? 0,
      bvid: (map['bvid'] as String?) ?? '',
      epId: epId == 0 ? null : epId,
      title: (map['title'] as String?) ?? '',
      cover: (map['cover'] as String?) ?? '',
      durationMs: (map['duration_ms'] as int?) ?? 0,
      cid: (map['cid'] as int?) ?? 0,
      discoveredAt: (map['discovered_at'] as int?) ?? 0,
      downloaded: ((map['downloaded'] as int?) ?? 0) == 1,
    );
  }
}
