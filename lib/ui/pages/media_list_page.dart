import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../bili/models.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/video_card.dart';

/// 批量列表页：收藏夹 / 合集 / 历史 / 稍后再看 / 整季番剧 / 订阅新内容。
class MediaListPage extends StatelessWidget {
  const MediaListPage({super.key, this.onEnqueued});

  /// 任务创建成功后的回调，订阅页用它把对应条目标记为「已处理」。
  /// 只有真正建了任务才触发——用户在设置弹窗里点取消不会触发。
  final Future<void> Function(List<MediaItem> items)? onEnqueued;

  @override
  Widget build(BuildContext context) {
    final parse = context.watch<ParseController>();
    final batch = parse.batch;

    return TdPage(
      title: batch?.title ?? '批量列表',
      showDivider: true,
      child: batch == null
          ? const TdEmptyView(text: '没有可下载的内容')
          : Column(
              children: <Widget>[
                Container(
                  color: TdPalette.container,
                  padding: const EdgeInsets.symmetric(
                      horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '共 ${batch.items.length} 个视频，已选 ${parse.selectedCount}'
                          '（长按可连续选择）',
                          style: TdText.bodySmall,
                        ),
                      ),
                      TButton(
                        child: Text(parse.selectedCount == parse.selectableCount
                            ? '全不选'
                            : '全选'),
                        variant: TButtonVariant.text,
                        size: TButtonSize.extraSmall,
                        colorPreset: TButtonColorPreset.primary,
                        onPressed: () => parse.selectAllBatch(
                            parse.selectedCount != parse.selectableCount),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
                    itemCount: batch.items.length + (batch.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= batch.items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: TdSpacer.medium),
                          child: Center(
                            child: parse.loadingMore
                                ? const TdLoadingView(text: '加载更多')
                                : TButton(
                                    child: const Text('加载更多'),
                                    colorPreset: TButtonColorPreset.light,
                                    size: TButtonSize.small,
                                    onPressed: parse.loadMore,
                                  ),
                          ),
                        );
                      }
                      final item = batch.items[index];
                      // 合集条目（空间投稿流里的 publication）：不可勾选，
                      // 点击进入合集列表
                      if (item.isCollection) {
                        return VideoInfoTile(
                          title: item.title,
                          cover: item.cover,
                          subtitle: '合集 · ${item.epCount} 集',
                          durationMs: item.durationMs,
                          onTap: () => _openCollection(context, parse, item),
                        );
                      }
                      return GestureDetector(
                        onLongPress: () => parse.longPressBatchItem(index),
                        child: VideoInfoTile(
                          title: item.title,
                          cover: item.cover,
                          subtitle: item.ownerName.isEmpty
                              ? '${item.bvid}${item.epId == null ? '' : ' · ep${item.epId}'}'
                              : item.ownerName,
                          durationMs: item.durationMs,
                          leading: TdCheckboxField(
                            checked: parse.isBatchSelected(item),
                            onChanged: (checked) => parse.toggleBatchItem(item),
                          ),
                          onTap: () => parse.toggleBatchItem(item),
                        ),
                      );
                    },
                  ),
                ),
                _buildBottomBar(context, parse, batch),
              ],
            ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, ParseController parse, BatchResult batch) {
    return Container(
      color: TdPalette.container,
      child: SafeArea(
        top: false,
        child: TdPrimaryAction(
          text: '下载选中（${parse.selectedCount}）',
          onTap:
              parse.selectedCount == 0 ? null : () => _download(context, parse),
        ),
      ),
    );
  }

  /// 打开合集条目：保存现场 → 加载合集 → 压入新的列表页 → 返回后恢复现场。
  Future<void> _openCollection(
      BuildContext context, ParseController parse, MediaItem item) async {
    final saved = parse.saveBatchState();
    tdLoadingShow(context, text: '加载合集');
    await parse.openCollection(item);
    tdLoadingHide();
    if (!context.mounted) return;
    if (parse.batch?.seasonId != item.seasonId) {
      tdToastError(context, '合集加载失败：${parse.error ?? '未知错误'}');
      parse.restoreBatchState(saved);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MediaListPage()),
    );
    if (!context.mounted) return;
    parse.restoreBatchState(saved);
  }

  Future<void> _download(BuildContext context, ParseController parse) async {
    final selected = parse.selectedCount;
    if (selected == 0) return;

    // 先解析第一个选中项，取回真实的清晰度 / 编码 / 音轨列表，
    // 选项面板才不会列出「该视频并不支持」的档位（例如视频没有 8K 却给出 8K）
    tdLoadingShow(context, text: '解析可选项');
    final referenceLoaded = await parse.loadBatchReference();
    tdLoadingHide();
    if (!context.mounted) return;

    final confirmed = await showDownloadOptionsSheet(
      context,
      count: selected,
      referenceLoaded: referenceLoaded,
    );
    if (!confirmed || !context.mounted) return;

    tdLoadingShow(context, text: '创建任务');
    final count = await parse.enqueueBatch();
    tdLoadingHide();
    if (!context.mounted) return;
    if (count == 0) {
      tdToast(context, '任务已存在或无可下载内容');
      return;
    }
    tdToastSuccess(context, '已创建 $count 个下载任务');
    Navigator.of(context).maybePop();
  }
}
