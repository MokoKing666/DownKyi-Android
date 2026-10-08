import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../core/formatter.dart';
import '../../data/bili_api.dart';
import '../../data/download_task.dart';
import '../../data/settings_store.dart';
import '../../download/danmaku_writer.dart';
import '../../download/download_manager.dart';
import '../../download/ffmpeg_service.dart';
import '../../native/bridge.dart';
import '../td.dart';

/// 工具箱：格式转换 / 重新合并 / 转换弹幕 / 导出，均可直接点击使用。
class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<DownloadManager>();
    final tasks = manager.finishedTasks;

    return Container(
      color: TdPalette.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(TdSpacer.medium, TdSpacer.large, TdSpacer.medium, TdSpacer.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('工具箱', style: TdText.titleLarge)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: TdSpacer.large),
                children: <Widget>[
                  TdSection(
                    title: '工具（点击使用）',
                    child: Column(
                      children: <Widget>[
                        _ToolEntry(
                          icon: Icons.transform,
                          title: '格式转换（FFmpeg）',
                          description: '从已完成任务里选一个视频转换',
                          onTap: () => _convertFromTask(context),
                        ),
                        _ToolEntry(
                          icon: Icons.folder_open,
                          title: '选择设备上的文件转换',
                          description: '转封装 / 提取音频 / GIF / 压缩 / H.264 ↔ H.265',
                          onTap: () => _convertFromDevice(context),
                        ),
                        _ToolEntry(
                          icon: Icons.merge_type,
                          title: '重新合并音视频',
                          description: '把保留的 video / audio 分片用 MediaMuxer 无损封装为 mp4',
                          onTap: () => _pickTaskThen(context, title: '选择要重新合并的任务', action: _remux),
                        ),
                        _ToolEntry(
                          icon: Icons.subtitles_outlined,
                          title: '重新生成弹幕',
                          description: '重新拉取弹幕并生成 ASS / XML / TXT',
                          onTap: () => _pickTaskThen(context, title: '选择要生成弹幕的任务', action: _rebuildDanmaku),
                        ),
                        _ToolEntry(
                          icon: Icons.save_alt,
                          title: '导出到相册 / 下载目录',
                          description: '视频进 Movies，其它文件统一进 Download',
                          onTap: () => _pickTaskThen(context, title: '选择要导出的任务', action: _export),
                        ),
                        _ToolEntry(
                          icon: Icons.cleaning_services_outlined,
                          title: '清理缓存',
                          description: '删除临时分片与残留文件，不影响已下载的成品',
                          showDivider: false,
                          onTap: () => _clearCache(context),
                        ),
                      ],
                    ),
                  ),
                  TdSection(
                    title: '已完成的任务（点击进行操作）',
                    child: tasks.isEmpty
                        ? Text('还没有完成的任务', style: TdText.bodySmall)
                        : Column(
                            children: <Widget>[
                              for (final task in tasks)
                                TDCell(
                                  title: task.title,
                                  note: formatBytes(task.totalBytes),
                                  description: _statusOf(task),
                                  arrow: true,
                                  onClick: (cell) => _showActions(context, manager, task),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusOf(DownloadTask task) {
    if (task.exported) return '已保存到系统相册';
    if (task.merged) return '已合并为 mp4';
    if (task.outputPath == null) return 'Aria2 远程下载';
    return '未合并';
  }

  // ------------------------------------------------------------------
  // 通用：选任务 -> 执行某个动作
  // ------------------------------------------------------------------

  Future<void> _pickTaskThen(
    BuildContext context, {
    required String title,
    required Future<void> Function(BuildContext context, DownloadTask task) action,
  }) async {
    final task = await _pickTask(context, title: title);
    if (task == null || !context.mounted) return;
    await action(context, task);
  }

  Future<DownloadTask?> _pickTask(BuildContext context, {required String title}) async {
    final tasks = context.read<DownloadManager>().finishedTasks;
    if (tasks.isEmpty) {
      tdToast(context, '还没有已完成的任务');
      return null;
    }
    return showModalBottomSheet<DownloadTask>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: TdPalette.container,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TdRadius.extraLarge)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
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
                  child: Text(title, style: TdText.titleSmall),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final task in tasks)
                        TDCell(
                          title: task.title,
                          description: _statusOf(task),
                          note: formatBytes(task.totalBytes),
                          arrow: true,
                          onClick: (cell) => Navigator.of(sheetContext).pop(task),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 格式转换
  // ------------------------------------------------------------------

  /// 清理缓存：只删临时分片与残留文件。
  ///
  /// 保护规则在 `DownloadManager.clearCache()` 里：正在下载 / 已暂停的任务
  /// 其分片会保留，断点续传不受影响。
  Future<void> _clearCache(BuildContext context) async {
    final manager = context.read<DownloadManager>();
    tdLoadingShow(context, text: '统计缓存');
    final before = await manager.cacheBytes();
    tdLoadingHide();
    if (!context.mounted) return;
    if (before <= 0) {
      tdToast(context, '没有可清理的缓存');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text('清理缓存', style: TdText.titleSmall),
        content: Text(
          '将删除临时分片与残留文件，可释放约 ${formatBytes(before)}。\n\n'
          '正在下载、已暂停的任务分片会保留，断点续传不受影响；'
          '已下载完成的文件不会被删除。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final freed = await manager.clearCache();
    if (!context.mounted) return;
    tdToastSuccess(context, '已释放 ${formatBytes(freed)}');
  }

  Future<void> _convertFromTask(BuildContext context) async {
    if (context.read<DownloadManager>().finishedTasks.isEmpty) {
      tdToast(context, '还没有已完成的任务，可改用「选择设备上的文件转换」');
      return;
    }
    final task = await _pickTask(context, title: '选择要转换的任务');
    if (task == null || !context.mounted) return;

    final source = task.exportedPath ?? task.outputPath;
    if (source == null || source.isEmpty) {
      tdToast(context, '这个任务没有可转换的文件（Aria2 远程下载的文件在 aria2 所在设备）');
      return;
    }
    await _prepareAndConvert(context, source: source, baseName: task.fileName);
  }

  Future<void> _convertFromDevice(BuildContext context) async {
    final uri = await NativeBridge.pickFile();
    if (uri == null || uri.isEmpty) return;
    if (!context.mounted) return;
    await _prepareAndConvert(context, source: uri, baseName: _displayNameOf(uri));
  }

  /// 相册 / 外部文件是 content uri，FFmpeg 读不了，先落地成真实文件再转换
  Future<void> _prepareAndConvert(
    BuildContext context, {
    required String source,
    required String baseName,
  }) async {
    final manager = context.read<DownloadManager>();
    final workDir = await manager.ensureDownloadDir();
    final convertDir = Directory('$workDir/.convert');
    await convertDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final local = await NativeBridge.materialize(
      path: source,
      dest: '${convertDir.path}/source_$stamp.${_extensionHint(source)}',
    );
    if (local == null) {
      if (context.mounted) tdToastError(context, '无法读取源文件');
      return;
    }
    if (!context.mounted) return;
    await _runConversion(
      context,
      sourcePath: local,
      baseName: baseName.trim().isEmpty ? 'converted' : baseName.trim(),
      workDir: workDir,
      convertDir: convertDir,
    );
  }

  Future<void> _runConversion(
    BuildContext context, {
    required String sourcePath,
    required String baseName,
    required String workDir,
    required Directory convertDir,
  }) async {
    final settings = context.read<SettingsStore>();

    tdLoadingShow(context, text: '读取文件信息');
    final probe = await FfmpegService.probe(sourcePath);
    tdLoadingHide();
    if (!context.mounted) return;

    final target = await _pickTarget(context, probe: probe, baseName: baseName);
    if (target == null || !context.mounted) return;

    if (_needsAudio(target) && !(probe?.hasAudio ?? false)) {
      tdToast(context, probe == null ? '无法读取该文件' : '该文件没有音轨，无法提取音频');
      return;
    }
    if (_needsVideo(target) && !(probe?.hasVideo ?? false)) {
      tdToast(context, probe == null ? '无法读取该文件' : '该文件没有视频轨，无法执行该转换');
      return;
    }

    final outputName = _outputName(baseName, target);
    final outputPath = '${convertDir.path}/$outputName';
    final progress = ValueNotifier<double>(0);
    // 先捕获 Navigator，避免 widget 卸载后关不掉进度弹窗
    final navigator = Navigator.of(context, rootNavigator: true);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ConvertDialog(
        progress: progress,
        title: '转换为 ${target.label}',
        onCancel: () => unawaited(FfmpegService.cancel()),
      ),
    ));

    void closeDialog() {
      if (!dialogOpen) return;
      dialogOpen = false;
      if (navigator.mounted) navigator.pop();
    }

    try {
      final result = await FfmpegService.convert(
        input: sourcePath,
        target: target,
        output: outputPath,
        gifFps: settings.gifFps,
        // GIF 只截取前 10 秒，进度按 10 秒算更贴近实际
        totalMs: target == ConvertTarget.gif ? 10000 : (probe?.durationMs ?? 0),
        onProgress: (value) => progress.value = value,
      );
      closeDialog();

      if (!result.success) {
        if (context.mounted) {
          tdToastError(context, result.cancelled ? '已取消转换' : '转换失败：${result.message}');
        }
        return;
      }

      // 默认保存到系统相册，否则放到工作目录
      String? placed;
      if (settings.saveToGallery) {
        placed = await NativeBridge.exportToPublic(
          path: outputPath,
          name: outputName,
          mime: DownloadManager.mimeOf(outputPath),
          album: AppInfo.englishName,
        );
      }
      if (placed == null) {
        final moved = '$workDir/$outputName';
        await File(outputPath).rename(moved);
        placed = moved;
      }
      if (context.mounted) {
        tdToastSuccess(context, '已生成 $outputName');
      }
    } catch (error) {
      if (context.mounted) tdToastError(context, '转换失败：$error');
    } finally {
      closeDialog();
      progress.dispose();
      try {
        if (await convertDir.exists()) {
          await convertDir.delete(recursive: true);
        }
      } catch (_) {
        // 清理失败不影响结果
      }
    }
  }

  Future<ConvertTarget?> _pickTarget(
    BuildContext context, {
    required MediaProbe? probe,
    required String baseName,
  }) {
    return showModalBottomSheet<ConvertTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: TdPalette.container,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TdRadius.extraLarge)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        Icon(Icons.transform, size: 20, color: TdPalette.brand),
                        const SizedBox(width: TdSpacer.xs),
                        Expanded(child: Text('选择转换目标', style: TdText.titleSmall)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
                    child: Text(
                      _describeSource(probe, baseName),
                      style: TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
                    ),
                  ),
                  const SizedBox(height: TdSpacer.xs),
                  for (final target in ConvertTarget.values)
                    TDCell(
                      title: target.label,
                      description: target.description,
                      arrow: true,
                      onClick: (cell) => Navigator.of(sheetContext).pop(target),
                    ),
                  const SizedBox(height: TdSpacer.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _describeSource(MediaProbe? probe, String baseName) {
    if (probe == null) return '$baseName · 未能读取媒体信息，转换可能失败';
    final parts = <String>[
      baseName,
      if (probe.durationMs > 0) formatDuration(probe.durationMs),
      if (probe.summary.isNotEmpty) probe.summary,
    ];
    return parts.join(' · ');
  }

  static bool _needsAudio(ConvertTarget target) =>
      target == ConvertTarget.mp3 || target == ConvertTarget.m4a;

  static bool _needsVideo(ConvertTarget target) => switch (target) {
        ConvertTarget.gif ||
        ConvertTarget.compress ||
        ConvertTarget.avcToHevc ||
        ConvertTarget.hevcToAvc =>
          true,
        _ => false,
      };

  static String _outputName(String baseName, ConvertTarget target) {
    switch (target) {
      case ConvertTarget.mp3:
      case ConvertTarget.m4a:
      case ConvertTarget.gif:
        return '$baseName.${target.extension}';
      case ConvertTarget.mkvCopy:
        return '$baseName.mkv';
      case ConvertTarget.mp4Copy:
        return '${baseName}_remux.mp4';
      case ConvertTarget.compress:
        return '${baseName}_compressed.mp4';
      case ConvertTarget.avcToHevc:
        return '${baseName}_h265.mp4';
      case ConvertTarget.hevcToAvc:
        return '${baseName}_h264.mp4';
    }
  }

  /// 从路径或 content uri 里猜扩展名，用于给落地文件起名
  static String _extensionHint(String path) {
    var name = path.split('/').last;
    final query = name.indexOf('?');
    if (query >= 0) name = name.substring(0, query);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'mp4';
    final extension = name.substring(dot + 1).toLowerCase();
    if (extension.isEmpty || extension.length > 5) return 'mp4';
    return extension;
  }

  /// 从 content uri 里尽量取一个可读的名字
  static String _displayNameOf(String uri) {
    var name = uri.split('/').last;
    final query = name.indexOf('?');
    if (query >= 0) name = name.substring(0, query);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || name.contains('%') || name.length > 80) return '外部文件';
    return name.substring(0, dot);
  }

  // ------------------------------------------------------------------
  // 单任务操作
  // ------------------------------------------------------------------

  Future<void> _showActions(BuildContext context, DownloadManager manager, DownloadTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: TdPalette.container,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TdRadius.extraLarge)),
        ),
        padding: const EdgeInsets.symmetric(vertical: TdSpacer.small),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
                child: Text(
                  task.title,
                  style: TdText.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TDCell(
                title: '打开文件',
                leftIcon: Icons.play_circle_outline,
                arrow: true,
                onClick: (cell) async {
                  Navigator.of(sheetContext).pop();
                  final ok = await manager.openFile(task);
                  if (context.mounted && !ok) tdToast(context, '没有可用的播放器');
                },
              ),
              TDCell(
                title: '格式转换（FFmpeg）',
                leftIcon: Icons.transform,
                description: '转封装 / 提取音频 / GIF / 压缩 / 换编码',
                arrow: true,
                onClick: (cell) async {
                  Navigator.of(sheetContext).pop();
                  final source = task.exportedPath ?? task.outputPath;
                  if (source == null || source.isEmpty) {
                    if (context.mounted) tdToast(context, '没有可转换的文件');
                    return;
                  }
                  await _prepareAndConvert(context, source: source, baseName: task.fileName);
                },
              ),
              TDCell(
                title: '导出到相册 / 下载目录',
                leftIcon: Icons.save_alt,
                arrow: true,
                onClick: (cell) async {
                  Navigator.of(sheetContext).pop();
                  await _export(context, task);
                },
              ),
              TDCell(
                title: '重新合并音视频',
                leftIcon: Icons.merge_type,
                arrow: true,
                onClick: (cell) async {
                  Navigator.of(sheetContext).pop();
                  await _remux(context, task);
                },
              ),
              TDCell(
                title: '重新生成弹幕文件',
                leftIcon: Icons.subtitles_outlined,
                arrow: true,
                onClick: (cell) async {
                  Navigator.of(sheetContext).pop();
                  await _rebuildDanmaku(context, task);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, DownloadTask task) async {
    final manager = context.read<DownloadManager>();
    tdLoadingShow(context, text: '导出中');
    final target = await manager.exportFile(task);
    tdLoadingHide();
    if (!context.mounted) return;
    if (target == null) {
      tdToastError(context, '导出失败');
    } else {
      tdToastSuccess(context, '已导出到系统媒体库');
    }
  }

  Future<void> _remux(BuildContext context, DownloadTask task) async {
    final videoPath = task.videoPath;
    final audioPath = task.audioPath;
    var hasVideo = false;
    var hasAudio = false;
    if (videoPath != null) hasVideo = await File(videoPath).exists();
    if (audioPath != null) hasAudio = await File(audioPath).exists();
    if (!hasVideo && !hasAudio) {
      if (context.mounted) tdToast(context, '原始分片已不存在，无法重新合并');
      return;
    }

    final manager = context.read<DownloadManager>();
    final workDir = await manager.ensureDownloadDir();
    final current = task.outputPath ?? '';
    // 已导出到相册时 outputPath 是 content uri，不能作为 MediaMuxer 的输出
    final target = current.isEmpty || current.startsWith('content://')
        ? '$workDir/${task.fileName}.mp4'
        : (current.endsWith('.mp4') || current.endsWith('.m4a') ? current : '$current.mp4');

    if (context.mounted) tdLoadingShow(context, text: '合并中');
    final ok = await NativeBridge.mux(
      video: hasVideo ? videoPath : null,
      audio: hasAudio ? audioPath : null,
      output: target,
    );

    if (!ok) {
      if (context.mounted) {
        tdLoadingHide();
        tdToastError(context, '合并失败，可能是设备不支持该编码封装，可改用「格式转换」');
      }
      return;
    }

    final settings = context.read<SettingsStore>();
    var location = target;
    var exported = false;
    if (settings.saveToGallery) {
      final result = await NativeBridge.exportToPublic(
        path: target,
        name: target.split('/').last,
        mime: DownloadManager.mimeOf(target),
        album: AppInfo.englishName,
      );
      if (result != null) {
        location = result;
        exported = true;
        try {
          await File(target).delete();
        } catch (_) {
          // 清理失败不影响结果
        }
      }
    }

    task.outputPath = location;
    task.exported = exported;
    task.exportedPath = exported ? location : null;
    task.merged = true;
    task.error = null;
    manager.refresh();

    if (context.mounted) {
      tdLoadingHide();
      tdToastSuccess(context, '合并完成');
    }
  }

  Future<void> _rebuildDanmaku(BuildContext context, DownloadTask task) async {
    if (context.mounted) tdLoadingShow(context, text: '拉取弹幕');
    try {
      final api = context.read<BiliApi>();
      final manager = context.read<DownloadManager>();
      final settings = context.read<SettingsStore>();
      final items = await api.danmaku(cid: task.cid, durationMs: task.durationMs);
      // 用 if/else 而不是 switch 表达式：避免部分 Dart 版本对枚举常量模式判定为「非常量」
      var content = DanmakuWriter.toAss(items, title: task.title);
      if (task.danmakuFormat == DanmakuFormat.xml) {
        content = DanmakuWriter.toXml(items);
      } else if (task.danmakuFormat == DanmakuFormat.txt) {
        content = DanmakuWriter.toText(items);
      }
      final dir = await manager.ensureDownloadDir();
      final name = '${task.fileName}.${task.danmakuFormat.ext}';
      final file = File('$dir/$name');
      await file.writeAsString(content, flush: true);

      if (settings.saveToGallery) {
        await NativeBridge.exportToPublic(
          path: file.path,
          name: name,
          mime: 'text/plain',
          album: AppInfo.englishName,
        );
      }
      if (context.mounted) {
        tdLoadingHide();
        tdToastSuccess(context, '已生成 ${items.length} 条弹幕');
      }
    } catch (error) {
      if (context.mounted) {
        tdLoadingHide();
        tdToastError(context, '转换失败：$error');
      }
    }
  }
}

/// 可点击的工具入口
class _ToolEntry extends StatelessWidget {
  const _ToolEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: TdPalette.brandLight,
                    borderRadius: BorderRadius.circular(TdRadius.medium),
                  ),
                  child: Icon(icon, size: 19, color: TdPalette.brand),
                ),
                const SizedBox(width: TdSpacer.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: TdText.bodyLarge),
                      const SizedBox(height: 2),
                      Text(description, style: TdText.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: TdPalette.gray6),
              ],
            ),
          ),
        ),
        if (showDivider) TDDivider(height: 0.5, color: TdPalette.divider),
      ],
    );
  }
}

/// 转换进度弹窗
class _ConvertDialog extends StatelessWidget {
  const _ConvertDialog({
    required this.progress,
    required this.title,
    required this.onCancel,
  });

  final ValueListenable<double> progress;
  final String title;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TdPalette.container,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TdRadius.extraLarge)),
      child: Padding(
        padding: const EdgeInsets.all(TdSpacer.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TdText.titleSmall),
            const SizedBox(height: TdSpacer.medium),
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TdRadius.round),
                    child: LinearProgressIndicator(
                      value: value <= 0 ? null : value.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: TdPalette.gray2,
                      valueColor: AlwaysStoppedAnimation<Color>(TdPalette.brand),
                    ),
                  ),
                  const SizedBox(height: TdSpacer.xs),
                  Text(
                    value <= 0 ? '正在准备…' : '已完成 ${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: TdText.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            Align(
              alignment: Alignment.centerRight,
              child: TDButton(
                text: '取消',
                type: TDButtonType.text,
                size: TDButtonSize.small,
                onTap: onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
