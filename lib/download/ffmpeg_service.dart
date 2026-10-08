import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

import '../core/constants.dart';
import '../core/logger.dart';

/// 探测到的媒体信息
class MediaProbe {
  const MediaProbe({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.videoCodec,
    required this.audioCodec,
    required this.format,
    required this.hasVideo,
    required this.hasAudio,
  });

  final int durationMs;
  final int width;
  final int height;
  final String videoCodec;
  final String audioCodec;
  final String format;
  final bool hasVideo;
  final bool hasAudio;

  String get resolutionLabel =>
      (width > 0 && height > 0) ? '${width}x$height' : '';

  String get summary {
    final parts = <String>[
      if (resolutionLabel.isNotEmpty) resolutionLabel,
      if (videoCodec.isNotEmpty) videoCodec.toUpperCase(),
      if (audioCodec.isNotEmpty) audioCodec.toUpperCase(),
    ];
    return parts.join(' · ');
  }
}

/// 一次 FFmpeg 执行的结果
class FfmpegResult {
  const FfmpegResult({
    required this.success,
    required this.cancelled,
    required this.message,
  });

  final bool success;
  final bool cancelled;
  final String message;
}

/// FFmpeg / FFprobe 封装：格式转换、转码、提取音频、生成 GIF。
///
/// 底层是 ffmpeg_kit_flutter_new（ffmpeg-kit 的社区维护分支，含完整 GPL 编解码器，
/// 因此 libx264 / libx265 / libmp3lame 都可用）。
class FfmpegService {
  FfmpegService._();

  static int? _currentSession;

  /// 是否正在执行任务
  static bool get isBusy => _currentSession != null;

  /// 探测媒体信息（时长 / 分辨率 / 编码）
  static Future<MediaProbe?> probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return null;

      var width = 0;
      var height = 0;
      var videoCodec = '';
      var audioCodec = '';
      var hasVideo = false;
      var hasAudio = false;

      for (final stream in info.getStreams()) {
        final type = stream.getType() ?? '';
        if (type == 'video' && !hasVideo) {
          hasVideo = true;
          videoCodec = stream.getCodec() ?? '';
          width = stream.getWidth() ?? 0;
          height = stream.getHeight() ?? 0;
        } else if (type == 'audio' && !hasAudio) {
          hasAudio = true;
          audioCodec = stream.getCodec() ?? '';
        }
      }

      return MediaProbe(
        durationMs: _secondsToMs(info.getDuration()),
        width: width,
        height: height,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        format: info.getFormat() ?? '',
        hasVideo: hasVideo,
        hasAudio: hasAudio,
      );
    } catch (error) {
      AppLog.e('FFmpeg', '探测失败：$path', error);
      return null;
    }
  }

  /// 执行一次转换。
  ///
  /// [totalMs] 用于换算进度；[onProgress] 回调 0~1。
  static Future<FfmpegResult> convert({
    required String input,
    required ConvertTarget target,
    required String output,
    int gifFps = 12,
    int totalMs = 0,
    void Function(double progress)? onProgress,
  }) async {
    final args = buildArguments(
      input: input,
      target: target,
      output: output,
      gifFps: gifFps,
    );
    return run(args, totalMs: totalMs, onProgress: onProgress);
  }

  /// 按目标格式拼装 FFmpeg 参数（用 List 传参，避免路径里的空格 / 引号被误解析）
  static List<String> buildArguments({
    required String input,
    required ConvertTarget target,
    required String output,
    int gifFps = 12,
  }) {
    switch (target) {
      case ConvertTarget.mp4Copy:
        return <String>[
          '-y',
          '-i',
          input,
          '-c',
          'copy',
          '-movflags',
          '+faststart',
          output,
        ];
      case ConvertTarget.mkvCopy:
        return <String>['-y', '-i', input, '-c', 'copy', output];
      case ConvertTarget.mp3:
        return <String>[
          '-y',
          '-i',
          input,
          '-vn',
          '-c:a',
          'libmp3lame',
          '-b:a',
          '192k',
          output,
        ];
      case ConvertTarget.m4a:
        return <String>[
          '-y',
          '-i',
          input,
          '-vn',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          output,
        ];
      case ConvertTarget.gif:
        final fps = gifFps.clamp(5, 30);
        return <String>[
          '-y',
          '-i',
          input,
          '-t',
          '10',
          '-vf',
          'fps=$fps,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
          '-loop',
          '0',
          output,
        ];
      case ConvertTarget.compress:
        return <String>[
          '-y',
          '-i',
          input,
          '-c:v',
          'libx264',
          '-crf',
          '26',
          '-preset',
          'veryfast',
          '-vf',
          'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          '-movflags',
          '+faststart',
          output,
        ];
      case ConvertTarget.avcToHevc:
        return <String>[
          '-y',
          '-i',
          input,
          '-c:v',
          'libx265',
          '-crf',
          '26',
          '-preset',
          'veryfast',
          '-tag:v',
          'hvc1',
          '-c:a',
          'copy',
          output,
        ];
      case ConvertTarget.hevcToAvc:
        return <String>[
          '-y',
          '-i',
          input,
          '-c:v',
          'libx264',
          '-crf',
          '23',
          '-preset',
          'veryfast',
          '-vf',
          'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '-c:a',
          'copy',
          '-movflags',
          '+faststart',
          output,
        ];
    }
  }

  /// 直接执行一组 FFmpeg 参数
  static Future<FfmpegResult> run(
    List<String> arguments, {
    int totalMs = 0,
    void Function(double progress)? onProgress,
  }) async {
    if (_currentSession != null) {
      return const FfmpegResult(
          success: false, cancelled: false, message: '已有转换任务正在执行');
    }
    AppLog.d('FFmpeg', '执行：${FFmpegKitConfig.argumentsToString(arguments)}');

    final completer = Completer<FfmpegResult>();
    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (FFmpegSession finished) {
          unawaited(_finish(finished, completer));
        },
        null,
        (Statistics statistics) {
          if (onProgress == null || totalMs <= 0) return;
          final done = statistics.getTime();
          if (done <= 0) return;
          onProgress((done / totalMs).clamp(0.0, 1.0));
        },
      );
      _currentSession = session.getSessionId();
      return await completer.future;
    } catch (error) {
      AppLog.e('FFmpeg', '执行失败', error);
      return FfmpegResult(success: false, cancelled: false, message: '$error');
    } finally {
      _currentSession = null;
    }
  }

  /// 取消当前任务
  static Future<void> cancel() async {
    final sessionId = _currentSession;
    if (sessionId == null) return;
    try {
      await FFmpegKit.cancel(sessionId);
    } catch (error) {
      AppLog.e('FFmpeg', '取消失败', error);
    }
  }

  static Future<void> _finish(
      FFmpegSession session, Completer<FfmpegResult> completer) async {
    if (completer.isCompleted) return;
    try {
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput() ?? '';
      if (ReturnCode.isSuccess(returnCode)) {
        completer.complete(
            const FfmpegResult(success: true, cancelled: false, message: ''));
        return;
      }
      if (ReturnCode.isCancel(returnCode)) {
        completer.complete(const FfmpegResult(
            success: false, cancelled: true, message: '已取消'));
        return;
      }
      completer.complete(
        FfmpegResult(
            success: false, cancelled: false, message: _tailOf(output)),
      );
    } catch (error) {
      completer.complete(
          FfmpegResult(success: false, cancelled: false, message: '$error'));
    }
  }

  /// 取日志末尾几行作为错误提示（FFmpeg 的真正原因通常在最后）
  static String _tailOf(String output) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return 'FFmpeg 执行失败，未返回错误信息';
    final start = lines.length > 3 ? lines.length - 3 : 0;
    return lines.sublist(start).join('\n');
  }

  /// FFprobe 返回的时长是「秒」的字符串
  static int _secondsToMs(String? seconds) {
    if (seconds == null || seconds.isEmpty) return 0;
    final value = double.tryParse(seconds);
    if (value == null || value <= 0) return 0;
    return (value * 1000).round();
  }
}
