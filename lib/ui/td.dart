import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'theme.dart';

/// 当前生效的色板。根组件在 build 时调用 [TdPalette.apply] 注入，
/// 因此整个工程只需改主题定义，不必改业务代码。
class TdPalette {
  const TdPalette._();

  static AppThemeTokens _tokens = AppThemeTokens.simpleWhite;

  /// 当前色板（供主题选择器等需要读取原始令牌的地方使用）
  static AppThemeTokens get tokens => _tokens;

  /// 换肤入口：根组件在构建子树之前调用
  static void apply(AppThemeTokens tokens) {
    _tokens = tokens;
  }

  static Color get brand => _tokens.brand;
  static Color get brandHover => _tokens.brandHover;
  static Color get brandActive => _tokens.brandActive;
  static Color get brandLight => _tokens.brandLight;

  static Color get success => _tokens.success;
  static Color get successLight => _tokens.successLight;
  static Color get warning => _tokens.warning;
  static Color get warningLight => _tokens.warningLight;
  static Color get error => _tokens.error;
  static Color get errorLight => _tokens.errorLight;

  static Color get pageBackground => _tokens.pageBackground;
  static Color get container => _tokens.container;
  static Color get containerAlt => _tokens.containerAlt;
  static Color get navBackground => _tokens.navBackground;

  static Color get textPrimary => _tokens.textPrimary;
  static Color get textSecondary => _tokens.textSecondary;
  static Color get textPlaceholder => _tokens.textPlaceholder;
  static Color get textDisabled => _tokens.textDisabled;

  static Color get gray1 => _tokens.gray1;
  static Color get gray2 => _tokens.gray2;
  static Color get gray3 => _tokens.gray3;
  static Color get gray4 => _tokens.gray4;
  static Color get gray6 => _tokens.gray6;
  static Color get gray8 => _tokens.gray8;
  static Color get gray10 => _tokens.gray10;

  static Color get border => _tokens.border;
  static Color get divider => _tokens.divider;
  static Color get cardBorder => _tokens.cardBorder;

  /// 是否深色主题
  static bool get isDark => _tokens.brightness == Brightness.dark;
}

class TdRadius {
  const TdRadius._();

  static const double small = 3;
  static const double medium = 6;
  static const double large = 9;
  static const double extraLarge = 12;
  static const double round = 999;
}

class TdSpacer {
  const TdSpacer._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double small = 12;
  static const double medium = 16;
  static const double large = 24;
  static const double xl = 32;
}

/// 文字样式。改为 getter 以便跟随主题实时取色。
class TdText {
  const TdText._();

  static TextStyle get display => TextStyle(
      fontSize: 32, fontWeight: FontWeight.w600, color: TdPalette.textPrimary);

  static TextStyle get titleLarge => TextStyle(
      fontSize: 20, fontWeight: FontWeight.w600, color: TdPalette.textPrimary);

  static TextStyle get titleMedium => TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, color: TdPalette.textPrimary);

  static TextStyle get titleSmall => TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: TdPalette.textPrimary);

  static TextStyle get bodyLarge =>
      TextStyle(fontSize: 16, color: TdPalette.textPrimary, height: 1.5);

  static TextStyle get bodyMedium =>
      TextStyle(fontSize: 14, color: TdPalette.textPrimary, height: 1.5);

  static TextStyle get bodySmall =>
      TextStyle(fontSize: 12, color: TdPalette.textSecondary, height: 1.5);
}

/// 统一页面骨架：TDesign 导航栏 + 页面底色
class TdPage extends StatelessWidget {
  const TdPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
    this.showDivider = false,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final List<TNavBarItem>? actions;
  final bool showBack;
  final bool showDivider;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? TdPalette.pageBackground,
      body: Column(
        children: <Widget>[
          Container(
            color: TdPalette.navBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  TNavBar(
                    title: Text(title, style: TdText.titleSmall),
                    useDefaultBack: showBack,
                    onBack: showBack
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: actions,
                  ),
                  if (showDivider)
                    Divider(height: 0.5, color: TdPalette.divider),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 卡片（TDesign Container）。
///
/// 简洁白主题下卡片与页面同为白色，因此统一加一层极细描边来区分层次。
class TdSection extends StatelessWidget {
  const TdSection({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(TdSpacer.medium),
    this.margin = const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: BorderRadius.circular(TdRadius.large),
        border: Border.all(color: TdPalette.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(title!, style: TdText.titleSmall),
            const SizedBox(height: TdSpacer.small),
          ],
          child,
        ],
      ),
    );
  }
}

/// 开关行（标题 + 说明 + TSwitch）
class TdSwitchRow extends StatelessWidget {
  const TdSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.showDivider = true,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: TdText.bodyLarge),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(description!, style: TdText.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: TdSpacer.small),
              TSwitch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 0.5, color: TdPalette.divider),
      ],
    );
  }
}

/// 官方 `TCheckbox` 的统一入口。
///
/// 1.x 的 TCheckbox 不再无条件垫底色块，暗色模式下的
/// 「圆圈外面多出一块方框」问题随组件重写消失，这里只做参数收口。
class TdCheckboxField extends StatelessWidget {
  const TdCheckboxField({
    super.key,
    required this.checked,
    required this.onChanged,
    this.title,
    this.subTitle,
    this.subTitleMaxLine = 2,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? title;
  final String? subTitle;
  final int subTitleMaxLine;

  @override
  Widget build(BuildContext context) {
    return TCheckbox(
      value: checked,
      size: TCheckboxSize.small,
      showDivider: false,
      title: title,
      subTitle: subTitle,
      subTitleMaxLines: subTitleMaxLine,
      onChanged: (value) => onChanged(value ?? false),
    );
  }
}

/// 勾选行
class TdCheckRow extends StatelessWidget {
  const TdCheckRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // 整行用官方 TCell：hover 反馈、行内边距、标题/说明排版都交给组件库。
    return TCell(
      title: Text(title, style: TdText.bodyMedium),
      subtitle: description == null
          ? null
          : Text(
              description!,
              style:
                  TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
            ),
      prefix: TdCheckboxField(checked: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

/// 小标签。
///
/// 1.x 的 TTag 不再支持直接覆盖任意文字/底色（只剩 colorPreset 配色），
/// 而调用点需要自定义配色，因此这里用轻量容器自绘。
class TdLabel extends StatelessWidget {
  const TdLabel(this.text, {super.key, this.color, this.background});

  final String text;

  /// 为空时取主题强调色
  final Color? color;

  /// 为空时取主题强调色浅底
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? TdPalette.brandLight,
        borderRadius: BorderRadius.circular(TdRadius.small),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          color: color ?? TdPalette.brand,
        ),
      ),
    );
  }
}

/// 主按钮行
class TdPrimaryAction extends StatelessWidget {
  const TdPrimaryAction({
    super.key,
    required this.text,
    required this.onTap,
    this.loading = false,
    this.danger = false,
  });

  final String text;
  final VoidCallback? onTap;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: TdSpacer.medium, vertical: TdSpacer.small),
      child: SizedBox(
        width: double.infinity,
        child: TButton(
          size: TButtonSize.large,
          colorPreset:
              danger ? TButtonColorPreset.danger : TButtonColorPreset.primary,
          onPressed: loading || onTap == null ? null : onTap,
          child: Text(loading ? '处理中…' : text),
        ),
      ),
    );
  }
}

/// 空状态
class TdEmptyView extends StatelessWidget {
  const TdEmptyView(
      {super.key, required this.text, this.operationText, this.onTap});

  final String text;
  final String? operationText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TEmpty(
        emptyText: text,
        operation: operationText == null
            ? null
            : TButton(
                variant: TButtonVariant.outline,
                onPressed: onTap,
                child: Text(operationText!),
              ),
      ),
    );
  }
}

/// 加载中
class TdLoadingView extends StatelessWidget {
  const TdLoadingView({super.key, this.text = '加载中'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TdSpacer.large),
        child: TLoading(size: 24, icon: TLoadingIcon.circle, text: text),
      ),
    );
  }
}

/// 确认弹窗。
///
/// 直接转发到官方 `TDialog`：按钮样式、圆角、遮罩、危险色
/// 都由组件库按当前主题决定，我们不再自绘一套。
Future<bool> tdConfirm(
  BuildContext context, {
  required String title,
  String? content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final result = await TDialog.show<bool>(
    context,
    dialog: TDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: <TDialogAction>[
        TDialogAction(
          child: Text(cancelText),
          result: false,
        ),
        TDialogAction(
          child: Text(confirmText),
          result: true,
          role: danger
              ? TDialogActionRole.destructive
              : TDialogActionRole.primary,
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 轻提示
void tdToast(BuildContext context, String message) {
  TToast.showText(message, context: context);
}

void tdToastSuccess(BuildContext context, String message) {
  TToast.showSuccess(message, context: context);
}

void tdToastError(BuildContext context, String message) {
  TToast.showFail(message, context: context);
}

/// 加载提示的实例 id（TToast 需要 id 才能定点关闭）
String? _loadingToastId;

void tdLoadingShow(BuildContext context, {String text = '请稍候'}) {
  _loadingToastId = TToast.showLoading(context: context, text: text);
}

void tdLoadingHide() {
  final id = _loadingToastId;
  if (id == null) return;
  _loadingToastId = null;
  TToast.dismissToast(id);
}
