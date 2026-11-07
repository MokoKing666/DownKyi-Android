import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../data/settings_store.dart';
import '../td.dart';
import '../theme.dart';

/// 主题面板返回的选择结果
class ThemePickerResult {
  const ThemePickerResult({this.style, this.followSystem});

  final AppThemeStyle? style;
  final bool? followSystem;
}

/// 弹出主题选择面板。
///
/// 换肤会重建整棵子树（让 const widget 也能拿到新配色），
/// 因此这里等面板完全关闭后再写入设置，避免在路由动画过程中拆掉 Navigator。
Future<void> showThemePicker(BuildContext context) async {
  final settings = context.read<SettingsStore>();
  final handle = TPopup.show(
    context,
    options: TPopupOptions.bottom(
      child: _ThemePickerSheet(settings: settings),
    ),
  );
  final result = await handle.result as ThemePickerResult?;
  if (result == null) return;

  // 留出面板退出动画的时间
  await Future<void>.delayed(const Duration(milliseconds: 260));
  await settings.update(() {
    final style = result.style;
    final follow = result.followSystem;
    if (style != null) settings.themeStyle = style;
    if (follow != null) settings.followSystemDark = follow;
  });
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final current = context.watch<SettingsStore>().themeStyle;
    final follow = context.watch<SettingsStore>().followSystemDark;

    return Container(
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(TdRadius.extraLarge)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TdSpacer.medium,
                TdSpacer.medium,
                TdSpacer.medium,
                TdSpacer.xs,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.palette_outlined,
                      size: 20, color: TdPalette.brand),
                  const SizedBox(width: TdSpacer.xs),
                  Text('主题颜色', style: TdText.titleSmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
              child: Text(
                '默认「简洁白」，强调色为哔哩哔哩粉；开启跟随系统后，系统切到深色会自动使用「主题黑」。',
                style:
                    TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
              ),
            ),
            const SizedBox(height: TdSpacer.xs),
            for (final style in AppThemeStyle.values)
              _ThemeOption(
                style: style,
                selected: current == style,
                onTap: () =>
                    Navigator.of(context).pop(ThemePickerResult(style: style)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
              child: TdSwitchRow(
                title: '跟随系统深色模式',
                description: '系统切换深色时自动套用「主题黑」',
                value: follow,
                showDivider: false,
                onChanged: (value) => Navigator.of(context)
                    .pop(ThemePickerResult(followSystem: value)),
              ),
            ),
            const SizedBox(height: TdSpacer.xs),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption(
      {required this.style, required this.selected, required this.onTap});

  final AppThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 官方 TCell：色板预览走 prefix，选中标记走 trailing
    return TCell(
      title: Text(style.label, style: TdText.bodyLarge),
      subtitle: Text(style.description, style: TdText.bodySmall),
      prefix: ClipRRect(
        borderRadius: BorderRadius.circular(TdRadius.medium),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Row(
            children: <Widget>[
              for (final color in style.preview)
                Expanded(child: ColoredBox(color: color)),
            ],
          ),
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: TdPalette.brand, size: 22)
          : null,
      onTap: onTap,
    );
  }
}
