import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../core/formatter.dart';
import '../../download/device_capabilities.dart';
import '../../download/download_rules.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import 'choice.dart';

/// 解码能力只探测一次，之后复用（探测本身要遍历 MediaCodecList，不必每次重建都做）
DeviceCapabilities? _capabilityCache;

Future<DeviceCapabilities> _capabilities() async {
  return _capabilityCache ??= await DeviceCapabilities.load();
}

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

  List<int> get _qualities => _hasRealData
      ? parse.availableQualities
      : (fallbackQualities ?? const <int>[]);

  List<String> get _codecs => _hasRealData
      ? parse.availableCodecs
      : const <String>['avc', 'hevc', 'av1'];

  bool get _showAudio => _hasRealData && parse.availableAudios.isNotEmpty;

  void _apply(VoidCallback change) {
    change();
    // 解析结果页靠 ParseController 的重建刷新；弹窗靠 onChanged 里的 setState
    parse.touch();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      // 偏好模式放最前面：它是「先决定思路」，后面的清晰度/编码都会被它带着走
      _wrap('智能选档', _modeChild()),
      _wrap('清晰度', _qualityChild()),
      if (_codecs.length > 1) _wrap('视频编码', _codecChild()),
      if (_showAudio) _wrap('音频', _audioChild()),
      _wrap('下载内容', _contentsChild()),
      // 保存位置放在这里，解析完就能直接改，不用再跳回设置页
      _wrap('保存位置', _locationChild(context)),
    ];

    if (card) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: sections);
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
      // 标签带上预估体积，让「画质 vs 体积」可以在同一行里直接比较
      labelBuilder: _qualityLabelWithSize,
      onSelect: (value) => _apply(() => parse.setQuality(value)),
    );
  }

  /// 清晰度标签 + 预估体积（评审第 16 项）。
  /// DASH 拿不到真实总长，这里是按码率 × 时长估算，误差通常在 5% 以内。
  String _qualityLabelWithSize(int quality) {
    final base = parse.qualityLabel(quality);
    final dash = parse.dash;
    if (dash == null) return base;
    final bytes =
        MediaEstimator.videoBytes(dash, quality, parse.codec, dash.durationMs);
    if (bytes <= 0) return base;
    return '$base · ${formatBytes(bytes)}';
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
          description: '语言：${parse.settings.subtitleSummary}（设置页可多选）',
          value: parse.wantSubtitle,
          onChanged: (value) => _apply(() => parse.wantSubtitle = value),
        ),
        if (!parse.wantVideo && !parse.wantAudio)
          Padding(
            padding: const EdgeInsets.only(top: TdSpacer.xs),
            child: Text(
              '只下封面 / 弹幕 / 字幕，不保存视频文件；这些文件会放进 Download 目录',
              style:
                  TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
            ),
          ),
      ],
    );
  }

  Widget _locationChild(BuildContext context) {
    final settings = parse.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TdChoiceGroup<SaveLocation>(
          items: SaveLocation.values,
          selected: settings.saveLocation,
          labelBuilder: (value) => value.label,
          onSelect: (value) => _apply(
            () =>
                unawaited(settings.update(() => settings.saveLocation = value)),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _describeLocation(),
                style:
                    TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
              ),
            ),
            if (settings.saveLocation == SaveLocation.custom)
              TDButton(
                text: settings.downloadDir.isEmpty ? '设置目录' : '修改',
                theme: TDButtonTheme.light,
                type: TDButtonType.text,
                size: TDButtonSize.extraSmall,
                onTap: () => unawaited(_editCustomDir(context)),
              ),
          ],
        ),
      ],
    );
  }

  String _describeLocation() {
    final settings = parse.settings;
    switch (settings.saveLocation) {
      case SaveLocation.gallery:
        return '视频 → Movies/${AppInfo.englishName}；封面 / 弹幕 / 字幕 → Download/${AppInfo.englishName}';
      case SaveLocation.appDir:
        return '应用专属外部目录，卸载应用会一并删除';
      case SaveLocation.custom:
        return settings.downloadDir.isEmpty
            ? '尚未设置目录，会回退到应用目录'
            : settings.downloadDir;
    }
  }

  /// 智能选档：切换模式时立刻按模式把清晰度 / 编码 / 音轨都重新选好，
  /// 而不是只把一个开关存起来——用户要的是结果，不是配置项。
  Widget _modeChild() {
    final settings = parse.settings;
    final dash = parse.dash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TdChoiceGroup<PreferenceMode>(
          items: PreferenceMode.values,
          selected: settings.preferenceMode,
          labelBuilder: (value) => value.label,
          onSelect: _applyMode,
        ),
        const SizedBox(height: 6),
        Text(
          settings.preferenceMode.description,
          style: TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
        ),
        if (dash != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            '当前组合预估体积 '
            '${MediaEstimator.describe(dash, quality: parse.quality, codec: parse.codec, audioId: parse.audioId)}',
            style: TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
          ),
        ],
        const SizedBox(height: 6),
        _DeviceCapabilityCard(
          parse: parse,
          onRecommend: _applyMode,
        ),
      ],
    );
  }

  void _applyMode(PreferenceMode mode) {
    final settings = parse.settings;
    unawaited(settings.update(() => settings.preferenceMode = mode));

    final dash = parse.dash;
    if (dash == null) {
      _apply(() {});
      return;
    }
    final quality = SmartPicker.pickQuality(dash, mode);
    final codec = SmartPicker.pickCodec(dash, quality, mode);
    final audioId = SmartPicker.pickAudioId(dash, mode);
    _apply(() {
      parse.setQuality(quality);
      if (codec != null) parse.setCodec(codec);
      if (audioId != null) parse.setAudioId(audioId);
    });
  }

  Future<void> _editCustomDir(BuildContext context) async {
    final settings = parse.settings;
    final controller = TextEditingController(text: settings.downloadDir);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text('自定义下载目录', style: TdText.titleSmall),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例如 /storage/emulated/0/Download/DownKyi',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    _apply(
        () => unawaited(settings.update(() => settings.downloadDir = value)));
  }
}

/// 本机解码能力卡片（评审第 17 项）。
///
/// 探测是异步的，所以做成独立的 StatefulWidget 自己管加载——
/// 免得把「设备能力」这种和视频解析无关的状态塞进 ParseController。
///
/// 这里只给**建议**，不做拦截：设备上报的 profileLevels 经常缺项，
/// 硬拦会把本来能播的设备误判掉。
class _DeviceCapabilityCard extends StatefulWidget {
  const _DeviceCapabilityCard({required this.parse, required this.onRecommend});

  final ParseController parse;
  final void Function(PreferenceMode mode) onRecommend;

  @override
  State<_DeviceCapabilityCard> createState() => _DeviceCapabilityCardState();
}

class _DeviceCapabilityCardState extends State<_DeviceCapabilityCard> {
  DeviceCapabilities _caps = DeviceCapabilities.unknown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final caps = await _capabilities();
    if (!mounted) return;
    setState(() {
      _caps = caps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder);
    if (_loading) {
      return Text('正在检测本机解码能力…', style: placeholder);
    }
    if (!_caps.probed) {
      return Text('未能读取本机解码能力，已跳过兼容性提示', style: placeholder);
    }

    final parse = widget.parse;
    final quality = parse.quality;
    final codec = parse.codec;
    final warnings = parse.dash == null
        ? const <String>[]
        : _caps.warningsFor(quality: quality, codec: codec);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: TdSpacer.small,
          runSpacing: 2,
          children: <Widget>[
            for (final row in _caps.rows)
              Text(
                '${row.ok ? '✓' : '✗'} ${row.label}',
                style: TdText.bodySmall.copyWith(
                  color: row.ok ? TdPalette.brand : TdPalette.textPlaceholder,
                ),
              ),
          ],
        ),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠ $warning',
              style: TdText.bodySmall.copyWith(color: TdPalette.warning),
            ),
          ),
      ],
    );
  }
}
