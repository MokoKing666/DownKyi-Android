import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../core/formatter.dart';
import '../../data/models.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import '../widgets/choice.dart';
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
                _buildQuality(context, parse),
                if (parse.availableCodecs.length > 1) _buildCodec(context, parse),
                if (parse.availableAudios.isNotEmpty) _buildAudio(context, parse),
                _buildContents(context, parse),
                const SizedBox(height: TdSpacer.xs),
                TdPrimaryAction(
                  text: '开始下载（已选 ${parse.selectedCount} 项）',
                  onTap: parse.selectedCount == 0 ? null : () => _download(context),
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
              VideoCover(url: video.cover, width: 130, height: 78, durationMs: video.durationMs),
              const SizedBox(width: TdSpacer.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(video.title, style: TdText.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildPages(BuildContext context, ParseController parse, VideoDetail video) {
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
                text: parse.selectedPages.length == video.pages.length ? '全不选' : '全选',
                type: TDButtonType.text,
                size: TDButtonSize.extraSmall,
                theme: TDButtonTheme.primary,
                onTap: () => parse.selectAllPages(parse.selectedPages.length != video.pages.length),
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

  Widget _buildQuality(BuildContext context, ParseController parse) {
    final qualities = parse.availableQualities;
    if (qualities.isEmpty) {
      return TdSection(
        child: Text(
          parse.dash == null ? '清晰度信息获取失败：${parse.error ?? '未知错误'}' : '该视频没有可用的清晰度',
          style: TdText.bodySmall.copyWith(color: TdPalette.warning),
        ),
      );
    }
    return TdSection(
      title: '清晰度',
      child: TdChoiceGroup<int>(
        items: qualities,
        selected: parse.quality,
        labelBuilder: parse.qualityLabel,
        onSelect: parse.setQuality,
      ),
    );
  }

  Widget _buildCodec(BuildContext context, ParseController parse) {
    return TdSection(
      title: '视频编码',
      child: TdChoiceGroup<String>(
        items: parse.availableCodecs,
        selected: parse.codec,
        labelBuilder: (value) => switch (value) {
          'hevc' => 'HEVC / H.265',
          'av1' => 'AV1',
          _ => 'AVC / H.264',
        },
        onSelect: parse.setCodec,
      ),
    );
  }

  Widget _buildAudio(BuildContext context, ParseController parse) {
    final audios = parse.availableAudios;
    return TdSection(
      title: '音频',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TdChoiceGroup<int>(
            items: audios.map((item) => item.id).toList(),
            selected: parse.audioId,
            labelBuilder: (value) {
              final stream = audios.firstWhere((item) => item.id == value);
              final name = BiliConst.audioNames[value] ?? '音频';
              return '$name · ${(stream.bandwidth / 1000).round()} kbps';
            },
            onSelect: (value) => parse.setAudioId(value),
          ),
        ],
      ),
    );
  }

  Widget _buildContents(BuildContext context, ParseController parse) {
    return TdSection(
      title: '下载内容',
      child: Column(
        children: <Widget>[
          TdCheckRow(
            title: '视频',
            value: parse.wantVideo,
            onChanged: (value) {
              parse.wantVideo = value;
              parse.touch();
            },
          ),
          TdCheckRow(
            title: '音频',
            value: parse.wantAudio,
            onChanged: (value) {
              parse.wantAudio = value;
              parse.touch();
            },
          ),
          TdCheckRow(
            title: '封面',
            value: parse.wantCover,
            onChanged: (value) {
              parse.wantCover = value;
              parse.touch();
            },
          ),
          TdCheckRow(
            title: '弹幕',
            description: '格式：${parse.settings.danmakuFormat.label}',
            value: parse.wantDanmaku,
            onChanged: (value) {
              parse.wantDanmaku = value;
              parse.touch();
            },
          ),
          TdCheckRow(
            title: '字幕',
            description: '优先下载中文（CC）字幕，转为 srt',
            value: parse.wantSubtitle,
            onChanged: (value) {
              parse.wantSubtitle = value;
              parse.touch();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final parse = context.read<ParseController>();
    if (!parse.wantVideo && !parse.wantAudio) {
      tdToast(context, '请至少选择「视频」或「音频」');
      return;
    }
    if (parse.wantVideo && parse.wantAudio && !parse.availableCodecs.contains(parse.codec)) {
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
