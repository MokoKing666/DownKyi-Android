import 'dart:async';
import 'dart:io';

import '../core/constants.dart';
import '../core/logger.dart';
import '../data/http_client.dart';
import 'danmaku_parser.dart';
import 'models.dart';
import 'wbi.dart';

/// B 站接口层。
///
/// 分层约定（改动时请保持）：
///
///   lib/bili/      B 站专有的一切——接口、签名、链接识别、数据模型、
///                  弹幕 protobuf。**B 站改接口只需动这里。**
///   lib/data/      通用持久化与传输——HTTP 客户端、任务/订阅数据库、设置。
///                  不认识 B 站的具体返回结构。
///   lib/download/  可靠下载与媒体处理。只接受 URL 与文件路径，
///                  以及 media 层已经抽象好的数据，不直接解析接口返回。
///   lib/ui/        界面。只读 state/ 与 bili/ 暴露的模型。
///
/// 现状说明：`download_manager` 仍会自己调 [playUrl] 拿地址（而不是由上层注入），
/// 这是下一步可以拆的点；但媒体与下载层已经不依赖任何 B 站返回结构了。

/// 收藏夹（文件夹）
class FavFolder {
  const FavFolder({required this.id, required this.title, required this.count});

  final int id;
  final String title;
  final int count;
}

/// UP 主合集
class SeasonSummary {
  const SeasonSummary({
    required this.seasonId,
    required this.mid,
    required this.name,
    required this.cover,
    required this.total,
  });

  final int seasonId;
  final int mid;
  final String name;
  final String cover;
  final int total;
}

/// B 站接口集合，参考 DownKyi.Core/BiliApi 的功能划分。
class BiliApi {
  BiliApi(this.http);

  final AppHttp http;
  final WbiSigner wbi = WbiSigner();

  static final BiliApi instance = BiliApi(AppHttp.instance);

  // ------------------------------------------------------------------
  // WBI 与登录态
  // ------------------------------------------------------------------

  Future<void> ensureWbiKeys({bool force = false}) async {
    if (wbi.ready && !force) return;
    final data = asMap(await http.getData('/x/web-interface/nav'));
    final wbiImg = asMap(data['wbi_img']);
    wbi.updateKeys(asString(wbiImg['img_url']), asString(wbiImg['sub_url']));
    if (wbi.ready) AppLog.d('WBI', '密钥刷新成功');
  }

  /// 申请 buvid3 / buvid4，避免部分接口返回 -352
  Future<void> ensureBuvid() async {
    if ((http.cookies['buvid3'] ?? '').isNotEmpty) return;
    try {
      final data = asMap(await http.getData('/x/frontend/finger/spi'));
      final b3 = asString(data['b_3']);
      final b4 = asString(data['b_4']);
      if (b3.isNotEmpty) http.setCookie('buvid3', b3);
      if (b4.isNotEmpty) http.setCookie('buvid4', b4);
      if (http.cookies['buvid4'] == null) {
        http.setCookie('buvid4',
            '${DateTime.now().millisecondsSinceEpoch}-${b3.hashCode}');
      }
    } catch (error) {
      AppLog.e('API', '获取 buvid 失败', error);
    }
  }

  /// 尽力做 WBI 签名。
  ///
  /// 列表 / 历史类接口在不同时期对签名的要求不一致（有的必须签，有的签了也无害），
  /// 这里统一签名；一旦密钥拿不到就退回原始参数，
  /// 避免因为签名环节失败导致这些接口整体不可用。
  Future<Map<String, String>> _sign(Map<String, String> query) async {
    try {
      await ensureWbiKeys();
      if (!wbi.ready) return query;
      return wbi.sign(query);
    } catch (error) {
      AppLog.e('WBI', '签名失败，改用未签名请求', error);
      return query;
    }
  }

  Future<NavInfo> nav() async {
    final data = asMap(await http.getData('/x/web-interface/nav'));
    return NavInfo.fromJson(data);
  }

  Future<QrLogin> qrGenerate() async {
    final json = await http.getJson(
      '/x/passport-login/web/qrcode/generate',
      host: BiliConst.passportBase,
    );
    final data = asMap(json['data']);
    return QrLogin(
        url: asString(data['url']), key: asString(data['qrcode_key']));
  }

  Future<QrPollResult> qrPoll(String key) async {
    final json = await http.getJson(
      '/x/passport-login/web/qrcode/poll',
      query: {'qrcode_key': key, 'source': 'main-fe-header'},
      host: BiliConst.passportBase,
    );
    final data = asMap(json['data']);
    final callbackUrl = asString(data['url']);
    return QrPollResult(
      code: asInt(data['code'], -1),
      message: asString(data['message'], '等待扫码'),
      cookie: callbackUrl.isEmpty ? null : callbackUrl,
    );
  }

  /// 二维码登录成功后，从回调 url 中解析出 Cookie
  void applyLoginUrl(String callbackUrl) {
    final uri = Uri.tryParse(callbackUrl);
    if (uri == null) return;
    uri.queryParameters.forEach((key, value) {
      if (key == 'SESSDATA' ||
          key == 'bili_jct' ||
          key == 'DedeUserID' ||
          key == 'DedeUserID__ckMd5') {
        http.setCookie(key, value);
      }
    });
  }

  // ------------------------------------------------------------------
  // 视频信息
  // ------------------------------------------------------------------

  Future<VideoDetail> videoDetail(String id) async {
    final isAv = id.toLowerCase().startsWith('av');
    final query = <String, String>{
      if (isAv) 'aid': id.substring(2) else 'bvid': id,
    };
    final data =
        asMap(await http.getData('/x/web-interface/view', query: query));
    return VideoDetail.fromView(data);
  }

  /// 番剧 / 课程整季信息
  Future<
      ({
        Map<String, dynamic> season,
        List<MediaItem> items,
        List<Map<String, dynamic>> rawEpisodes,
      })> seasonInfo({
    required bool isCheese,
    int? epId,
    int? seasonId,
  }) async {
    final path = isCheese ? '/pugv/view/web/season' : '/pgc/view/web/season';
    final query = <String, String>{
      if (epId != null) 'ep_id': '$epId',
      if (seasonId != null) 'season_id': '$seasonId',
    };
    final data = asMap(await http.getData(path, query: query));
    final btype = isCheese ? BiliConst.typeCheese : BiliConst.typeBangumi;
    final rawEpisodes = asList(data['episodes'])
        .map((item) => asMap(item))
        .toList(growable: false);
    final items = rawEpisodes
        .map((item) => _episodeToItem(item, btype))
        .toList(growable: false);
    return (season: data, items: items, rawEpisodes: rawEpisodes);
  }

  MediaItem _episodeToItem(Map<String, dynamic> json, String btype) {
    return MediaItem(
      bvid: asString(json['bvid']),
      cid: MediaItem.resolveCid(json),
      aid: asInt(json['aid']),
      title: asString(json['long_title'] ?? json['title'], '未命名'),
      cover: normalizeUrl(asString(json['cover'])),
      durationMs: asInt(json['duration']) * 1000,
      ownerName: asString(json['author'] ?? json['up_name']),
      btype: btype,
      epId: asInt(json['id']),
    );
  }

  // ------------------------------------------------------------------
  // 播放地址
  // ------------------------------------------------------------------

  Future<DashInfo> playUrl({
    required String btype,
    required int cid,
    String bvid = '',
    int? epId,
    int quality = 80,
  }) async {
    final baseQuery = <String, String>{
      'cid': '$cid',
      'qn': '$quality',
      'fnval': '${BiliConst.fnvalDash}',
      'fnver': '0',
      'fourk': '1',
    };
    Map<String, dynamic> json;
    switch (btype) {
      case BiliConst.typeBangumi:
        json = await http.getJson('/pgc/player/web/playurl', query: {
          ...baseQuery,
          if (epId != null) 'ep_id': '$epId',
          if (bvid.isNotEmpty) 'bvid': bvid,
          'otype': 'json',
        });
        break;
      case BiliConst.typeCheese:
        json = await http.getJson('/pugv/player/web/playurl', query: {
          ...baseQuery,
          if (epId != null) 'ep_id': '$epId',
          if (bvid.isNotEmpty) 'bvid': bvid,
          'otype': 'json',
        });
        break;
      default:
        await ensureWbiKeys();
        final signed = wbi.sign({
          ...baseQuery,
          if (bvid.isNotEmpty) 'bvid': bvid,
        });
        json = await http.getJson('/x/player/wbi/playurl', query: signed);
        break;
    }
    final data = asMap(json['data']);
    return parseDash(data);
  }

  DashInfo parseDash(Map<String, dynamic> data) {
    final dash = asMap(data['dash']);
    final videos = <DashStream>[];
    for (final item in asList(dash['video'])) {
      videos.add(DashStream.fromJson(asMap(item), isVideo: true));
    }
    final audios = <DashStream>[];
    for (final item in asList(dash['audio'])) {
      audios.add(DashStream.fromJson(asMap(item), isVideo: false));
    }
    DashStream? flac;
    final flacAudio = asMap(asMap(dash['flac'])['audio']);
    if (flacAudio.isNotEmpty) {
      flac = DashStream.fromJson(flacAudio, isVideo: false);
    }
    DashStream? dolby;
    final dolbyAudio = asMap(asMap(dash['dolby'])['audio']);
    if (dolbyAudio.isNotEmpty) {
      dolby = DashStream.fromJson(dolbyAudio, isVideo: false);
    }

    final formats = <int, String>{};
    for (final item in asList(data['support_formats'])) {
      final map = asMap(item);
      final quality = asInt(map['quality']);
      if (quality > 0) {
        formats[quality] = asString(
          map['new_description'] ?? map['display_desc'],
          BiliConst.qualityNames[quality] ?? '$quality',
        );
      }
    }

    // ⚠️ 三个来源的单位不一样，必须统一成毫秒再用：
    //   dash.duration   → **秒**（例如 3 分 38 秒的视频这里是 218）
    //   timelength      → 毫秒
    //   durl.length     → 毫秒
    // 这里曾经把 dash.duration 直接当毫秒塞进 DashInfo.durationMs，
    // 少乘了 1000，导致所有基于时长的计算都小了 1000 倍——
    // 最直观的表现是「清晰度选项上的预估体积把 MB 显示成了 KB」。
    var durationMs = asInt(dash['duration']) * 1000;
    if (durationMs <= 0) durationMs = asInt(data['timelength']);
    if (durationMs <= 0) {
      final durl = asList(data['durl']);
      if (durl.isNotEmpty) durationMs = asInt(asMap(durl.first)['length']);
    }

    return DashInfo(
      durationMs: durationMs,
      videos: videos,
      audios: audios,
      flac: flac,
      dolby: dolby,
      supportFormats: formats,
    );
  }

  /// 部分老视频 / 番剧只有 durl（FLV/MP4 直链），尝试取第一个直链
  Future<String?> plainUrl({
    required String btype,
    required int cid,
    String bvid = '',
    int? epId,
    int quality = 80,
  }) async {
    final query = <String, String>{
      'cid': '$cid',
      'qn': '$quality',
      'fnval': '0',
      'fnver': '0',
      'fourk': '1',
    };
    Map<String, dynamic> json;
    switch (btype) {
      case BiliConst.typeBangumi:
        json = await http.getJson('/pgc/player/web/playurl', query: {
          ...query,
          if (epId != null) 'ep_id': '$epId',
          'otype': 'json',
        });
        break;
      case BiliConst.typeCheese:
        json = await http.getJson('/pugv/player/web/playurl', query: {
          ...query,
          if (epId != null) 'ep_id': '$epId',
          'otype': 'json',
        });
        break;
      default:
        json = await http.getJson('/x/player/playurl', query: {
          ...query,
          if (bvid.isNotEmpty) 'bvid': bvid,
        });
        break;
    }
    final durl = asList(asMap(json['data'])['durl']);
    if (durl.isEmpty) return null;
    final url = asString(asMap(durl.first)['url']);
    return url.isEmpty ? null : normalizeUrl(url);
  }

  // ------------------------------------------------------------------
  // 字幕与弹幕
  // ------------------------------------------------------------------

  Future<List<SubtitleItem>> subtitles({
    required int cid,
    String bvid = '',
    int? epId,
  }) async {
    try {
      await ensureWbiKeys();
      final signed = wbi.sign({
        'cid': '$cid',
        if (bvid.isNotEmpty) 'bvid': bvid,
        if (epId != null) 'ep_id': '$epId',
      });
      final data = asMap(await http.getData('/x/player/wbi/v2', query: signed));
      final subtitle = asMap(data['subtitle']);
      final result = <SubtitleItem>[];
      for (final item in asList(subtitle['subtitles'])) {
        final sub = SubtitleItem.fromJson(asMap(item));
        if (sub.url.isNotEmpty) result.add(sub);
      }
      return result;
    } catch (error) {
      AppLog.e('API', '获取字幕失败', error);
      return const <SubtitleItem>[];
    }
  }

  /// 拉取字幕内容并转成 SRT
  Future<String> subtitleToSrt(String url) async {
    final data = asMap(await http.getData(url, referer: BiliConst.webBase));
    final body = asList(data['body']);
    final buffer = StringBuffer();
    var index = 1;
    for (final item in body) {
      final map = asMap(item);
      final from = _formatSrtTime((map['from'] as num?)?.toDouble() ?? 0);
      final to = _formatSrtTime((map['to'] as num?)?.toDouble() ?? 0);
      final content = asString(map['content']);
      if (content.isEmpty) continue;
      buffer.writeln('$index');
      buffer.writeln('$from --> $to');
      buffer.writeln(content);
      buffer.writeln();
      index++;
    }
    return buffer.toString();
  }

  String _formatSrtTime(double seconds) {
    final total = (seconds * 1000).round();
    final h = total ~/ 3600000;
    final m = (total % 3600000) ~/ 60000;
    final s = (total % 60000) ~/ 1000;
    final ms = total % 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)},${ms.toString().padLeft(3, '0')}';
  }

  /// 分段拉取弹幕（每段 6 分钟）
  Future<List<DanmakuItem>> danmaku({
    required int cid,
    int durationMs = 0,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final result = <DanmakuItem>[];
    final maxSegment =
        durationMs > 0 ? (durationMs / (6 * 60 * 1000)).ceil() + 1 : 30;
    for (var index = 1; index <= maxSegment; index++) {
      try {
        final bytes = await http.getBytes(http.buildUri('/x/v2/dm/web/seg.so', {
          'type': '1',
          'oid': '$cid',
          'segment_index': '$index',
        }));
        if (bytes.isEmpty) break;
        final items = DanmakuParser.parseSegment(bytes);
        if (items.isEmpty) break;
        result.addAll(items);
        onProgress?.call(result.length, durationMs);
      } catch (error) {
        AppLog.e('API', '弹幕分片 $index 失败', error);
        break;
      }
    }
    return result;
  }

  // ------------------------------------------------------------------
  // 收藏夹 / 历史 / 稍后再看 / 合集
  // ------------------------------------------------------------------

  Future<List<FavFolder>> favFolders(int mid) async {
    final data = asMap(await http.getData(
      '/x/v3/fav/folder/created/list-all',
      query: await _sign({'up_mid': '$mid'}),
    ));
    final result = <FavFolder>[];
    for (final item in asList(data['list'])) {
      final map = asMap(item);
      result.add(FavFolder(
        id: asInt(map['id']),
        title: asString(map['title'], '未命名收藏夹'),
        count: asInt(map['media_count']),
      ));
    }
    return result;
  }

  Future<BatchResult> favResources({
    required int mediaId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = asMap(await http.getData(
      '/x/v3/fav/resource/list',
      query: await _sign({
        'media_id': '$mediaId',
        'pn': '$page',
        'ps': '$pageSize',
        'platform': 'web',
        'order': 'mtime',
        'type': '0',
        'tid': '0',
      }),
    ));
    final info = asMap(data['info']);
    final items = <MediaItem>[];
    for (final item in asList(data['medias'])) {
      final map = asMap(item);
      // 失效稿件 title 为「已失效视频」
      if (asInt(map['attr']) != 0 && asString(map['bvid']).isEmpty) continue;
      items.add(MediaItem.fromJson(map));
    }
    return BatchResult(
      title: asString(info['title'], '收藏夹'),
      items: items,
      hasMore: data['has_more'] == true,
      page: page,
      mediaId: mediaId,
      mid: asInt(info['mid']),
    );
  }

  // ------------------------------------------------------------------
  // 站内搜索
  // ------------------------------------------------------------------

  /// 视频搜索。
  ///
  /// 必须用带 `wbi` 前缀的新接口 `/x/web-interface/wbi/search/type`——
  /// 不带前缀的旧接口已废弃。搜索自 2022-08 起加了大量 Cookie 校验，
  /// 字段不足会被拦截（`-412`），所以调用前需要已执行过 [ensureBuvid]。
  ///
  /// 另外接口**没有 `page_size` 参数**，每页固定 20 条，只能靠 `page` 翻页；
  /// `data.numPages` 最多 50，`numResults` 最多 1000。
  Future<BatchResult> searchVideo({
    required String keyword,
    int page = 1,
    String order = 'totalrank',
  }) async {
    final data = asMap(await http.getData(
      '/x/web-interface/wbi/search/type',
      // 搜索要求 Referer 落在 .bilibili.com 下，这里带上真实的搜索页地址
      referer:
          '${BiliConst.webBase}/search?keyword=${Uri.encodeComponent(keyword)}',
      query: await _sign({
        'search_type': 'video',
        'keyword': keyword,
        'page': '$page',
        'order': order,
      }),
    ));

    final items = <MediaItem>[];
    for (final raw in asList(data['result'])) {
      final map = asMap(raw);
      if (asString(map['type']) != 'video') continue;
      final bvid = asString(map['bvid']);
      if (bvid.isEmpty) continue;
      items.add(MediaItem(
        bvid: bvid,
        // 搜索结果不返回 cid，下载前由 DownloadManager._ensureCid 补查
        cid: 0,
        aid: asInt(map['aid'] ?? map['id']),
        title: plainTitle(asString(map['title'], '未命名')),
        cover: normalizeUrl(asString(map['pic'])),
        durationMs: durationFromText(asString(map['duration'])),
        ownerName: asString(map['author']),
      ));
    }

    return BatchResult(
      title: keyword,
      items: items,
      hasMore: page < asInt(data['numPages'], 1),
      page: page,
    );
  }

  /// 搜索结果的标题里带 `<em class="keyword">` 高亮标签，需要剥掉并还原 HTML 实体
  static String plainTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'</?em[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  /// 搜索结果的时长是 `"4:18"` / `"1:02:33"` 这样的字符串，转成毫秒
  static int durationFromText(String text) {
    if (text.isEmpty) return 0;
    var seconds = 0;
    for (final part in text.split(':')) {
      seconds = seconds * 60 + (int.tryParse(part.trim()) ?? 0);
    }
    return seconds * 1000;
  }

  /// 观看历史
  ///
  /// **字段层级是这个接口最大的坑**：新版 `history/cursor` 把
  /// `bvid` / `cid` / `oid` 全部放在 `list[i].history` 子对象里，
  /// 顶层只有 `kid`，且**根本没有 `aid` 字段**（`kid` 在番剧时是 ssid，不能当 avid 用）。
  /// 顶层 `bvid` 恒为空字符串，所以早期实现会把每一条都 `continue` 掉、
  /// 最终返回空列表（表现为「历史获取不到 / 没有可取的内容」）。
  ///
  /// 各业务类型（`history.business`）的可下载性：
  /// - `archive` 稿件：有 `bvid` + `cid`，可直接下载
  /// - `pgc` 番剧影视：没有 `bvid`，靠 `epid` 走番剧播放地址
  /// - `live` 直播 / `article` 专栏 / `article-list` 文集：不是可下载的视频，跳过
  ///
  /// 游标参数（max / view_at / business）不传表示「从当前时间开始取」。
  Future<List<MediaItem>> history({int pageSize = 30}) async {
    final data = asMap(await http.getData(
      '/x/web-interface/history/cursor',
      query: await _sign({'ps': '${pageSize.clamp(1, 30)}'}),
    ));
    final items = <MediaItem>[];
    for (final item in asList(data['list'])) {
      final map = asMap(item);
      final nested = asMap(map['history']);
      final business = asString(nested['business']);
      if (business != 'archive' && business != 'pgc') continue;

      final cid = asInt(nested['cid']);
      final oid = asInt(nested['oid']);
      final epId = asInt(nested['epid']);
      final bvid = asString(nested['bvid']);
      final title = asString(map['title'], '未命名');
      final cover = normalizeUrl(asString(map['cover']));
      final durationMs = asInt(map['duration']) * 1000;
      final ownerName = asString(map['author_name']);

      if (business == 'archive') {
        if (bvid.isEmpty || cid <= 0) continue;
        items.add(MediaItem(
          bvid: bvid,
          cid: cid,
          aid: oid,
          title: title,
          cover: cover,
          durationMs: durationMs,
          ownerName: ownerName,
        ));
      } else {
        // 番剧：没有 bvid，必须靠 epid 才能取到播放地址
        if (epId <= 0) continue;
        items.add(MediaItem(
          bvid: '',
          cid: cid,
          aid: oid,
          title: title,
          cover: cover,
          durationMs: durationMs,
          ownerName: ownerName,
          btype: BiliConst.typeBangumi,
          epId: epId,
        ));
      }
    }
    return items;
  }

  Future<List<MediaItem>> toView() async {
    final data = asMap(await http.getData(
      '/x/v2/history/toview',
      query: await _sign(const <String, String>{}),
    ));
    final items = <MediaItem>[];
    for (final item in asList(data['list'])) {
      final map = asMap(item);
      final bvid = asString(map['bvid']);
      if (bvid.isEmpty) continue;
      items.add(MediaItem(
        bvid: bvid,
        cid: MediaItem.resolveCid(map),
        aid: asInt(map['aid']),
        title: asString(map['title'], '未命名'),
        cover: normalizeUrl(asString(map['pic'])),
        durationMs: asInt(map['duration']) * 1000,
        ownerName: asString(asMap(map['owner'])['name']),
      ));
    }
    return items;
  }

  Future<List<SeasonSummary>> seasons(int mid,
      {int page = 1, int pageSize = 20}) async {
    final data = asMap(await http.getData(
      '/x/polymer/web-space/seasons_series_list',
      query: await _sign({
        'mid': '$mid',
        'page_num': '$page',
        'page_size': '$pageSize',
        'web_location': '333.1387',
      }),
    ));
    final lists = asMap(data['items_lists']);
    final result = <SeasonSummary>[];
    void collect(dynamic source) {
      for (final item in asList(source)) {
        final map = asMap(item);
        final meta = asMap(map['meta']);
        final seasonId = asInt(meta['season_id']);
        if (seasonId == 0) continue;
        result.add(SeasonSummary(
          seasonId: seasonId,
          mid: mid,
          name: asString(meta['name'], '未命名合集'),
          cover: normalizeUrl(asString(meta['cover'])),
          total: asInt(meta['total']),
        ));
      }
    }

    collect(lists['seasons_list']);
    collect(lists['series_list']);
    return result;
  }

  /// UP 主合集内容列表。
  ///
  /// [newestFirst] 对应接口的 `sort_reverse`：默认 false（按发布时间**升序**，第 1 页最旧）。
  /// 订阅检查必须传 true，否则最新内容在最后一页，只拉第 1 页永远检测不到更新。
  Future<BatchResult> seasonArchives({
    required int mid,
    required int seasonId,
    String name = '',
    int page = 1,
    int pageSize = 30,
    bool newestFirst = false,
  }) async {
    final data = asMap(await http.getData(
      '/x/polymer/web-space/seasons_archives_list',
      query: await _sign({
        'mid': '$mid',
        'season_id': '$seasonId',
        'sort_reverse': newestFirst ? 'true' : 'false',
        'page_num': '$page',
        'page_size': '$pageSize',
        'web_location': '333.1387',
      }),
    ));
    final items = <MediaItem>[];
    for (final item in asList(data['archives'])) {
      final map = asMap(item);
      items.add(MediaItem(
        bvid: asString(map['bvid']),
        // 该接口不返回 cid，下载前会由 DownloadManager 补查
        cid: MediaItem.resolveCid(map),
        aid: asInt(map['aid']),
        title: asString(map['title'], '未命名'),
        cover: normalizeUrl(asString(map['cover'])),
        durationMs: asInt(map['duration']) * 1000,
      ));
    }
    final meta = asMap(data['page']);
    final hasMore = asInt(meta['total']) > page * pageSize;
    return BatchResult(
      title: name.isEmpty ? '合集 $seasonId' : name,
      items: items,
      mid: mid,
      seasonId: seasonId,
      hasMore: hasMore,
      page: page,
    );
  }

  /// UP 主投稿
  Future<BatchResult> spaceArchives({
    required int mid,
    int page = 1,
    int pageSize = 30,
  }) async {
    await ensureWbiKeys();
    final signed = wbi.sign({
      'mid': '$mid',
      'ps': '$pageSize',
      'pn': '$page',
      'order': 'pubdate',
      'platform': 'web',
      'web_location': '1550101',
    });
    final data =
        asMap(await http.getData('/x/space/wbi/arc/search', query: signed));
    final list = asMap(data['list']);
    final items = <MediaItem>[];
    for (final item in asList(list['vlist'])) {
      final map = asMap(item);
      items.add(MediaItem(
        bvid: asString(map['bvid']),
        cid: asInt(map['cid']),
        aid: asInt(map['aid']),
        title: asString(map['title'], '未命名'),
        cover: normalizeUrl(asString(map['pic'])),
        durationMs: asInt(map['duration']) * 1000,
        ownerName: asString(map['author']),
      ));
    }
    final pageInfo = asMap(data['page']);
    return BatchResult(
      title: 'TA 的投稿',
      items: items,
      mid: mid,
      hasMore: asInt(pageInfo['count']) > page * pageSize,
      page: page,
    );
  }

  Future<String> resolveShortLink(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, BiliConst.userAgent);
      final response = await request.close();
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      return location ?? url;
    } catch (error) {
      AppLog.e('API', '解析短链失败', error);
      return url;
    } finally {
      client.close(force: true);
    }
  }
}
