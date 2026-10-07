import 'package:flutter/foundation.dart';

/// 底部导航选中项。
///
/// 换肤时整棵子树会重建（让 const widget 也能拿到新配色），
/// 把选中态放在这里可以保证换主题后仍停留在原来的标签页。
class ShellController extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  set index(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }

  void select(int value) => index = value;
}
