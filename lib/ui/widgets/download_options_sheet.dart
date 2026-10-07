import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import 'choice.dart';

/// 批量下载前的选项弹窗：清晰度 / 编码 / 下载内容。
///
/// 批量列表（收藏夹 / 合集 / 观看历史 / 稍后再看 / 整季番剧）在创建任务前
/// 并没有逐个视频的 playurl 信息，所以这里给的是通用清晰度列表；
/// 选到某个视频不支持的档位不会失败——服务端会回退到该视频实际可用的档位
/// （见 `DashInfo.pickVideo` 的兜底逻辑）。
///
/// 返回 true 表示用户点了「确认并创建任务」。
Future<bool> showDownloadOptionsSheet(
  BuildContext context, {
  required int count,
}) async {
  final parse = context.read<ParseController>();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DownloadOptionsSheet(parse: parse, count: count),
  );
  return confirmed ?? false;
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({required this.parse, required this.count});

  final ParseController parse;
  final int count;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  ParseController get parse => widget.parse;

  /// 清晰度：用通用表（去掉几乎用不到的 240P），
  /// 当前档位若不在表里则补到最前面，避免出现「一个都没选中」。
  List<int> get _qualities {
    final list = BiliConst.qualityNames.keys.where((key) => key != 6).toList();
    if (!list.contains(parse.quality)) list.insert(0, parse.quality);
    return list;
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final canDownload = parse.wantVideo || parse.wantAudio;

    return Container(
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TdRadius.extraLarge)),
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
                padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildQuality(),
                    const SizedBox(height: TdSpacer.medium),
                    _buildCodec(),
                    const SizedBox(height: TdSpacer.medium),
                    _buildContents(),
                    const SizedBox(height: TdSpacer.small),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TdSpacer.medium,
                TdSpacer.xs,
                TdSpacer.medium,
                TdSpacer.small,
              ),
              child: TDButton(
                text: '确认并创建 ${widget.count} 个任务',
                theme: TDButtonTheme.primary,
                size: TDButtonSize.large,
                isBlock: true,
                disabled: !canDownload,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(TdSpacer.medium, TdSpacer.medium, TdSpacer.medium, TdSpacer.small),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('下载设置', style: TdText.titleSmall)),
          Text('已选 ${widget.count} 个视频', style: TdText.bodySmall),
          const SizedBox(width: TdSpacer.xs),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            child: Icon(Icons.close, size: 20, color: TdPalette.gray6),
          ),
        ],
      ),
    );
  }

  Widget _buildQuality() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('清晰度', style: TdText.titleSmall),
        const SizedBox(height: TdSpacer.xs),
        TdChoiceGroup<int>(
          items: _qualities,
          selected: parse.quality,
          labelBuilder: parse.qualityLabel,
          onSelect: (value) => _update(() => parse.setQuality(value)),
        ),
        const SizedBox(height: 6),
        Text(
          '超出视频实际档位时会自动回退到该视频的最高可用清晰度',
          style: TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
        ),
      ],
    );
  }

  Widget _buildCodec() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('视频编码', style: TdText.titleSmall),
        const SizedBox(height: TdSpacer.xs),
        TdChoiceGroup<String>(
          items: const <String>['avc', 'hevc', 'av1'],
          selected: parse.codec,
          labelBuilder: (value) => switch (value) {
            'hevc' => 'HEVC / H.265',
            'av1' => 'AV1',
            _ => 'AVC / H.264',
          },
          onSelect: (value) => _update(() => parse.setCodec(value)),
        ),
        const SizedBox(height: 6),
        Text(
          '同档位没有所选编码时，会自动改用该档位可用的编码；音轨自动选择最高码率',
          style: TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
        ),
      ],
    );
  }

  Widget _buildContents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('下载内容', style: TdText.titleSmall),
        const SizedBox(height: TdSpacer.xxs),
        TdCheckRow(
          title: '视频',
          value: parse.wantVideo,
          onChanged: (value) => _update(() => parse.wantVideo = value),
        ),
        TdCheckRow(
          title: '音频',
          value: parse.wantAudio,
          onChanged: (value) => _update(() => parse.wantAudio = value),
        ),
        TdCheckRow(
          title: '封面',
          value: parse.wantCover,
          onChanged: (value) => _update(() => parse.wantCover = value),
        ),
        TdCheckRow(
          title: '弹幕',
          description: '格式：${parse.settings.danmakuFormat.label}',
          value: parse.wantDanmaku,
          onChanged: (value) => _update(() => parse.wantDanmaku = value),
        ),
        TdCheckRow(
          title: '字幕',
          description: '优先下载中文（CC）字幕，转为 srt',
          value: parse.wantSubtitle,
          onChanged: (value) => _update(() => parse.wantSubtitle = value),
        ),
        if (!parse.wantVideo && !parse.wantAudio)
          Padding(
            padding: const EdgeInsets.only(top: TdSpacer.xs),
            child: Text(
              '请至少选择「视频」或「音频」',
              style: TdText.bodySmall.copyWith(color: TdPalette.warning),
            ),
          ),
      ],
    );
  }
}
