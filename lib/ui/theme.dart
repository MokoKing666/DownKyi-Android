import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 哔哩哔哩粉：三套主题统一的强调色。
const Color kBrandPink = Color(0xFFFB7299);
const Color kBrandPinkHover = Color(0xFFFF8CB0);
const Color kBrandPinkActive = Color(0xFFE05C82);

/// 应用主题风格。
///
/// 原有 TDesign 蓝色主题（#0052D9）已移除，改为：
/// - [simpleWhite] 简洁白（默认）：页面与卡片大面积留白，强调色为哔哩哔哩粉
/// - [girlPink] 少女粉：哔哩哔哩粉作为主色调，柔和粉底
/// - [darkBlack] 主题黑：深色底 + 哔哩哔哩粉强调，适合夜间
enum AppThemeStyle {
  simpleWhite,
  girlPink,
  darkBlack;

  String get label => switch (this) {
        AppThemeStyle.simpleWhite => '简洁白',
        AppThemeStyle.girlPink => '少女粉',
        AppThemeStyle.darkBlack => '主题黑',
      };

  String get description => switch (this) {
        AppThemeStyle.simpleWhite => '大面积留白 + 哔哩哔哩粉点缀',
        AppThemeStyle.girlPink => '哔哩哔哩粉主色，柔和粉底',
        AppThemeStyle.darkBlack => '深色护眼，适合夜间使用',
      };

  /// 是否为深色主题（决定 SystemUI 状态栏图标明暗）
  bool get isDark => this == AppThemeStyle.darkBlack;

  /// 设置页色板预览：底色 / 容器色 / 强调色
  List<Color> get preview => switch (this) {
        AppThemeStyle.simpleWhite => const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFF1F2F3),
            kBrandPink,
          ],
        AppThemeStyle.girlPink => const <Color>[
            Color(0xFFFFE3EC),
            Color(0xFFFFF3F7),
            kBrandPink,
          ],
        AppThemeStyle.darkBlack => const <Color>[
            Color(0xFF121315),
            Color(0xFF1C1D20),
            kBrandPink,
          ],
      };

  static AppThemeStyle fromName(String? name) {
    for (final value in AppThemeStyle.values) {
      if (value.name == name) return value;
    }
    return AppThemeStyle.simpleWhite;
  }
}

/// 主题色板（Design Token）。
///
/// 三套主题共用同一组字段，组件层只读这里，因此换肤不需要改业务代码。
class AppThemeTokens {
  const AppThemeTokens({
    required this.style,
    required this.brightness,
    required this.brand,
    required this.brandHover,
    required this.brandActive,
    required this.brandLight,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.error,
    required this.errorLight,
    required this.pageBackground,
    required this.container,
    required this.containerAlt,
    required this.navBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPlaceholder,
    required this.textDisabled,
    required this.gray1,
    required this.gray2,
    required this.gray3,
    required this.gray4,
    required this.gray6,
    required this.gray8,
    required this.gray10,
    required this.border,
    required this.divider,
    required this.cardBorder,
  });

  final AppThemeStyle style;
  final Brightness brightness;

  final Color brand;
  final Color brandHover;
  final Color brandActive;
  final Color brandLight;

  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;

  final Color pageBackground;
  final Color container;

  /// 次级容器：输入框底、标签底、hover 态
  final Color containerAlt;

  /// 导航栏 / 标题栏底色
  final Color navBackground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textPlaceholder;
  final Color textDisabled;

  final Color gray1;
  final Color gray2;
  final Color gray3;
  final Color gray4;
  final Color gray6;
  final Color gray8;
  final Color gray10;

  final Color border;
  final Color divider;

  /// 卡片描边：简洁白下卡片与页面同为白色，靠描边区分层次
  final Color cardBorder;

  static AppThemeTokens of(AppThemeStyle style) => switch (style) {
        AppThemeStyle.simpleWhite => simpleWhite,
        AppThemeStyle.girlPink => girlPink,
        AppThemeStyle.darkBlack => darkBlack,
      };

  /// 简洁白（默认）：大部分色块为白色，强调色哔哩哔哩粉
  static const AppThemeTokens simpleWhite = AppThemeTokens(
    style: AppThemeStyle.simpleWhite,
    brightness: Brightness.light,
    brand: kBrandPink,
    brandHover: kBrandPinkHover,
    brandActive: kBrandPinkActive,
    brandLight: Color(0xFFFFF0F5),
    success: Color(0xFF2BA471),
    successLight: Color(0xFFE3F9E9),
    warning: Color(0xFFE37318),
    warningLight: Color(0xFFFFF1E9),
    error: Color(0xFFD54941),
    errorLight: Color(0xFFFFEEEE),
    pageBackground: Color(0xFFFFFFFF),
    container: Color(0xFFFFFFFF),
    containerAlt: Color(0xFFF7F8FA),
    navBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF18191C),
    textSecondary: Color(0xFF61666D),
    textPlaceholder: Color(0xFF9499A0),
    textDisabled: Color(0xFFC9CCD0),
    gray1: Color(0xFFF7F8FA),
    gray2: Color(0xFFF1F2F3),
    gray3: Color(0xFFE3E5E7),
    gray4: Color(0xFFD0D3D6),
    gray6: Color(0xFF9499A0),
    gray8: Color(0xFF61666D),
    gray10: Color(0xFF2F3238),
    border: Color(0xFFE3E5E7),
    divider: Color(0xFFF1F2F3),
    cardBorder: Color(0xFFF0F1F2),
  );

  /// 少女粉：哔哩哔哩粉铺开做底色
  static const AppThemeTokens girlPink = AppThemeTokens(
    style: AppThemeStyle.girlPink,
    brightness: Brightness.light,
    brand: kBrandPink,
    brandHover: kBrandPinkHover,
    brandActive: kBrandPinkActive,
    brandLight: Color(0xFFFFE3EC),
    success: Color(0xFF2BA471),
    successLight: Color(0xFFE3F9E9),
    warning: Color(0xFFE37318),
    warningLight: Color(0xFFFFF1E9),
    error: Color(0xFFD54941),
    errorLight: Color(0xFFFFEEEE),
    pageBackground: Color(0xFFFFF3F7),
    container: Color(0xFFFFFFFF),
    containerAlt: Color(0xFFFFF0F5),
    navBackground: Color(0xFFFFE3EC),
    textPrimary: Color(0xFF3D1F2B),
    textSecondary: Color(0xFF8A6274),
    textPlaceholder: Color(0xFFBFA0AD),
    textDisabled: Color(0xFFD9C2CC),
    gray1: Color(0xFFFFF3F7),
    gray2: Color(0xFFFFF0F5),
    gray3: Color(0xFFFFE3EC),
    gray4: Color(0xFFFFD6E4),
    gray6: Color(0xFFBFA0AD),
    gray8: Color(0xFF8A6274),
    gray10: Color(0xFF5A3345),
    border: Color(0xFFFFD6E4),
    divider: Color(0xFFFFE4EE),
    cardBorder: Color(0xFFFFDCE8),
  );

  /// 主题黑：深色底，哔哩哔哩粉作强调
  static const AppThemeTokens darkBlack = AppThemeTokens(
    style: AppThemeStyle.darkBlack,
    brightness: Brightness.dark,
    brand: kBrandPink,
    brandHover: kBrandPinkHover,
    brandActive: kBrandPinkActive,
    brandLight: Color(0xFF3A2230),
    success: Color(0xFF3FBF87),
    successLight: Color(0xFF1D3329),
    warning: Color(0xFFF2A15C),
    warningLight: Color(0xFF3A2A1C),
    error: Color(0xFFF0685F),
    errorLight: Color(0xFF3A2220),
    pageBackground: Color(0xFF121315),
    container: Color(0xFF1C1D20),
    containerAlt: Color(0xFF26272B),
    navBackground: Color(0xFF1C1D20),
    textPrimary: Color(0xFFF1F2F3),
    textSecondary: Color(0xFFA2A7AE),
    textPlaceholder: Color(0xFF76797E),
    textDisabled: Color(0xFF4A4D52),
    gray1: Color(0xFF1C1D20),
    gray2: Color(0xFF26272B),
    gray3: Color(0xFF2E3034),
    gray4: Color(0xFF3A3D42),
    gray6: Color(0xFF76797E),
    gray8: Color(0xFFA2A7AE),
    gray10: Color(0xFFE3E5E7),
    border: Color(0xFF2E3034),
    divider: Color(0xFF26272B),
    cardBorder: Color(0xFF2A2C30),
  );

  /// 映射到 TDesign 的 colorMap，让 TDButton / TDCell / TDSwitch 等官方组件跟随换肤。
  Map<String, Color> get tdColorMap => <String, Color>{
        // 品牌色阶：brandColor7 = 常态，6 = hover，8 = active，1~3 = 浅底
        'brandColor1': brandLight,
        'brandColor2': brandLight,
        'brandColor3': brandLight,
        'brandColor4': brandHover,
        'brandColor5': brandHover,
        'brandColor6': brandHover,
        'brandColor7': brand,
        'brandColor8': brandActive,
        'brandColor9': brandActive,
        'brandColor10': brandActive,
        // 中性色阶
        'grayColor1': gray1,
        'grayColor2': gray2,
        'grayColor3': gray3,
        'grayColor4': gray4,
        'grayColor5': gray4,
        'grayColor6': gray6,
        'grayColor7': gray6,
        'grayColor8': gray8,
        'grayColor9': gray8,
        'grayColor10': gray10,
        'grayColor11': gray10,
        'grayColor12': containerAlt,
        'grayColor13': container,
        'grayColor14': pageBackground,
        // 语义色
        'successColor1': successLight,
        'successColor5': success,
        'warningColor1': warningLight,
        'warningColor5': warning,
        'errorColor1': errorLight,
        'errorColor6': error,
        // 背景
        'bgColorPage': pageBackground,
        'bgColorContainer': container,
        'bgColorContainerSelect': container,
        'bgColorSpecialComponent': container,
        'bgColorContainerHover': containerAlt,
        'bgColorContainerActive': gray3,
        'bgColorSecondaryContainer': containerAlt,
        'bgColorSecondaryContainerHover': gray3,
        'bgColorSecondaryContainerActive': gray4,
        'bgColorComponent': containerAlt,
        'bgColorComponentHover': gray3,
        'bgColorComponentActive': gray4,
        'bgColorComponentDisabled': containerAlt,
        'bgColorSecondaryComponent': gray3,
        'bgColorSecondaryComponentHover': gray4,
        'bgColorSecondaryComponentActive': gray4,
        // 文字
        'fontGyColor1': textPrimary,
        'fontGyColor2': textSecondary,
        'fontGyColor3': textPlaceholder,
        'fontGyColor4': textDisabled,
        'textColorPrimary': textPrimary,
        'textColorSecondary': textSecondary,
        'textColorPlaceholder': textPlaceholder,
        'textDisabledColor': textDisabled,
        'textColorBrand': brand,
        'textColorLink': brandActive,
        // 描边
        'componentStrokeColor': border,
        'componentBorderColor': divider,
      };

  /// Material 层配色（TextField / AlertDialog / BottomSheet 等跟随换肤）
  ColorScheme get colorScheme => ColorScheme.fromSeed(
        seedColor: brand,
        brightness: brightness,
        surface: container,
      ).copyWith(
        primary: brand,
        surface: container,
        onSurface: textPrimary,
        outline: border,
        error: error,
      );
}

/// 按当前色板构造 TDesign 主题数据。
///
/// 通过 `copyWithTDThemeData` 在官方默认主题上覆写 colorMap，
/// 这样 TDButton / TDCell / TDSwitch 等组件会同步变成哔哩哔哩粉。
TDThemeData buildTdThemeData(AppThemeTokens tokens) {
  final base = TDThemeData.defaultData();
  final data = base.copyWithTDThemeData(
    'downkyi_${tokens.style.name}',
    colorMap: tokens.tdColorMap,
  );
  data.light = data;
  return data;
}
