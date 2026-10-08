import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../data/models.dart';
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
                  padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '共 ${batch.items.length} 个视频，已选 ${parse.selectedCount}',
                          style: TdText.bodySmall,
                        ),
                      ),
                      TDButton(
                        text: parse.selectedCount == batch.items.length ? '全不选' : '全选',
                        type: TDButtonType.text,
                        size: TDButtonSize.extraSmall,
                        theme: TDButtonTheme.primary,
                        onTap: () => parse.selectAllBatch(parse.selectedCount != batch.items.length),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
                    itemCount: batch.items.length + (batch.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= batch.items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: TdSpacer.medium),
                          child: Center(
                            child: parse.loadingMore
                                ? const TdLoadingView(text: '加载更多')
                                : TDButton(
                                    text: '加载更多',
                                    theme: TDButtonTheme.light,
                                    size: TDButtonSize.small,
                                    onTap: parse.loadMore,
                                  ),
                          ),
                        );
                      }
                      final item = batch.items[index];
                      return VideoInfoTile(
                        title: item.title,
                        cover: item.cover,
                        subtitle: item.ownerName.isEmpty
                            ? '${item.bvid}${item.epId == null ? '' : ' · ep${item.epId}'}'
                            : item.ownerName,
                        durationMs: item.durationMs,
                        leading: TDCheckbox(
                          checked: parse.isBatchSelected(item),
                          size: TDCheckBoxSize.small,
                          insetSpacing: 0,
                          showDivider: false,
                          onCheckBoxChanged: (checked) => parse.toggleBatchItem(item),
                        ),
                        onTap: () => parse.toggleBatchItem(item),
                      );
                    },
                  ),
                ),
                _buildBottomBar(context, parse, batch),
              ],
            ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ParseController parse, BatchResult batch) {
    return Container(
      color: TdPalette.container,
      child: SafeArea(
        top: false,
        child: TdPrimaryAction(
          text: '下载选中（${parse.selectedCount}）',
          onTap: parse.selectedCount == 0 ? null : () => _download(context, parse),
        ),
      ),
    );
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
