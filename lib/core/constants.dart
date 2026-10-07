/// 全局常量：接口地址、请求头、清晰度与编码枚举。
library;

class AppInfo {
  static const String name = '哔哩哔哩下载姬';
  static const String englishName = 'DownKyi';
  static const String version = '1.3.0';
  static const String disclaimer = '本应用仅提供视频解析与本地下载能力，不提供任何内容存储服务。'
      '所有内容版权归原作者所有，仅供个人学习交流，请勿用于商业用途，并支持原始发布者。';
}

class BiliConst {
  static const String apiBase = 'https://api.bilibili.com';
  static const String passportBase = 'https://passport.bilibili.com';
  static const String webBase = 'https://www.bilibili.com';

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// DASH 全格式：16(DASH) | 64(HDR) | 128(4K) | 256(杜比音频) | 512(杜比视界) | 1024(8K) | 2048(AV1)
  static const int fnvalDash = 4048;

  static const int maxSegmentConcurrency = 8;

  /// 清晰度（qn）
  static const Map<int, String> qualityNames = {
    127: '8K 超清',
    126: '杜比视界',
    125: 'HDR 真彩',
    120: '4K 超清',
    116: '1080P60',
    112: '1080P+',
    80: '1080P 高清',
    74: '720P60',
    64: '720P 高清',
    32: '480P 清晰',
    16: '360P 流畅',
    6: '240P 最流畅',
  };

  /// 视频编码
  static const Map<int, String> codecNames = {
    7: 'AVC / H.264',
    12: 'HEVC / H.265',
    13: 'AV1',
  };

  /// 音频流 id
  static const Map<int, String> audioNames = {
    30216: '64K',
    30232: '132K',
    30280: '192K',
    30250: '杜比全景声',
    30251: 'Hi-Res 无损',
  };

  /// 番剧 / 课程 / 普通视频
  static const String typeVideo = 'video';
  static const String typeBangumi = 'bangumi';
  static const String typeCheese = 'cheese';
}

/// 弹幕转换格式
enum DanmakuFormat {
  none,
  xml,
  ass,
  txt;

  String get label => switch (this) {
        DanmakuFormat.none => '不下载',
        DanmakuFormat.xml => 'XML 原始格式',
        DanmakuFormat.ass => 'ASS 字幕（可用播放器加载）',
        DanmakuFormat.txt => 'TXT 纯文本',
      };

  String get ext => switch (this) {
        DanmakuFormat.none => '',
        DanmakuFormat.xml => 'xml',
        DanmakuFormat.ass => 'ass',
        DanmakuFormat.txt => 'txt',
      };
}

/// 下载内容勾选项
class DownloadFlags {
  static const int video = 1;
  static const int audio = 2;
  static const int cover = 4;
  static const int danmaku = 8;
  static const int subtitle = 16;
}

/// 下载引擎：内置分片下载器 / Aria2（JSON-RPC）
enum DownloadEngine {
  builtin,
  aria2;

  String get label => switch (this) {
        DownloadEngine.builtin => '内置下载器',
        DownloadEngine.aria2 => 'Aria2',
      };

  String get description => switch (this) {
        DownloadEngine.builtin => '多线程分片 + 断点续传，无需额外部署',
        DownloadEngine.aria2 => '通过 JSON-RPC 调用 aria2，支持远程 / NAS 下载',
      };

  static DownloadEngine fromName(String? name) {
    for (final value in DownloadEngine.values) {
      if (value.name == name) return value;
    }
    return DownloadEngine.builtin;
  }
}

/// 文件保存位置
enum SaveLocation {
  /// 系统相册（MediaStore：视频进 Movies/DownKyi，图片进 Pictures/DownKyi）
  gallery,

  /// 应用专属外部目录（卸载应用会一并删除）
  appDir,

  /// 用户自定义目录
  custom;

  String get label => switch (this) {
        SaveLocation.gallery => '系统相册',
        SaveLocation.appDir => '应用目录',
        SaveLocation.custom => '自定义目录',
      };

  static SaveLocation fromName(String? name) {
    for (final value in SaveLocation.values) {
      if (value.name == name) return value;
    }
    return SaveLocation.gallery;
  }
}

/// FFmpeg 格式转换目标
enum ConvertTarget {
  mp4Copy('MP4（原画无损封装）', 'mp4', 'container 不变、编码不变，只是重新封装容器'),
  mkvCopy('MKV（原画无损封装）', 'mkv', '把音视频重新封装为 Matroska，画质零损失'),
  mp3('MP3 音频', 'mp3', '提取音轨并转码为 MP3（192kbps）'),
  m4a('M4A 音频', 'm4a', '提取音轨封装为 M4A，几乎无损失'),
  gif('GIF 动图', 'gif', '截取片段生成动图，适合做表情包'),
  compress('压缩视频（H.264）', 'mp4', '用 H.264 重新编码，体积更小、兼容性更好'),
  avcToHevc('转 H.265（HEVC）', 'mp4', '体积更小，需要设备支持硬解'),
  hevcToAvc('转 H.264（AVC）', 'mp4', '把 H.265 转回 H.264，老设备也能播');

  const ConvertTarget(this.label, this.extension, this.description);

  final String label;
  final String extension;
  final String description;
}
