import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../ui/theme.dart';
import 'http_client.dart';

/// 应用设置，持久化在 SharedPreferences。
class SettingsStore extends ChangeNotifier {
  static const String _kDir = 'download_dir';
  static const String _kSaveLocation = 'save_location';
  static const String _kConcurrentTasks = 'concurrent_tasks';
  static const String _kSegments = 'segment_concurrency';
  static const String _kQuality = 'default_quality';
  static const String _kCodec = 'codec_preference';
  static const String _kDanmaku = 'danmaku_format';
  static const String _kVideo = 'download_video';
  static const String _kAudio = 'download_audio';
  static const String _kCover = 'download_cover';
  static const String _kSubtitle = 'download_subtitle';
  static const String _kDanmakuEnable = 'download_danmaku';
  static const String _kMerge = 'merge_av';
  static const String _kWifiOnly = 'wifi_only';
  static const String _kTemplate = 'file_name_template';
  static const String _kCookie = 'cookie_header';
  static const String _kThemeStyle = 'theme_style';
  static const String _kFollowSystemDark = 'follow_system_dark';
  static const String _kEngine = 'download_engine';
  static const String _kAria2Url = 'aria2_rpc_url';
  static const String _kAria2Secret = 'aria2_rpc_secret';
  static const String _kAria2Split = 'aria2_split';
  static const String _kAria2Dir = 'aria2_dir';
  static const String _kGifFps = 'convert_gif_fps';
  static const String _kSubCheck = 'subscription_check_enabled';
  static const String _kSubInterval = 'subscription_interval_hours';

  static const String defaultAria2Url = 'http://127.0.0.1:6800/jsonrpc';

  /// 自定义下载目录（仅 [SaveLocation.custom] 时生效）
  String downloadDir = '';

  /// 保存位置：默认「系统相册」
  SaveLocation saveLocation = SaveLocation.gallery;

  int concurrentTasks = 2;
  int segmentConcurrency = 8;
  int defaultQuality = 80;
  String codecPreference = 'avc';
  DanmakuFormat danmakuFormat = DanmakuFormat.ass;
  bool downloadVideo = true;
  bool downloadAudio = true;
  bool downloadCover = true;
  bool downloadSubtitle = false;
  bool downloadDanmaku = true;
  bool mergeAv = true;
  bool wifiOnly = false;
  String fileNameTemplate = '{title}';

  /// 主题风格，默认「简洁白」
  AppThemeStyle themeStyle = AppThemeStyle.simpleWhite;

  /// 系统切到深色模式时是否自动套用「主题黑」
  bool followSystemDark = true;

  /// 下载引擎：内置 / Aria2
  DownloadEngine downloadEngine = DownloadEngine.builtin;

  String aria2RpcUrl = defaultAria2Url;
  String aria2Secret = '';

  /// aria2 单文件连接数（--split）
  int aria2Split = 16;

  /// aria2 落盘目录（aria2 所在设备上的路径；留空则用 aria2 自己的默认目录）
  String aria2Dir = '';

  /// GIF 生成帧率
  int gifFps = 12;

  /// 是否开启订阅的周期后台检查
  bool subscriptionCheckEnabled = true;

  /// 订阅检查间隔（小时）。WorkManager 的周期下限是 15 分钟，这里最短 1 小时
  int subscriptionIntervalHours = 6;

  /// 可选的检查间隔
  static const List<int> subscriptionIntervalOptions = <int>[1, 3, 6, 12, 24];

  bool _loaded = false;

  bool get loaded => _loaded;

  /// 默认保存到系统相册
  bool get saveToGallery => saveLocation == SaveLocation.gallery;

  bool get usesCustomDir => saveLocation == SaveLocation.custom && downloadDir.isNotEmpty;

  static const List<String> templates = <String>[
    '{title}',
    '{title}_{quality}',
    '{owner}_{title}',
    '{owner}_{title}_{quality}',
  ];

  String describeTemplate(String template) => template
      .replaceAll('{title}', '视频标题')
      .replaceAll('{quality}', '清晰度')
      .replaceAll('{owner}', 'UP 主');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    downloadDir = prefs.getString(_kDir) ?? '';
    saveLocation = SaveLocation.fromName(prefs.getString(_kSaveLocation));
    concurrentTasks = prefs.getInt(_kConcurrentTasks) ?? 2;
    segmentConcurrency = prefs.getInt(_kSegments) ?? 8;
    defaultQuality = prefs.getInt(_kQuality) ?? 80;
    codecPreference = prefs.getString(_kCodec) ?? 'avc';
    downloadVideo = prefs.getBool(_kVideo) ?? true;
    downloadAudio = prefs.getBool(_kAudio) ?? true;
    downloadCover = prefs.getBool(_kCover) ?? true;
    downloadSubtitle = prefs.getBool(_kSubtitle) ?? false;
    downloadDanmaku = prefs.getBool(_kDanmakuEnable) ?? true;
    mergeAv = prefs.getBool(_kMerge) ?? true;
    wifiOnly = prefs.getBool(_kWifiOnly) ?? false;
    fileNameTemplate = prefs.getString(_kTemplate) ?? '{title}';
    themeStyle = AppThemeStyle.fromName(prefs.getString(_kThemeStyle));
    followSystemDark = prefs.getBool(_kFollowSystemDark) ?? true;
    downloadEngine = DownloadEngine.fromName(prefs.getString(_kEngine));
    aria2RpcUrl = prefs.getString(_kAria2Url) ?? defaultAria2Url;
    aria2Secret = prefs.getString(_kAria2Secret) ?? '';
    aria2Split = prefs.getInt(_kAria2Split) ?? 16;
    aria2Dir = prefs.getString(_kAria2Dir) ?? '';
    gifFps = prefs.getInt(_kGifFps) ?? 12;
    subscriptionCheckEnabled = prefs.getBool(_kSubCheck) ?? true;
    subscriptionIntervalHours = prefs.getInt(_kSubInterval) ?? 6;

    final savedFormat = prefs.getString(_kDanmaku) ?? DanmakuFormat.ass.name;
    danmakuFormat = DanmakuFormat.values.firstWhere(
      (value) => value.name == savedFormat,
      orElse: () => DanmakuFormat.ass,
    );

    // Cookie 恢复
    final cookie = prefs.getString(_kCookie) ?? '';
    if (cookie.isNotEmpty) {
      AppHttp.instance.setCookieHeader(cookie);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDir, downloadDir);
    await prefs.setString(_kSaveLocation, saveLocation.name);
    await prefs.setInt(_kConcurrentTasks, concurrentTasks);
    await prefs.setInt(_kSegments, segmentConcurrency);
    await prefs.setInt(_kQuality, defaultQuality);
    await prefs.setString(_kCodec, codecPreference);
    await prefs.setString(_kDanmaku, danmakuFormat.name);
    await prefs.setBool(_kVideo, downloadVideo);
    await prefs.setBool(_kAudio, downloadAudio);
    await prefs.setBool(_kCover, downloadCover);
    await prefs.setBool(_kSubtitle, downloadSubtitle);
    await prefs.setBool(_kDanmakuEnable, downloadDanmaku);
    await prefs.setBool(_kMerge, mergeAv);
    await prefs.setBool(_kWifiOnly, wifiOnly);
    await prefs.setString(_kTemplate, fileNameTemplate);
    await prefs.setString(_kThemeStyle, themeStyle.name);
    await prefs.setBool(_kFollowSystemDark, followSystemDark);
    await prefs.setString(_kEngine, downloadEngine.name);
    await prefs.setString(_kAria2Url, aria2RpcUrl);
    await prefs.setString(_kAria2Secret, aria2Secret);
    await prefs.setInt(_kAria2Split, aria2Split);
    await prefs.setString(_kAria2Dir, aria2Dir);
    await prefs.setInt(_kGifFps, gifFps);
    await prefs.setBool(_kSubCheck, subscriptionCheckEnabled);
    await prefs.setInt(_kSubInterval, subscriptionIntervalHours);
    await prefs.setString(_kCookie, AppHttp.instance.cookieHeader);
  }

  Future<void> saveCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCookie, AppHttp.instance.cookieHeader);
  }

  Future<void> clearCookies() async {
    AppHttp.instance.clearCookies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCookie);
    notifyListeners();
  }

  Future<void> update(void Function() change) async {
    change();
    notifyListeners();
    await persist();
  }

  String get codecLabel => BiliConst.codecNames.entries
      .firstWhere(
        (entry) => _codecKey(entry.key) == codecPreference,
        orElse: () => const MapEntry(7, 'AVC / H.264'),
      )
      .value;

  static String _codecKey(int id) => switch (id) {
        12 => 'hevc',
        13 => 'av1',
        _ => 'avc',
      };
}
