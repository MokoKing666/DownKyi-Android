import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../core/formatter.dart';
import '../../data/settings_store.dart';
import '../../download/download_manager.dart';
import '../../state/login_controller.dart';
import '../td.dart';
import '../widgets/theme_picker.dart';
import 'login_page.dart';
import 'settings_page.dart';

/// 我的：账号 + 主题 + 设置入口 + 关于
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginController>();
    final manager = context.watch<DownloadManager>();
    final settings = context.watch<SettingsStore>();
    final info = login.navInfo;
    final finished = manager.finishedTasks;
    final totalBytes =
        finished.fold<int>(0, (sum, task) => sum + task.totalBytes);

    return Container(
      color: TdPalette.pageBackground,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: TdSpacer.large),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(TdSpacer.medium,
                  TdSpacer.large, TdSpacer.medium, TdSpacer.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('我的', style: TdText.titleLarge)),
                  // 主题颜色按钮：打开主题选择面板
                  _ThemeButton(onTap: () => showThemePicker(context)),
                ],
              ),
            ),
            TdSection(
              child: Row(
                children: <Widget>[
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: (info?.face.isEmpty ?? true)
                          ? Container(
                              color: TdPalette.gray2,
                              child: Icon(Icons.person,
                                  color: TdPalette.gray6, size: 30),
                            )
                          : Image.network(info!.face, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: TdSpacer.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(login.isLogin ? (info?.uname ?? '已登录') : '未登录',
                            style: TdText.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          login.isLogin
                              ? 'UID ${info?.mid ?? 0} · Lv${info?.level ?? 0}'
                              : '登录后可下载 1080P+ / 4K 及会员内容',
                          style: TdText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TButton(
                    child: Text(login.isLogin ? '账号' : '登录'),
                    size: TButtonSize.small,
                    colorPreset: TButtonColorPreset.primary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            TdSection(
              child: Column(
                children: <Widget>[
                  TCell(
                    title: const Text('主题颜色'),
                    prefix: const Icon(Icons.palette_outlined),
                    note: Text(settings.themeStyle.label),
                    arrow: true,
                    onTap: () => showThemePicker(context),
                  ),
                  TCell(
                    title: const Text('已完成任务'),
                    prefix: const Icon(Icons.download_done),
                    note: Text(
                        '${finished.length} 个 · ${formatBytes(totalBytes)}'),
                  ),
                  TCell(
                    title: const Text('默认清晰度'),
                    prefix: const Icon(Icons.high_quality_outlined),
                    note: Text(
                        BiliConst.qualityNames[settings.defaultQuality] ??
                            '${settings.defaultQuality}'),
                  ),
                  TCell(
                    title: const Text('下载引擎'),
                    prefix: const Icon(Icons.memory_outlined),
                    note: Text(settings.downloadEngine.label),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            TdSection(
              child: Column(
                children: <Widget>[
                  TCell(
                    title: const Text('下载设置'),
                    prefix: const Icon(Icons.settings_outlined),
                    arrow: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage()),
                    ),
                  ),
                  TCell(
                    title: const Text('登录 / 切换账号'),
                    prefix: const Icon(Icons.account_circle_outlined),
                    arrow: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginPage()),
                    ),
                  ),
                  TCell(
                    title: const Text('关于'),
                    prefix: const Icon(Icons.info_outline),
                    note: const Text('v${AppInfo.version}'),
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TdSpacer.medium),
              child: Text(
                AppInfo.disclaimer,
                style:
                    TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    TDialog.show<void>(
      context,
      dialog: TConfirmDialog(
        title: AppInfo.name,
        contentWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('版本 v${AppInfo.version}（${AppInfo.englishName}）',
                style: TdText.bodySmall),
            const SizedBox(height: TdSpacer.xs),
            Text(
              '功能参考开源项目 DownKyi（哔哩下载姬）的跨平台版本，'
              '使用 Flutter + TDesign 实现。\n'
              '音视频封装由系统 MediaMuxer 完成；格式转换由 FFmpeg 完成；'
              '可选择内置分片下载器或 Aria2（JSON-RPC）作为下载引擎。',
              style: TdText.bodySmall,
            ),
            const SizedBox(height: TdSpacer.small),
            Text(AppInfo.disclaimer,
                style: TdText.bodySmall
                    .copyWith(color: TdPalette.textPlaceholder)),
          ],
        ),
        buttonText: '知道了',
      ),
    );
  }
}

/// 主题颜色按钮（色板图标 + 当前主题名）
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = context.watch<SettingsStore>().themeStyle;
    // 这是个按钮，不是行——所以用官方 TButton（浅色主题），
    // 圆角、内边距、按下反馈都交给组件库
    return TButton(
      child: Text(style.label),
      icon: const Icon(Icons.palette_outlined),
      colorPreset: TButtonColorPreset.light,
      size: TButtonSize.small,
      onPressed: onTap,
    );
  }
}
