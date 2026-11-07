import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/formatter.dart';
import '../../data/download_task.dart';
import '../../download/download_manager.dart';
import '../../download/download_rules.dart';
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
      margin: const EdgeInsets.symmetric(
          horizontal: TdSpacer.medium, vertical: TdSpacer.xxs),
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
                          errorBuilder: (context, error, stack) =>
                              Container(color: TdPalette.gray2),
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
                    Row(
                      children: <Widget>[
                        _sourceBadge(),
                        Expanded(
                          child: Text(
                            task.displaySubTitle,
                            style: TdText.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
      color: task.status == TaskStatus.failed
          ? TdPalette.error
          : TdPalette.textSecondary,
    );
    final text = switch (task.status) {
      TaskStatus.queued => '等待开始',
      TaskStatus.running =>
        '${formatBytes(task.downloadedBytes)} / ${formatBytes(task.totalBytes)} · '
            '${formatSpeed(task.speed)} · 剩余 ${formatEta(task.remainSeconds)}',
      TaskStatus.paused =>
        '已暂停 · ${formatBytes(task.downloadedBytes)} / ${formatBytes(task.totalBytes)}',
      TaskStatus.merging => '正在合并音视频…',
      TaskStatus.completed => _completedText(task),
      TaskStatus.failed => task.error ?? '下载失败',
    };
    return Text(text,
        style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  /// 视频本体完成，但封面 / 弹幕 / 字幕里可能有失败项，或者封装没成功。
  ///
  /// 过去无论附加资源成功与否都只显示「已完成」，用户会以为封面字幕都下好了。
  /// 更糟的是**封装失败**：`_merge` 把原因写进了 `task.error`，但这里只显示
  /// 「已完成（未合并）」，用户根本不知道该去查什么——只能看到「合并不了」。
  /// 现在把真实原因顶到标题行上。
  String _completedText(DownloadTask task) {
    final size = formatBytes(task.totalBytes);
    final error = task.error;
    // 注意：只有「封装失败」才会带 error。设置里关了自动合并、
    // 或者只下了封面弹幕，这两种情况 merged 也是 false，但 error 为空。
    if (!task.merged && error != null && error.isNotEmpty) {
      return '$error · $size';
    }
    final extras = task.extrasError;
    if (extras != null && extras.isNotEmpty) {
      return '已完成，但 $extras 未成功 · $size';
    }
    if (!task.merged) {
      return '已完成（未合并，可在「工具」里手动合并）· $size';
    }
    return '已完成 · $size';
  }

  /// 下载来源标签（评审第 20 项）。
  ///
  /// 接上 NAS / 电脑的 aria2 之后，任务列表里会同时存在「本机在下」和
  /// 「远程在下」两种任务，速度与进度的含义完全不同，必须能一眼分辨。
  /// 本机任务不加标签，避免每条都挂个「本机」把界面弄脏。
  Widget _sourceBadge() {
    final source = TaskSources.of(task, manager.settings.aria2RpcUrl);
    if (source == TaskSource.local) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: TdSpacer.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: TdPalette.gray1,
          borderRadius: BorderRadius.circular(TdRadius.medium),
        ),
        child: Text(
          source.label,
          style: TdText.bodySmall.copyWith(
            color: source.isRemote ? TdPalette.brand : TdPalette.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
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
