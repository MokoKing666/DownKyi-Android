import 'package:shared_preferences/shared_preferences.dart';

/// 下载归档（参考 BBDownT 的 `--save-archives-to-file`）。
///
/// 解决的问题：任务列表里「清理已完成」之后，同一个视频还能被再次加入下载——
/// 对追更场景尤其浪费：每周订阅检查都会把已经下过的旧视频再下一遍。
///
/// 归档记录的是**媒体本身**的身份（BV / 分P / 清晰度 / 编码 / 音轨），
/// 不含弹幕、字幕这些「附加资源」配置——所以「上次下了带弹幕的，这次想下不带的」
/// 也会被跳过。这是刻意的：归档的语义是「这个文件我已经有了」，
/// 附加资源随时可以在工具箱里补。
///
/// 存储上限 [maxEntries] 条，超出后丢弃最旧的记录（FIFO）。
class DownloadArchive {
  DownloadArchive._();

  static final DownloadArchive instance = DownloadArchive._();

  static const String _kKey = 'download_archive';

  /// 归档条目上限。5000 条大约对应重度用户一两年的下载量，够用了；
  /// 超出后丢最旧的——最旧的恰好是最不可能重下的。
  static const int maxEntries = 5000;

  /// 媒体身份：同一 BV 同一分P、同样的清晰度/编码/音轨，视为同一个文件。
  static String mediaKey({
    required String bvid,
    required int cid,
    int? epId,
    required int quality,
    required String codec,
    int? audioId,
  }) {
    return '$bvid|${epId ?? 0}|$cid|$quality|$codec|${audioId ?? 0}';
  }

  Future<List<String>> _loadList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kKey) ?? <String>[];
  }

  Future<bool> contains(String key) async => (await _loadList()).contains(key);

  Future<int> get length async => (await _loadList()).length;

  Future<void> add(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    if (list.contains(key)) return;
    list.add(key);
    await prefs.setStringList(_kKey, trim(list, maxEntries));
  }

  /// 清空归档，返回清掉的条数（给「清除归档」按钮做反馈）
  Future<int> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getStringList(_kKey) ?? const <String>[]).length;
    await prefs.remove(_kKey);
    return count;
  }

  /// 超出上限时丢弃最旧的记录（FIFO）。抽成纯函数便于单测。
  static List<String> trim(List<String> list, int cap) {
    if (list.length <= cap) return List<String>.of(list);
    return list.sublist(list.length - cap);
  }
}
