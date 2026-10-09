import 'models.dart';

/// AI 字幕策略（参考 BBDownT 的 exclude / include / only）。
///
/// B 站的 AI 字幕质量参差：有些 up 主会精修，更多是纯机翻。
/// 之前我们只有「人工优先」一条路——有 AI 就拿来兜底。
/// 现在把选择权交出来：
enum AiSubtitleStrategy {
  /// 同一语言人工字幕优先，没有人工才用 AI（默认，v2.0 行为）
  preferHuman,

  /// 完全不要 AI 字幕：某语言只有 AI 时视为没有
  excludeAi,

  /// 只要 AI 字幕（少数场景：AI 字幕出得比人工快）
  onlyAi,
  ;

  String get label => switch (this) {
        AiSubtitleStrategy.preferHuman => '人工优先',
        AiSubtitleStrategy.excludeAi => '不用 AI',
        AiSubtitleStrategy.onlyAi => '只要 AI',
      };

  static AiSubtitleStrategy fromName(String? name) =>
      AiSubtitleStrategy.values.firstWhere(
        (value) => value.name == name,
        orElse: () => AiSubtitleStrategy.preferHuman,
      );
}

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
  /// - [aiStrategy] 控制 AI 字幕的取舍（见 [AiSubtitleStrategy]）
  /// - 每种语言只取一条
  static List<SubtitleItem> select(
    List<SubtitleItem> available,
    List<String> wanted, {
    AiSubtitleStrategy aiStrategy = AiSubtitleStrategy.preferHuman,
  }) {
    if (wanted.isEmpty || available.isEmpty) return const <SubtitleItem>[];

    final pool = switch (aiStrategy) {
      AiSubtitleStrategy.preferHuman => available,
      AiSubtitleStrategy.excludeAi =>
        available.where((item) => !item.isAi).toList(),
      AiSubtitleStrategy.onlyAi =>
        available.where((item) => item.isAi).toList(),
    };

    final result = <SubtitleItem>[];
    for (final code in wanted) {
      SubtitleItem? best;
      for (final item in pool) {
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
