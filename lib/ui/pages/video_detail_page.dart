import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../core/formatter.dart';
import '../../data/models.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import '../widgets/download_options.dart';
import '../widgets/video_card.dart';

/// 解析结果页：选集 + 清晰度 / 编码 / 音轨 + 下载内容。
class VideoDetailPage extends StatelessWidget {
  const VideoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final parse = context.watch<ParseController>();
    final video = parse.video;

    return TdPage(
      title: '解析结果',
      showDivider: true,
      backgroundColor: TdPalette.pageBackground,
      child: video == null
          ? const TdEmptyView(text: '没有解析结果')
          : ListView(
              padding: const EdgeInsets.only(bottom: TdSpacer.large),
              children: <Widget>[
                _buildInfo(video),
                if (video.pages.length > 1) _buildPages(context, parse, video),
                // 清晰度 / 编码 / 音频 / 下载内容：与批量下载弹窗共用同一份实现，
                // 保证两处选项逻辑不会各自漂移
                DownloadOptionsPanel(parse: parse, card: true),
                const SizedBox(height: TdSpacer.xs),
                TdPrimaryAction(
                  text: '开始下载（已选 ${parse.selectedCount} 项）',
                  onTap: parse.selectedCount == 0
                      ? null
                      : () => _download(context),
                ),
              ],
            ),
    );
  }

  Widget _buildInfo(VideoDetail video) {
    return TdSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              VideoCover(
                  url: video.cover,
                  width: 130,
                  height: 78,
                  durationMs: video.durationMs),
              const SizedBox(width: TdSpacer.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(video.title,
                        style: TdText.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      video.ownerName,
                      style: TdText.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatCount(video.view)} 播放 · ${formatCount(video.danmakuCount)} 弹幕',
                      style: TdText.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (video.btype != BiliConst.typeVideo) ...<Widget>[
            const SizedBox(height: TdSpacer.small),
            TdLabel(video.btype == BiliConst.typeCheese ? '课程' : '番剧'),
          ],
        ],
      ),
    );
  }

  Widget _buildPages(
      BuildContext context, ParseController parse, VideoDetail video) {
    return TdSection(
      title: '选集（共 ${video.pages.length} P）',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '已选 ${parse.selectedPages.length} / ${video.pages.length}',
                  style: TdText.bodySmall,
                ),
              ),
              TDButton(
                text: parse.selectedPages.length == video.pages.length
                    ? '全不选'
                    : '全选',
                type: TDButtonType.text,
                size: TDButtonSize.extraSmall,
                theme: TDButtonTheme.primary,
                onTap: () => parse.selectAllPages(
                    parse.selectedPages.length != video.pages.length),
              ),
            ],
          ),
          const SizedBox(height: TdSpacer.xxs),
          for (var index = 0; index < video.pages.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: TDCheckbox(
                key: ValueKey<String>('page_$index'),
                title: video.pages[index].part,
                subTitle: formatDuration(video.pages[index].durationMs),
                checked: parse.selectedPages.contains(index),
                size: TDCheckBoxSize.small,
                insetSpacing: 0,
                showDivider: false,
                onCheckBoxChanged: (checked) {
                  parse.togglePage(index);
                  if (checked && parse.selectedPages.length == 1) {
                    parse.loadQualities();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final parse = context.read<ParseController>();
    // 允许只下封面 / 弹幕 / 字幕：没有媒体流时下载管理器会跳过合并直接收尾
    if (parse.wantVideo &&
        parse.wantAudio &&
        !parse.availableCodecs.contains(parse.codec)) {
      tdToast(context, '当前清晰度不支持所选编码，已自动切换');
    }
    tdLoadingShow(context, text: '创建任务');
    final count = await parse.enqueueVideo();
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
