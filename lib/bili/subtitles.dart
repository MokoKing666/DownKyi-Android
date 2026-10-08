import 'models.dart';

/// 字幕语言（评审第 21 项）。
///
/// 此前字幕策略是写死的：只挑中文，挑不到就放弃。问题是
/// **B 站对同一件事有多种写法**——简体用过 `zh-CN` 和 `zh-Hans`，
/// AI 字幕是 `ai-zh`，繁体是 `zh-Hant` / `zh-TW` / `zh-HK`。
/// 直接字符串比较会漏掉一大半，表现成「明明有字幕却说没有」。
///
/// 所以这里先归一化再匹配，并支持多选（要中英双语时就下两份）。
class SubtitleLanguage {
  const SubtitleLanguage(this.code, this.label);

  /// 归一化之后的短码，同时用作字幕文件名后缀
  final String code;
  final String label;

  static const List<SubtitleLanguage> all = <SubtitleLanguage>[
    SubtitleLanguage('zh-Hans', '简体中文'),
    SubtitleLanguage('zh-Hant', '繁体中文'),
    SubtitleLanguage('en-US', 'English'),
    SubtitleLanguage('ja', '日本語'),
    SubtitleLanguage('ko', '한국어'),
    SubtitleLanguage('ai-zh', 'AI 简体中文'),
  ];

  /// 默认只要简体
  static const String defaultCode = 'zh-Hans';

  static SubtitleLanguage? of(String code) {
    for (final item in all) {
      if (item.code == code) return item;
    }
    return null;
  }

  static String labelOf(String code) => of(code)?.label ?? code;

  /// 把 B 站返回的 `lan` 归一到本套短码。
  /// 无法识别时返回原文的小写形式，这样界面上至少不会显示空白。
  static String normalize(String lan) {
    final code = lan.trim().toLowerCase();
    if (code.isEmpty) return '';
    if (code == 'ai-zh' || code == 'ai-en') return code;
    if (code.startsWith('zh')) {
      if (code.contains('hant') ||
          code.contains('tw') ||
          code.contains('hk') ||
          code.contains('mo')) {
        return 'zh-Hant';
      }
      return 'zh-Hans';
    }
    if (code.startsWith('en')) return 'en-US';
    if (code.startsWith('ja')) return 'ja';
    if (code.startsWith('ko')) return 'ko';
    return code;
  }

  /// 按用户想要的语言挑字幕。
  ///
  /// - 顺序按 [wanted]，保证「主要语言」排在前面
  /// - 同一语言的人工字幕优先于 AI 字幕（[SubtitleItem.isAi]）
  /// - 每种语言只取一条
  static List<SubtitleItem> select(
    List<SubtitleItem> available,
    List<String> wanted,
  ) {
    if (wanted.isEmpty || available.isEmpty) return const <SubtitleItem>[];

    final result = <SubtitleItem>[];
    for (final code in wanted) {
      SubtitleItem? best;
      for (final item in available) {
        if (normalize(item.lan) != code) continue;
        // 人工字幕优先；都是人工或都是 AI 时保留先出现的那条
        if (best == null || (best.isAi && !item.isAi)) best = item;
      }
      if (best != null) result.add(best);
    }
    return result;
  }

  /// 可用字幕里有哪些语言（去重，按 [all] 的顺序）
  static List<String> availableCodes(List<SubtitleItem> items) {
    final found = <String>{for (final item in items) normalize(item.lan)};
    final ordered = <String>[
      ...all.map((item) => item.code).where(found.contains),
      ...found.where((code) => of(code) == null),
    ];
    return ordered.where((code) => code.isNotEmpty).toList();
  }

  /// 字幕文件后缀，例如 `video.zh-Hans.srt`
  static String fileSuffix(String code) => code.replaceAll('/', '-');
}
