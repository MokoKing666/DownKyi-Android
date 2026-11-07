import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../state/shell_controller.dart';
import 'pages/download_page.dart';
import 'pages/mine_page.dart';
import 'pages/parse_page.dart';
import 'pages/toolbox_page.dart';
import 'td.dart';

/// 主框架：TDesign 底部标签栏 + 四个页面。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const List<Widget> _pages = <Widget>[
    ParsePage(),
    DownloadPage(),
    ToolboxPage(),
    MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final index = shell.index;

    return Scaffold(
      backgroundColor: TdPalette.pageBackground,
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: TTabBar(
        type: TTabBarType.iconText,
        value: index,
        onChanged: (next) => shell.select(next),
        navigationTabs: <TTabBarItemConfig>[
          _tab(
            text: '解析',
            selected: Icons.cloud_download,
            unselected: Icons.cloud_download_outlined,
          ),
          _tab(
            text: '下载',
            selected: Icons.download_done,
            unselected: Icons.download_outlined,
          ),
          _tab(
            text: '工具',
            selected: Icons.widgets,
            unselected: Icons.widgets_outlined,
          ),
          _tab(
            text: '我的',
            selected: Icons.person,
            unselected: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  /// 选中态用主题强调色（哔哩哔哩粉），未选中用中性色
  static TTabBarItemConfig _tab({
    required String text,
    required IconData selected,
    required IconData unselected,
  }) {
    return TTabBarItemConfig(
      tabText: text,
      selectedIcon: Icon(selected, color: TdPalette.brand, size: 24),
      unselectedIcon: Icon(unselected, color: TdPalette.gray6, size: 24),
    );
  }
}
