import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/formatter.dart';
import '../../download/download_manager.dart';
import '../td.dart';

/// 缓存分析：按文件类型列出可清理的内容，由用户自己勾选。
///
/// 返回实际释放的字节数；用户取消返回 null。
Future<int?> showCacheAnalysisSheet(
  BuildContext context,
  DownloadManager manager,
) async {
  tdLoadingShow(context, text: '分析缓存');
  final groups = await manager.analyzeCache();
  tdLoadingHide();
  if (!context.mounted) return null;
  if (groups.isEmpty) {
    tdToast(context, '工作目录是空的，没有可清理的内容');
    return null;
  }
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CacheAnalysisSheet(manager: manager, groups: groups),
  );
}

class _CacheAnalysisSheet extends StatefulWidget {
  const _CacheAnalysisSheet({required this.manager, required this.groups});

  final DownloadManager manager;
  final List<CacheGroup> groups;

  @override
  State<_CacheAnalysisSheet> createState() => _CacheAnalysisSheetState();
}

class _CacheAnalysisSheetState extends State<_CacheAnalysisSheet> {
  /// 默认可清理的都勾上——它们没有任何任务引用
  late final Set<String> _selected = <String>{
    for (final group in widget.groups)
      if (group.fileCount > 0) group.key,
  };

  bool _busy = false;

  List<CacheGroup> get _removable => widget.groups
      .where((group) => group.fileCount > 0)
      .toList(growable: false);

  List<CacheGroup> get _kept =>
      widget.groups.where((group) => group.hasKept).toList(growable: false);

  int get _selectedBytes => widget.groups
      .where((group) => _selected.contains(group.key))
      .fold<int>(0, (sum, group) => sum + group.bytes);

  int get _selectedCount => widget.groups
      .where((group) => _selected.contains(group.key))
      .fold<int>(0, (sum, group) => sum + group.fileCount);

  int get _totalBytes =>
      widget.groups.fold<int>(0, (sum, group) => sum + group.totalBytes);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(TdRadius.extraLarge)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSummary(),
                    const SizedBox(height: TdSpacer.medium),
                    if (_removable.isEmpty)
                      Text('没有可清理的文件', style: TdText.bodyMedium)
                    else ...<Widget>[
                      Text('可清理', style: TdText.titleSmall),
                      const SizedBox(height: TdSpacer.xs),
                      for (final group in _removable) _buildGroup(group),
                    ],
                    if (_kept.isNotEmpty) ...<Widget>[
                      const SizedBox(height: TdSpacer.medium),
                      Text('占用中（不会被删除）', style: TdText.titleSmall),
                      const SizedBox(height: TdSpacer.xs),
                      for (final group in _kept) _buildKept(group),
                    ],
                    const SizedBox(height: TdSpacer.small),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TdSpacer.medium,
        TdSpacer.medium,
        TdSpacer.medium,
        TdSpacer.small,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('缓存分析', style: TdText.titleSmall)),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.close, size: 20, color: TdPalette.gray6),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final removable =
        widget.groups.fold<int>(0, (sum, group) => sum + group.bytes);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TdSpacer.small),
      decoration: BoxDecoration(
        color: TdPalette.brandLight,
        borderRadius: BorderRadius.circular(TdRadius.medium),
      ),
      child: Text(
        '工作目录共占用 ${formatBytes(_totalBytes)}，其中 ${formatBytes(removable)} 可清理。\n'
        '缓存只影响 App 的工作目录，不会碰系统相册里的文件。',
        style: TdText.bodySmall,
      ),
    );
  }

  Widget _buildGroup(CacheGroup group) {
    final checked = _selected.contains(group.key);
    return InkWell(
      onTap: () => _toggle(group),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TdCheckboxField(
              checked: checked,
              onChanged: (_) => _toggle(group),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: Text(group.label, style: TdText.bodyMedium)),
                      Text(
                        '${group.fileCount} 个 · ${formatBytes(group.bytes)}',
                        style: TdText.bodyMedium,
                      ),
                    ],
                  ),
                  Text(group.description, style: TdText.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKept(CacheGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                        child: Text(group.label, style: TdText.bodyMedium)),
                    Text(formatBytes(group.keptBytes),
                        style: TdText.bodyMedium),
                  ],
                ),
                Text(
                  '${group.keptCount} 个文件仍被任务引用'
                  '（未完成的分片、未导出的成品），删除会破坏断点续传或丢失文件',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final hasSelection = _selectedBytes > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TdSpacer.medium,
        TdSpacer.xs,
        TdSpacer.medium,
        TdSpacer.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            hasSelection
                ? '已选 $_selectedCount 个文件，将释放 ${formatBytes(_selectedBytes)}'
                : '未选中任何内容',
            style: TdText.bodySmall,
          ),
          const SizedBox(height: TdSpacer.xs),
          TDButton(
            text: _busy ? '清理中…' : '清理选中',
            theme: TDButtonTheme.primary,
            size: TDButtonSize.large,
            isBlock: true,
            disabled: !hasSelection || _busy,
            onTap: () => unawaited(_clean()),
          ),
        ],
      ),
    );
  }

  void _toggle(CacheGroup group) {
    setState(() {
      if (_selected.contains(group.key)) {
        _selected.remove(group.key);
      } else {
        _selected.add(group.key);
      }
    });
  }

  Future<void> _clean() async {
    setState(() => _busy = true);
    final freed = await widget.manager.clearCacheGroups(_selected.toList());
    if (!mounted) return;
    Navigator.of(context).pop(freed);
  }
}
