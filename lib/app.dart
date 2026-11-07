import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'core/constants.dart';
import 'data/settings_store.dart';
import 'ui/home_shell.dart';
import 'ui/td.dart';
import 'ui/theme.dart';

class DownKyiApp extends StatefulWidget {
  const DownKyiApp({super.key});

  @override
  State<DownKyiApp> createState() => _DownKyiAppState();
}

class _DownKyiAppState extends State<DownKyiApp> with WidgetsBindingObserver {
  Brightness _platform = Brightness.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next != _platform && mounted) {
      setState(() => _platform = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    // 「跟随系统深色模式」：系统切到深色时自动套用主题黑，否则用用户选定的主题
    final style = settings.followSystemDark && _platform == Brightness.dark
        ? AppThemeStyle.darkBlack
        : settings.themeStyle;
    final tokens = AppThemeTokens.of(style);

    // 子组件在 build 时直接读 TdPalette 静态字段，因此必须在构建子树之前注入
    TdPalette.apply(tokens);

    // 1.x 的主题走 Material ThemeData（TThemeData 以 ThemeExtension 注入），
    // 不再有 TDTheme 包裹组件
    final tTheme = buildTThemeData(tokens);
    return MaterialApp(
      // 换肤时重建整棵子树：否则 const widget 会继续沿用旧配色
      key: ValueKey<String>('theme-${style.name}'),
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: (tokens.brightness == Brightness.dark
              ? TThemeBuilder.dark(tTheme)
              : TThemeBuilder.light(tTheme))
          .copyWith(
        colorScheme: tokens.colorScheme,
        scaffoldBackgroundColor: tokens.pageBackground,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const HomeShell(),
    );
  }
}
