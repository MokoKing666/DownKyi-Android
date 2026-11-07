/// 把用户粘贴的内容识别成 B 站资源类型。
library;

enum LinkKind {
  video, // BV / av
  bangumiEp, // ep
  bangumiSeason, // ss
  cheese, // 课程
  favorites, // 收藏夹
  space, // UP 主空间
  season, // UP 主合集
  shortLink, // b23.tv 短链
  unknown,
}

class LinkInfo {
  const LinkInfo(this.kind, {this.id, this.raw = '', this.page});

  final LinkKind kind;
  final String? id;
  final String raw;
  final int? page;

  bool get isSupported => kind != LinkKind.unknown;

  String get describe => switch (kind) {
        LinkKind.video => '视频 $id',
        LinkKind.bangumiEp => '番剧剧集 ep$id',
        LinkKind.bangumiSeason => '番剧合集 ss$id',
        LinkKind.cheese => '课程 $id',
        LinkKind.favorites => '收藏夹 $id',
        LinkKind.space => 'UP 主空间 $id',
        LinkKind.season => '合集 $id',
        LinkKind.shortLink => '短链 $raw',
        LinkKind.unknown => '未识别的链接',
      };
}

final RegExp _bvReg = RegExp(r'BV[0-9A-Za-z]{10}');
final RegExp _avReg = RegExp(r'av(\d+)', caseSensitive: false);
final RegExp _epReg = RegExp(r'ep(\d+)', caseSensitive: false);
final RegExp _ssReg = RegExp(r'ss(\d+)', caseSensitive: false);
final RegExp _favReg = RegExp(r'(?:fid|media_id|fav_id)=(\d+)');
final RegExp _spaceReg = RegExp(r'space\.bilibili\.com/(\d+)');
final RegExp _seasonReg = RegExp(r'/(\d+)/lists/(\d+)');
final RegExp _shortReg = RegExp(r'(?:b23\.tv|bili2233\.cn)/([0-9A-Za-z]+)');
final RegExp _pageReg = RegExp(r'[?&]p=(\d+)');

LinkInfo parseLink(String input) {
  final text = input.trim();
  if (text.isEmpty) return const LinkInfo(LinkKind.unknown);

  final page = _pageReg.firstMatch(text)?.group(1);
  final pageIndex = page == null ? null : int.tryParse(page);

  // 短链优先处理（需要网络跟随跳转）
  final short = _shortReg.firstMatch(text);
  if (short != null) {
    return LinkInfo(LinkKind.shortLink,
        id: short.group(1), raw: text, page: pageIndex);
  }

  final isCheese = text.contains('/cheese/') || text.contains('pugv');

  final bv = _bvReg.firstMatch(text);
  if (bv != null) {
    return LinkInfo(LinkKind.video,
        id: bv.group(0), raw: text, page: pageIndex);
  }
  final av = _avReg.firstMatch(text);
  if (av != null && !text.toLowerCase().contains('/cheese/')) {
    return LinkInfo(LinkKind.video,
        id: 'av${av.group(1)}', raw: text, page: pageIndex);
  }

  final ep = _epReg.firstMatch(text);
  if (ep != null) {
    return LinkInfo(
      isCheese ? LinkKind.cheese : LinkKind.bangumiEp,
      id: ep.group(1),
      raw: text,
      page: pageIndex,
    );
  }
  final ss = _ssReg.firstMatch(text);
  if (ss != null) {
    return LinkInfo(
      isCheese ? LinkKind.cheese : LinkKind.bangumiSeason,
      id: ss.group(1),
      raw: text,
      page: pageIndex,
    );
  }

  final fav = _favReg.firstMatch(text);
  if (fav != null) {
    return LinkInfo(LinkKind.favorites, id: fav.group(1), raw: text);
  }

  final season = _seasonReg.firstMatch(text);
  if (season != null) {
    return LinkInfo(LinkKind.season,
        id: '${season.group(1)}:${season.group(2)}', raw: text);
  }

  final space = _spaceReg.firstMatch(text);
  if (space != null) {
    return LinkInfo(LinkKind.space, id: space.group(1), raw: text);
  }

  // 纯数字：视为收藏夹 id
  if (RegExp(r'^\d{4,}$').hasMatch(text)) {
    return LinkInfo(LinkKind.favorites, id: text, raw: text);
  }

  return LinkInfo(LinkKind.unknown, raw: text, page: pageIndex);
}
