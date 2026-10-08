import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../data/download_task.dart';
import '../../download/download_manager.dart';
import '../td.dart';
import '../widgets/choice.dart';
import '../widgets/task_tile.dart';

/// 下载管理页
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<DownloadManager>();
    final running = manager.tasks
        .where((task) => task.status != TaskStatus.completed)
        .toList();
    final done = manager.finishedTasks;
    final list = _tab == 0 ? running : done;

    return Container(
      color: TdPalette.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TdSpacer.medium, TdSpacer.large, TdSpacer.medium, 0),
              child: Row(
                children: <Widget>[
                  Text('下载管理', style: TdText.titleLarge),
                  const SizedBox(width: TdSpacer.xs),
                  TdLabel('${running.length} 进行中'),
                  const Spacer(),
                  if (_tab == 0)
                    TDButton(
                      text: '全部开始',
                      type: TDButtonType.text,
                      size: TDButtonSize.extraSmall,
                      onTap: manager.resumeAll,
                    ),
                  if (_tab == 0)
                    TDButton(
                      text: '全部暂停',
                      type: TDButtonType.text,
                      size: TDButtonSize.extraSmall,
                      onTap: manager.pauseAll,
                    ),
                  if (_tab == 1)
                    TDButton(
                      text: '清空记录',
                      type: TDButtonType.text,
                      size: TDButtonSize.extraSmall,
                      theme: TDButtonTheme.danger,
                      onTap: () => _clearFinished(context, manager),
                    ),
                ],
              ),
            ),
            TdSegmented(
              labels: <String>[
                '进行中 (${running.length})',
                '已完成 (${done.length})'
              ],
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
            Expanded(
              child: list.isEmpty
                  ? TdEmptyView(
                      text: _tab == 0 ? '暂无下载任务\n去首页粘贴链接开始下载吧' : '还没有完成的任务',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          top: TdSpacer.xxs, bottom: TdSpacer.large),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final task = list[index];
                        return TaskTile(
                          task: task,
                          manager: manager,
                          onTogglePause: () => _toggle(task, manager),
                          onRetry: () => manager.retry(task.id),
                          onOpen: () => _open(context, manager, task),
                          onExport: () => _export(context, manager, task),
                          onDelete: () => _delete(context, manager, task),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(DownloadTask task, DownloadManager manager) {
    if (task.status == TaskStatus.running ||
        task.status == TaskStatus.merging) {
      manager.pause(task.id);
    } else {
      manager.resume(task.id);
    }
  }

  Future<void> _open(
      BuildContext context, DownloadManager manager, DownloadTask task) async {
    final ok = await manager.openFile(task);
    if (!context.mounted) return;
    if (!ok) {
      tdToast(context, '没有可打开的文件，或没有可用的播放器');
    }
  }

  Future<void> _export(
      BuildContext context, DownloadManager manager, DownloadTask task) async {
    tdLoadingShow(context, text: '导出中');
    final target = await manager.exportFile(task);
    tdLoadingHide();
    if (!context.mounted) return;
    if (target == null) {
      tdToastError(context, '导出失败，请检查文件是否存在');
    } else {
      tdToastSuccess(context, '已导出到相册 / 下载目录');
    }
  }

  Future<void> _delete(
      BuildContext context, DownloadManager manager, DownloadTask task) async {
    final confirmed = await tdConfirm(
      context,
      title: '删除任务',
      content: '将同时删除已下载的文件（含临时分片），确定继续吗？',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    await manager.remove(task.id);
    if (context.mounted) tdToast(context, '已删除');
  }

  /// 清空已完成记录：先让用户选「只删记录」还是「连源文件一起删」
  Future<void> _clearFinished(
      BuildContext context, DownloadManager manager) async {
    final count = manager.finishedTasks.length;
    if (count == 0) {
      tdToast(context, '还没有已完成的任务');
      return;
    }

    // true = 连文件一起删，false = 只删记录，null = 取消
    final deleteFiles = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: TdPalette.container,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TdRadius.extraLarge)),
        ),
        child: SafeArea(
          top: false,
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
                child: Text('清空已完成记录（$count 个）', style: TdText.titleSmall),
              ),
              TDCell(
                title: '只删除记录',
                description: '已下载的文件会保留（含系统相册里的）',
                leftIcon: Icons.playlist_remove,
                arrow: true,
                onClick: (cell) => Navigator.of(sheetContext).pop(false),
              ),
              TDCell(
                title: '删除记录和源文件',
                description: '同时删除已下载的文件，不可恢复',
                leftIcon: Icons.delete_forever_outlined,
                arrow: true,
                onClick: (cell) => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: TdSpacer.xs),
            ],
          ),
        ),
      ),
    );

    if (deleteFiles == null || !context.mounted) return;

    if (deleteFiles) {
      final confirmed = await tdConfirm(
        context,
        title: '删除记录和源文件',
        content: '将删除这 $count 个任务的记录，并同时删除已下载的文件'
            '（包括已导出到系统相册的副本）。此操作不可恢复。',
        confirmText: '删除',
        danger: true,
      );
      if (!confirmed) return;
    }

    await manager.clearFinished(deleteFiles: deleteFiles);
    if (context.mounted) {
      tdToast(context, deleteFiles ? '已删除记录和文件' : '已清空记录');
    }
  }
}
