import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../data/models.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/video_card.dart';

/// 批量列表页：收藏夹 / 合集 / 历史 / 稍后再看 / 整季番剧。
class MediaListPage extends StatelessWidget {
  const MediaListPage({super.key});

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
    // 批量入口没有「解析结果页」，这里先弹选项面板，让用户挑清晰度 / 编码 / 下载内容
    final confirmed = await showDownloadOptionsSheet(context, count: parse.selectedCount);
    if (!confirmed || !context.mounted) return;
    if (!parse.wantVideo && !parse.wantAudio) {
      tdToast(context, '请至少选择「视频」或「音频」');
      return;
    }
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
