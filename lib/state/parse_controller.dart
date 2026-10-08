import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/link_parser.dart';
import '../core/logger.dart';
import '../data/bili_api.dart';
import '../data/http_client.dart';
import '../data/models.dart';
import '../data/settings_store.dart';
import '../download/download_manager.dart';

/// 解析流程控制器：链接 -> 视频 / 批量列表 -> 创建下载任务。
class ParseController extends ChangeNotifier {
  ParseController(
      {required this.api, required this.manager, required this.settings});

  final BiliApi api;
  final DownloadManager manager;
  final SettingsStore settings;

  bool loading = false;
  bool loadingMore = false;
  String? error;
  String? message;

  VideoDetail? video;
  BatchResult? batch;
  DashInfo? dash;

  int quality = 80;
  String qualityName = '';
  String codec = 'avc';
  int? audioId;

  bool wantVideo = true;
  bool wantAudio = true;
  bool wantCover = true;
  bool wantDanmaku = true;
  bool wantSubtitle = false;

  final Set<int> selectedPages = <int>{};
  final Set<String> selectedKeys = <String>{};

  LinkKind? sourceKind;
  String? sourceId;

  bool get hasResult => video != null || batch != null;

  bool get isBatch => batch != null;

  int get selectedCount =>
      batch != null ? selectedKeys.length : selectedPages.length;

  List<int> get availableQualities {
    final info = dash;
    if (info == null) return const <int>[];
    final ids = info.videos.map((item) => item.id).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (ids.isNotEmpty) return ids;
    return info.qualityList;
  }

  List<String> get availableCodecs {
    final info = dash;
    if (info == null) return const <String>['avc'];
    final families =
        info.videosOf(quality).map((item) => item.codecFamily).toSet().toList();
    if (families.isEmpty) {
      families
          .addAll(info.videos.map((item) => item.codecFamily).toSet().toList());
    }
    if (families.isEmpty) families.add('avc');
    families.sort();
    return families;
  }

  List<DashStream> get availableAudios {
    final info = dash;
    if (info == null) return const <DashStream>[];
    final list = <DashStream>[
      if (info.flac != null) info.flac!,
      if (info.dolby != null) info.dolby!,
      ...info.audios,
    ]..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return list;
  }

  String qualityLabel(int value) {
    final fromApi = dash?.supportFormats[value];
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    return BiliConst.qualityNames[value] ?? '$value';
  }

  // ------------------------------------------------------------------
  // 解析
  // ------------------------------------------------------------------

  Future<bool> parse(String input) async {
    loading = true;
    error = null;
    message = null;
    video = null;
    batch = null;
    dash = null;
    referenceTitle = null;
    referenceError = null;
    selectedPages.clear();
    selectedKeys.clear();
    notifyListeners();

    try {
      var link = parseLink(input);
      if (link.kind == LinkKind.shortLink) {
        final target =
            link.raw.contains('http') ? link.raw : 'https://${link.raw}';
        final resolved = await api.resolveShortLink(target);
        link = parseLink(resolved);
      }
      if (!link.isSupported || link.id == null) {
        error =
            '无法识别的链接。支持 BV 号 / 视频链接 / 番剧 ep、ss / 收藏夹 / UP 主空间 / 合集 / b23 短链';
        return false;
      }
      sourceKind = link.kind;
      sourceId = link.id;

      switch (link.kind) {
        case LinkKind.video:
          final detail = await api.videoDetail(link.id!);
          video = detail;
          final index = (link.page ?? 1) - 1;
          selectedPages
              .add(index >= 0 && index < detail.pages.length ? index : 0);
          break;

        case LinkKind.bangumiEp:
        case LinkKind.cheese:
          final isCheese = link.kind == LinkKind.cheese;
          final result = await api.seasonInfo(
              isCheese: isCheese, epId: int.parse(link.id!));
          _applyEpisode(result.season, result.rawEpisodes, link.id!, isCheese);
          if (result.items.length > 1) {
            // 同时保留整季列表，便于批量下载
            message = '该链接是单集，如需整季可在结果页切换到「整季列表」';
          }
          break;

        case LinkKind.bangumiSeason:
          final seasonResult = await api.seasonInfo(
              isCheese: false, seasonId: int.parse(link.id!));
          batch = BatchResult(
            title: asString(seasonResult.season['title'], '番剧'),
            cover: normalizeUrl(asString(seasonResult.season['cover'])),
            items: seasonResult.items,
            btype: BiliConst.typeBangumi,
            seasonId: asInt(seasonResult.season['season_id']),
          );
          _selectAllDefault();
          break;

        case LinkKind.favorites:
          batch = await api.favResources(mediaId: int.parse(link.id!));
          _selectAllDefault();
          break;

        case LinkKind.space:
          batch = await api.spaceArchives(mid: int.parse(link.id!));
          _selectAllDefault();
          break;

        case LinkKind.season:
          final parts = link.id!.split(':');
          batch = await api.seasonArchives(
            mid: int.parse(parts[0]),
            seasonId: int.parse(parts[1]),
          );
          _selectAllDefault();
          break;

        case LinkKind.shortLink:
        case LinkKind.unknown:
          error = '暂不支持该类型链接';
          return false;
      }

      if (video != null) {
        await loadQualities();
        applyDefaultOptions();
      } else if (batch != null) {
        _primeBatchDefaults();
      }
      return true;
    } catch (exception) {
      error =
          exception is ApiException ? exception.message : exception.toString();
      AppLog.e('Parse', '解析失败', exception);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _applyEpisode(
    Map<String, dynamic> season,
    List<Map<String, dynamic>> episodes,
    String epId,
    bool isCheese,
  ) {
    var index =
        episodes.indexWhere((item) => asInt(item['id']).toString() == epId);
    if (index < 0) index = 0;
    if (episodes.isEmpty) {
      throw ApiException(-1, '未获取到剧集信息，可能需要大会员或该内容已下架');
    }
    video = VideoDetail.fromEpisode(
      season,
      episodes[index],
      btype: isCheese ? BiliConst.typeCheese : BiliConst.typeBangumi,
    );
    selectedPages.add(0);
  }

  void _selectAllDefault() {
    selectedKeys.clear();
    for (final item in batch?.items ?? const <MediaItem>[]) {
      selectedKeys.add(_keyOf(item));
    }
  }

  /// 直接设置批量列表（历史 / 稍后再看等一次性数据）
  void setBatchDirectly(BatchResult? value) {
    batch = value;
    video = null;
    dash = null;
    referenceTitle = null;
    referenceError = null;
    sourceKind = null;
    sourceId = null;
    _selectAllDefault();
    if (value != null) _primeBatchDefaults();
    notifyListeners();
  }

  /// 批量入口（收藏夹 / 合集 / 历史 / 稍后再看 / 整季）没有「解析结果页」，
  /// 这里按设置补齐清晰度与下载项，否则会用字段初始值（80 / avc）去下载。
  void _primeBatchDefaults() {
    quality = settings.defaultQuality;
    codec = settings.codecPreference;
    qualityName = qualityLabel(quality);
    audioId = null;
    applyDefaultOptions();
  }

  /// 批量下载时作为「可选项参考」的视频标题（在选项面板上说明来源）
  String? referenceTitle;

  /// 参考视频解析失败的原因，用于在面板上向用户解释为什么退回通用档位
  String? referenceError;

  /// 批量列表中第一个被选中的条目
  MediaItem? get firstSelectedItem {
    for (final item in batch?.items ?? const <MediaItem>[]) {
      if (isBatchSelected(item)) return item;
    }
    return null;
  }

  /// 解析批量下载的「参考视频」，取回真实的清晰度 / 编码 / 音轨列表。
  ///
  /// 批量下载共用一套设置，逐个解析 N 个视频既慢也没有意义，所以只解析第一个选中项：
  /// 选项面板据此列出**该视频确实支持**的档位（避免出现「视频没有 8K 却给出 8K 选项」），
  /// 其余视频在下载时由 `DashInfo.pickVideo` / `pickAudio` 自动回退到各自可用的档位。
  ///
  /// 返回 false 表示没取到数据（未登录 / 会员内容 / 网络异常），
  /// 调用方应退回通用档位并向用户说明原因。
  Future<bool> loadBatchReference() async {
    final item = firstSelectedItem;
    referenceTitle = item?.title;
    referenceError = null;
    dash = null;
    if (item == null) {
      referenceError = '没有选中任何视频';
      notifyListeners();
      return false;
    }
    try {
      var cid = item.cid;
      if (cid <= 0) {
        // UP 主投稿 / 合集接口不返回 cid，先补一次详情查询
        if (item.bvid.isEmpty) throw ApiException(-1, '缺少 cid 与 bvid，无法获取播放地址');
        cid = (await api.videoDetail(item.bvid)).cid;
      }
      if (cid <= 0) throw ApiException(-1, '无法获取该视频的 cid，可能已下架');

      dash = await api.playUrl(
        btype: item.btype,
        cid: cid,
        bvid: item.bvid,
        epId: item.epId,
        quality: settings.defaultQuality,
      );

      final available = availableQualities;
      quality = available.contains(settings.defaultQuality)
          ? settings.defaultQuality
          : (available.isEmpty ? settings.defaultQuality : available.first);
      qualityName = qualityLabel(quality);
      codec = settings.codecPreference;
      final codecs = availableCodecs;
      if (codecs.isNotEmpty && !codecs.contains(codec)) codec = codecs.first;
      final audios = availableAudios;
      audioId = audios.isEmpty ? null : audios.first.id;
      notifyListeners();
      return true;
    } catch (exception) {
      dash = null;
      referenceError =
          exception is ApiException ? exception.message : '$exception';
      AppLog.e('Parse', '批量参考视频解析失败', exception);
      notifyListeners();
      return false;
    }
  }

  String _keyOf(MediaItem item) => '${item.bvid}_${item.cid}_${item.epId ?? 0}';

  /// 拉取清晰度 / 编码 / 音轨列表
  Future<void> loadQualities() async {
    final detail = video;
    if (detail == null) return;
    final index = selectedPages.isEmpty
        ? 0
        : selectedPages.reduce((a, b) => a < b ? a : b);
    final page =
        index < detail.pages.length ? detail.pages[index] : detail.pages.first;
    try {
      dash = await api.playUrl(
        btype: detail.btype,
        cid: page.cid,
        bvid: detail.bvid,
        epId: detail.epId,
        quality: settings.defaultQuality,
      );
      final available = availableQualities;
      if (available.isNotEmpty) {
        quality = available.contains(settings.defaultQuality)
            ? settings.defaultQuality
            : available.first;
      }
      qualityName = qualityLabel(quality);
      codec = settings.codecPreference;
      final audios = availableAudios;
      audioId = audios.isEmpty ? null : audios.first.id;
      error = null;
    } catch (exception) {
      dash = null;
      error =
          exception is ApiException ? exception.message : exception.toString();
      AppLog.e('Parse', '获取清晰度失败', exception);
    }
    notifyListeners();
  }

  void applyDefaultOptions() {
    wantVideo = settings.downloadVideo;
    wantAudio = settings.downloadAudio;
    wantCover = settings.downloadCover;
    wantDanmaku = settings.downloadDanmaku;
    wantSubtitle = settings.downloadSubtitle;
    notifyListeners();
  }

  /// 仅刷新 UI（选项被逐个切换时使用）
  void touch() => notifyListeners();

  int buildFlags() {
    var flags = 0;
    if (wantVideo) flags |= DownloadFlags.video;
    if (wantAudio) flags |= DownloadFlags.audio;
    if (wantCover) flags |= DownloadFlags.cover;
    if (wantDanmaku) flags |= DownloadFlags.danmaku;
    if (wantSubtitle) flags |= DownloadFlags.subtitle;
    return flags;
  }

  void setQuality(int value) {
    quality = value;
    qualityName = qualityLabel(value);
    final codecs = availableCodecs;
    if (codecs.isNotEmpty && !codecs.contains(codec)) {
      codec = codecs.first;
    }
    notifyListeners();
  }

  void setCodec(String value) {
    codec = value;
    notifyListeners();
  }

  void setAudioId(int? value) {
    audioId = value;
    notifyListeners();
  }

  void togglePage(int index) {
    if (selectedPages.contains(index)) {
      selectedPages.remove(index);
    } else {
      selectedPages.add(index);
    }
    notifyListeners();
  }

  void selectAllPages(bool value) {
    final total = video?.pages.length ?? 0;
    selectedPages.clear();
    if (value) {
      for (var index = 0; index < total; index++) {
        selectedPages.add(index);
      }
    }
    notifyListeners();
  }

  void toggleBatchItem(MediaItem item) {
    final key = _keyOf(item);
    if (selectedKeys.contains(key)) {
      selectedKeys.remove(key);
    } else {
      selectedKeys.add(key);
    }
    notifyListeners();
  }

  void selectAllBatch(bool value) {
    selectedKeys.clear();
    if (value) {
      for (final item in batch?.items ?? const <MediaItem>[]) {
        selectedKeys.add(_keyOf(item));
      }
    }
    notifyListeners();
  }

  bool isBatchSelected(MediaItem item) => selectedKeys.contains(_keyOf(item));

  Future<void> loadMore() async {
    final current = batch;
    final kind = sourceKind;
    if (current == null || kind == null || !current.hasMore || loadingMore)
      return;
    loadingMore = true;
    notifyListeners();
    try {
      final nextPage = current.page + 1;
      BatchResult? next;
      switch (kind) {
        case LinkKind.favorites:
          next = await api.favResources(
              mediaId: current.mediaId ?? 0, page: nextPage);
          break;
        case LinkKind.space:
          next = await api.spaceArchives(mid: current.mid ?? 0, page: nextPage);
          break;
        case LinkKind.season:
          next = await api.seasonArchives(
            mid: current.mid ?? 0,
            seasonId: current.seasonId ?? 0,
            name: current.title,
            page: nextPage,
          );
          break;
        default:
          break;
      }
      if (next != null) {
        batch = current.copyWith(
          items: <MediaItem>[...current.items, ...next.items],
          hasMore: next.hasMore,
          page: nextPage,
        );
        _selectAllDefault();
      }
    } catch (exception) {
      AppLog.e('Parse', '加载更多失败', exception);
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // 创建任务
  // ------------------------------------------------------------------

  Future<int> enqueueVideo() async {
    final detail = video;
    if (detail == null) return 0;
    final pages = detail.pages;
    final indexes =
        selectedPages.isEmpty ? <int>[0] : (selectedPages.toList()..sort());
    var count = 0;
    for (final index in indexes) {
      if (index < 0 || index >= pages.length) continue;
      final page = pages[index];
      final item = MediaItem(
        bvid: detail.bvid,
        cid: page.cid,
        aid: detail.aid,
        title:
            pages.length > 1 ? '${detail.title} - ${page.part}' : detail.title,
        cover: detail.cover,
        durationMs: page.durationMs,
        ownerName: detail.ownerName,
        btype: detail.btype,
        epId: detail.epId,
      );
      final task = await manager.enqueue(
        item: item,
        quality: quality,
        qualityName: qualityName,
        audioId: audioId,
        codec: codec,
        flags: buildFlags(),
      );
      if (task != null) count++;
    }
    return count;
  }

  Future<int> enqueueBatch() async {
    final current = batch;
    if (current == null) return 0;
    var count = 0;
    for (final item in current.items) {
      if (!isBatchSelected(item)) continue;
      final task = await manager.enqueue(
        item: item,
        quality: quality,
        qualityName: qualityName.isEmpty ? qualityLabel(quality) : qualityName,
        audioId: audioId,
        codec: codec,
        flags: buildFlags(),
      );
      if (task != null) count++;
    }
    return count;
  }

  void reset() {
    video = null;
    batch = null;
    dash = null;
    referenceTitle = null;
    referenceError = null;
    error = null;
    message = null;
    selectedPages.clear();
    selectedKeys.clear();
    notifyListeners();
  }
}
