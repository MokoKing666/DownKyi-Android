import '../core/constants.dart';

/// 任务状态
enum TaskStatus {
  queued,
  running,
  paused,
  merging,
  completed,
  failed;

  String get label => switch (this) {
        TaskStatus.queued => '等待中',
        TaskStatus.running => '下载中',
        TaskStatus.paused => '已暂停',
        TaskStatus.merging => '合并中',
        TaskStatus.completed => '已完成',
        TaskStatus.failed => '失败',
      };

  static TaskStatus fromName(String? name) {
    for (final value in TaskStatus.values) {
      if (value.name == name) return value;
    }
    return TaskStatus.queued;
  }
}

/// 下载任务。字段较多，这里用可变类而不是 copyWith，便于高频更新进度。
class DownloadTask {
  DownloadTask({
    this.id = 0,
    required this.key,
    required this.title,
    this.subTitle = '',
    this.cover = '',
    this.owner = '',
    this.bvid = '',
    required this.cid,
    this.epId,
    this.btype = BiliConst.typeVideo,
    this.durationMs = 0,
    this.quality = 80,
    this.qualityName = '',
    this.audioId,
    this.codec = 'avc',
    required this.flags,
    this.danmakuFormat = DanmakuFormat.ass,
    this.status = TaskStatus.queued,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speed = 0,
    this.videoPath,
    this.audioPath,
    this.outputPath,
    this.error,
    this.videoSegments,
    this.audioSegments,
    this.fileName = '',
    this.createdAt = 0,
    this.finishedAt = 0,
    this.merged = true,
    this.aria2Gid,
    this.exported = false,
    this.exportedPath,
    this.extrasError,
  });

  int id;
  final String key;
  final String title;
  final String subTitle;
  final String cover;
  final String owner;
  final String bvid;

  /// 分 P 的 cid。部分列表接口不返回 cid，下载前会补查并回写。
  int cid;
  final int? epId;
  final String btype;
  final int durationMs;
  final int quality;
  final String qualityName;
  final int? audioId;
  final String codec;
  final int flags;
  final DanmakuFormat danmakuFormat;

  /// 任务创建时按命名模板计算，之后可变
  String fileName;

  TaskStatus status;
  int totalBytes;
  int downloadedBytes;
  int speed;
  String? videoPath;
  String? audioPath;
  String? outputPath;
  String? error;
  String? videoSegments;
  String? audioSegments;
  int createdAt;
  int finishedAt;
  bool merged;

  /// 使用 Aria2 引擎时的任务 gid（用于轮询进度 / 暂停 / 删除）
  String? aria2Gid;

  /// 是否已导出到系统相册
  bool exported;

  /// 导出后系统媒体库的位置（content uri 或公共路径）
  String? exportedPath;

  /// 附加资源（封面 / 弹幕 / 字幕）里失败的项目，顿号分隔。
  ///
  /// 视频本体成功但某一项附加资源失败时，过去仍然只显示「已完成」，
  /// 用户以为一切正常。现在把失败项记下来并显示成「已完成（弹幕未成功）」。
  String? extrasError;

  /// 视频本体完成，但附加资源有失败项——UI 应显示为「有警告的完成」。
  ///
  /// 没有新增 `TaskStatus` 枚举值：状态机在 12 处被引用（已完成列表、计数、
  /// 缓存保护规则等），新增枚举值需要同步改动全部调用点，漏一处就会出现
  /// 任务不显示「已完成」或缓存误删。用派生态表达同样的语义更安全。
  bool get completedWithWarnings =>
      status == TaskStatus.completed && (extrasError?.isNotEmpty ?? false);

  bool get wantVideo => flags & DownloadFlags.video != 0;
  bool get wantAudio => flags & DownloadFlags.audio != 0;
  bool get wantCover => flags & DownloadFlags.cover != 0;
  bool get wantDanmaku =>
      flags & DownloadFlags.danmaku != 0 && danmakuFormat != DanmakuFormat.none;
  bool get wantSubtitle => flags & DownloadFlags.subtitle != 0;

  bool get isFinished => status == TaskStatus.completed;
  bool get isActive =>
      status == TaskStatus.running || status == TaskStatus.merging;

  double get progress {
    if (totalBytes <= 0) {
      return status == TaskStatus.completed ? 1 : 0;
    }
    final value = downloadedBytes / totalBytes;
    return value.clamp(0, 1);
  }

  int get remainSeconds {
    if (speed <= 0 || totalBytes <= 0) return -1;
    final remain = totalBytes - downloadedBytes;
    if (remain <= 0) return 0;
    return remain ~/ speed;
  }

  /// 展示用副标题：分P 名 / UP 主 / 清晰度
  String get displaySubTitle {
    final parts = <String>[
      if (subTitle.isNotEmpty) subTitle,
      if (owner.isNotEmpty) owner,
      if (qualityName.isNotEmpty) qualityName,
    ];
    return parts.join(' · ');
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id == 0 ? null : id,
        'task_key': key,
        'title': title,
        'sub_title': subTitle,
        'cover': cover,
        'owner': owner,
        'bvid': bvid,
        'cid': cid,
        'ep_id': epId,
        'btype': btype,
        'duration_ms': durationMs,
        'quality': quality,
        'quality_name': qualityName,
        'audio_id': audioId,
        'codec': codec,
        'flags': flags,
        'danmaku_format': danmakuFormat.name,
        'status': status.name,
        'total_bytes': totalBytes,
        'downloaded_bytes': downloadedBytes,
        'video_path': videoPath,
        'audio_path': audioPath,
        'output_path': outputPath,
        'error': error,
        'video_segments': videoSegments,
        'audio_segments': audioSegments,
        'file_name': fileName,
        'created_at': createdAt,
        'finished_at': finishedAt,
        'merged': merged ? 1 : 0,
        'aria2_gid': aria2Gid,
        'exported': exported ? 1 : 0,
        'exported_path': exportedPath,
        'extras_error': extrasError,
      };

  factory DownloadTask.fromMap(Map<String, Object?> map) => DownloadTask(
        id: (map['id'] as int?) ?? 0,
        key: (map['task_key'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        subTitle: (map['sub_title'] as String?) ?? '',
        cover: (map['cover'] as String?) ?? '',
        owner: (map['owner'] as String?) ?? '',
        bvid: (map['bvid'] as String?) ?? '',
        cid: (map['cid'] as int?) ?? 0,
        epId: map['ep_id'] as int?,
        btype: (map['btype'] as String?) ?? BiliConst.typeVideo,
        durationMs: (map['duration_ms'] as int?) ?? 0,
        quality: (map['quality'] as int?) ?? 80,
        qualityName: (map['quality_name'] as String?) ?? '',
        audioId: map['audio_id'] as int?,
        codec: (map['codec'] as String?) ?? 'avc',
        flags: (map['flags'] as int?) ?? 0,
        danmakuFormat: DanmakuFormat.values.firstWhere(
          (value) => value.name == map['danmaku_format'],
          orElse: () => DanmakuFormat.ass,
        ),
        status: TaskStatus.fromName(map['status'] as String?),
        totalBytes: (map['total_bytes'] as int?) ?? 0,
        downloadedBytes: (map['downloaded_bytes'] as int?) ?? 0,
        videoPath: map['video_path'] as String?,
        audioPath: map['audio_path'] as String?,
        outputPath: map['output_path'] as String?,
        error: map['error'] as String?,
        videoSegments: map['video_segments'] as String?,
        audioSegments: map['audio_segments'] as String?,
        fileName: (map['file_name'] as String?) ?? '',
        createdAt: (map['created_at'] as int?) ?? 0,
        finishedAt: (map['finished_at'] as int?) ?? 0,
        merged: ((map['merged'] as int?) ?? 1) == 1,
        aria2Gid: map['aria2_gid'] as String?,
        exported: ((map['exported'] as int?) ?? 0) == 1,
        exportedPath: map['exported_path'] as String?,
        extrasError: map['extras_error'] as String?,
      );
}
