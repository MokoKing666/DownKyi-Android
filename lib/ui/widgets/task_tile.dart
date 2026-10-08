import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/formatter.dart';
import '../../data/download_task.dart';
import '../../download/download_manager.dart';
import '../td.dart';

/// 下载任务卡片
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.manager,
    this.onOpen,
    this.onExport,
    this.onDelete,
    this.onRetry,
    this.onTogglePause,
  });

  final DownloadTask task;
  final DownloadManager manager;
  final VoidCallback? onOpen;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onTogglePause;

  @override
  Widget build(BuildContext context) {
    return TdSection(
      margin: const EdgeInsets.symmetric(horizontal: TdSpacer.medium, vertical: TdSpacer.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(TdRadius.medium),
                child: SizedBox(
                  width: 96,
                  height: 58,
                  child: task.cover.isEmpty
                      ? Container(color: TdPalette.gray2)
                      : Image.network(
                          task.cover,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(color: TdPalette.gray2),
                        ),
                ),
              ),
              const SizedBox(width: TdSpacer.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: TdText.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.displaySubTitle,
                      style: TdText.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TdSpacer.small),
          _buildStatusLine(),
          const SizedBox(height: TdSpacer.xs),
          TDProgress(
            type: TDProgressType.linear,
            value: task.progress,
            showLabel: false,
            strokeWidth: 4,
            color: _progressColor,
            linearBorderRadius: BorderRadius.circular(TdRadius.round),
          ),
          const SizedBox(height: TdSpacer.xs),
          _buildActions(context),
        ],
      ),
    );
  }

  Color get _progressColor => switch (task.status) {
        TaskStatus.failed => TdPalette.error,
        TaskStatus.completed => TdPalette.success,
        _ => TdPalette.brand,
      };

  Widget _buildStatusLine() {
    final style = TdText.bodySmall.copyWith(
      color: task.status == TaskStatus.failed ? TdPalette.error : TdPalette.textSecondary,
    );
    final text = switch (task.status) {
      TaskStatus.queued => '等待开始',
      TaskStatus.running =>
        '${formatBytes(task.downloadedBytes)} / ${formatBytes(task.totalBytes)} · '
            '${formatSpeed(task.speed)} · 剩余 ${formatEta(task.remainSeconds)}',
      TaskStatus.paused => '已暂停 · ${formatBytes(task.downloadedBytes)} / ${formatBytes(task.totalBytes)}',
      TaskStatus.merging => '正在合并音视频…',
      TaskStatus.completed => _completedText(task),
      TaskStatus.failed => task.error ?? '下载失败',
    };
    return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  /// 视频本体完成，但封面 / 弹幕 / 字幕里可能有失败项。
  ///
  /// 过去无论附加资源成功与否都只显示「已完成」，
  /// 用户会以为封面字幕都下好了。现在如实标出失败的是哪一项。
  String _completedText(DownloadTask task) {
    final size = formatBytes(task.totalBytes);
    final extras = task.extrasError;
    if (extras != null && extras.isNotEmpty) {
      return '已完成，但 $extras 未成功 · $size';
    }
    return task.merged ? '已完成 · $size' : '已完成（未合并）· $size';
  }

  Widget _buildActions(BuildContext context) {
    final actions = <Widget>[];
    switch (task.status) {
      case TaskStatus.queued:
      case TaskStatus.running:
        actions.add(_textButton('暂停', onTogglePause));
        break;
      case TaskStatus.merging:
        actions.add(_textButton('暂停', onTogglePause));
        break;
      case TaskStatus.paused:
        actions.add(_textButton('继续', onTogglePause));
        break;
      case TaskStatus.failed:
        actions.add(_textButton('重试', onRetry));
        break;
      case TaskStatus.completed:
        actions.add(_textButton('打开', onOpen));
        actions.add(_textButton('导出到相册', onExport));
        break;
    }
    actions.add(_textButton('删除', onDelete, danger: true));
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        for (final action in actions) ...<Widget>[
          action,
          const SizedBox(width: TdSpacer.xs),
        ],
      ],
    );
  }

  Widget _textButton(String text, VoidCallback? onTap, {bool danger = false}) {
    return TDButton(
      text: text,
      type: TDButtonType.text,
      size: TDButtonSize.extraSmall,
      theme: danger ? TDButtonTheme.danger : TDButtonTheme.primary,
      onTap: onTap,
    );
  }
}
