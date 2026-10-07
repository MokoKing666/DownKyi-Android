import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import 'choice.dart';

/// 下载选项面板：清晰度 / 视频编码 / 音频 / 下载内容。
///
/// 「解析结果页」与「批量下载设置」共用这一份实现，两处选项都来自**真实
/// `playurl` 的 `dash` 数据**，因此只会列出该视频确实支持的档位——
/// 不会出现「视频没有 8K 却给出 8K 选项」这种情况。
///
/// 唯一例外：批量下载连参考视频都解析不出来时（未登录 / 付费内容 / 网络异常），
/// 调用方可以传入 [fallbackQualities] 退回通用档位，并自行提示用户。
class DownloadOptionsPanel extends StatelessWidget {
  const DownloadOptionsPanel({
    super.key,
    required this.parse,
    this.onChanged,
    this.fallbackQualities,
    this.card = false,
  });

  final ParseController parse;

  /// 调用方额外的重建回调：批量弹窗靠它 `setState`；
  /// 解析结果页由 Provider 自动重建，可以不传。
  final VoidCallback? onChanged;

  /// 拿不到真实 dash 时退回的通用档位列表
  final List<int>? fallbackQualities;

  /// true = 每组选项各自包一张 [TdSection] 卡片（解析结果页的观感）
  /// false = 纯分组标题（弹窗里用，容器由调用方提供）
  final bool card;

  /// 是否拿到了真实的 dash 数据
  bool get _hasRealData => parse.dash != null;

  List<int> get _qualities =>
      _hasRealData ? parse.availableQualities : (fallbackQualities ?? const <int>[]);

  List<String> get _codecs =>
      _hasRealData ? parse.availableCodecs : const <String>['avc', 'hevc', 'av1'];

  bool get _showAudio => _hasRealData && parse.availableAudios.isNotEmpty;

  void _apply(VoidCallback change) {
    change();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _wrap('清晰度', _qualityChild()),
      if (_codecs.length > 1) _wrap('视频编码', _codecChild()),
      if (_showAudio) _wrap('音频', _audioChild()),
      _wrap('下载内容', _contentsChild()),
    ];

    if (card) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < sections.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: TdSpacer.medium),
          sections[index],
        ],
      ],
    );
  }

  Widget _wrap(String title, Widget child) {
    if (card) return TdSection(title: title, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TdText.titleSmall),
        const SizedBox(height: TdSpacer.xs),
        child,
      ],
    );
  }

  Widget _qualityChild() {
    final qualities = _qualities;
    if (qualities.isEmpty) {
      return Text(
        parse.dash == null
            ? '清晰度信息获取失败：${parse.error ?? '未知错误'}'
            : '该视频没有可用的清晰度',
        style: TdText.bodySmall.copyWith(color: TdPalette.warning),
      );
    }
    return TdChoiceGroup<int>(
      items: qualities,
      selected: parse.quality,
      labelBuilder: parse.qualityLabel,
      onSelect: (value) => _apply(() => parse.setQuality(value)),
    );
  }

  Widget _codecChild() {
    return TdChoiceGroup<String>(
      items: _codecs,
      selected: parse.codec,
      labelBuilder: (value) => switch (value) {
        'hevc' => 'HEVC / H.265',
        'av1' => 'AV1',
        _ => 'AVC / H.264',
      },
      onSelect: (value) => _apply(() => parse.setCodec(value)),
    );
  }

  Widget _audioChild() {
    final audios = parse.availableAudios;
    return TdChoiceGroup<int>(
      items: audios.map((item) => item.id).toList(),
      selected: parse.audioId,
      labelBuilder: (value) {
        final stream = audios.firstWhere(
          (item) => item.id == value,
          orElse: () => audios.first,
        );
        final name = BiliConst.audioNames[value] ?? '音频';
        return '$name · ${(stream.bandwidth / 1000).round()} kbps';
      },
      onSelect: (value) => _apply(() => parse.setAudioId(value)),
    );
  }

  Widget _contentsChild() {
    return Column(
      children: <Widget>[
        TdCheckRow(
          title: '视频',
          value: parse.wantVideo,
          onChanged: (value) => _apply(() => parse.wantVideo = value),
        ),
        TdCheckRow(
          title: '音频',
          value: parse.wantAudio,
          onChanged: (value) => _apply(() => parse.wantAudio = value),
        ),
        TdCheckRow(
          title: '封面',
          value: parse.wantCover,
          onChanged: (value) => _apply(() => parse.wantCover = value),
        ),
        TdCheckRow(
          title: '弹幕',
          description: '格式：${parse.settings.danmakuFormat.label}',
          value: parse.wantDanmaku,
          onChanged: (value) => _apply(() => parse.wantDanmaku = value),
        ),
        TdCheckRow(
          title: '字幕',
          description: '优先下载中文（CC）字幕，转为 srt',
          value: parse.wantSubtitle,
          onChanged: (value) => _apply(() => parse.wantSubtitle = value),
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
