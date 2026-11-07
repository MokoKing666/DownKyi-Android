import 'package:flutter/foundation.dart';

import '../core/logger.dart';
import '../native/bridge.dart';
import 'download_rules.dart';

/// 本机解码能力（评审第 17 项）。
///
/// B 站现在同一个视频给出 AVC / HEVC / AV1 三种编码，外加 HDR、杜比视界等档位。
/// 选错了不是「画质差一点」，而是**下完根本放不出来**——花半小时下了 4K HDR HEVC，
/// 结果手机没有 10-bit 硬解，播放器要么黑屏要么软解到掉帧。
///
/// 所以定位是「提前提醒」，不是「禁止选择」：
/// 设备上报的能力并不总是完整（有些 ROM 的 profileLevels 缺项），
/// 硬拦会误伤能播的设备。界面只给建议，用户仍然可以无视。
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    this.avc = true,
    this.hevc = false,
    this.av1 = false,
    this.hevc10Bit = false,
    this.hdr = false,
    this.dolbyVision = false,
    this.probed = false,
  });

  final bool avc;
  final bool hevc;
  final bool av1;
  final bool hevc10Bit;
  final bool hdr;
  final bool dolbyVision;

  /// 是否真的探测过（false 表示探测失败，此时全部按「支持」处理，不给建议）
  final bool probed;

  static const DeviceCapabilities unknown = DeviceCapabilities(probed: false);

  static DeviceCapabilities fromMap(Map<Object?, Object?> map) =>
      DeviceCapabilities(
        avc: map['avc'] == true,
        hevc: map['hevc'] == true,
        av1: map['av1'] == true,
        hevc10Bit: map['hevc10bit'] == true,
        hdr: map['hdr'] == true,
        dolbyVision: map['dolbyVision'] == true,
        probed: true,
      );

  /// 探测失败时返回 [unknown]，绝不因为探测问题影响正常下载
  static Future<DeviceCapabilities> load() async {
    try {
      final raw = await NativeBridge.decoderCapabilities();
      if (raw == null) return unknown;
      return fromMap(raw);
    } catch (error) {
      AppLog.e('Device', '解码能力探测失败', error);
      return unknown;
    }
  }

  bool supports(String codec) => switch (codec) {
        'hevc' => hevc,
        'av1' => av1,
        _ => avc,
      };

  static String codecLabel(String codec) => switch (codec) {
        'hevc' => 'HEVC / H.265',
        'av1' => 'AV1',
        _ => 'AVC / H.264',
      };

  /// 界面上的一行行清单：✓ 支持 / ✗ 不支持
  List<({String label, bool ok})> get rows => <({String label, bool ok})>[
        (label: 'AVC / H.264', ok: avc),
        (label: 'HEVC / H.265', ok: hevc),
        (label: 'AV1', ok: av1),
        (label: '10-bit', ok: hevc10Bit),
        (label: 'HDR', ok: hdr),
        (label: '杜比视界', ok: dolbyVision),
      ];

  /// 这个档位 + 编码在本机可能播不了的原因；空列表表示没问题。
  List<String> warningsFor({required int quality, required String codec}) {
    if (!probed) return const <String>[];
    final issues = <String>[];

    if (!supports(codec)) {
      issues.add('本机没有 ${codecLabel(codec)} 硬件解码器，可能需要软解（耗电、可能掉帧）');
    }
    if (quality == 126) {
      if (!dolbyVision) issues.add('本机未上报杜比视界支持，画面可能偏色甚至黑屏');
      if (!hevc10Bit) issues.add('杜比视界需要 10-bit 解码能力，本机未上报');
    } else if (quality == 125) {
      if (!hdr) issues.add('本机未上报 HDR 支持，色彩映射可能不正常');
      if (!hevc10Bit) issues.add('HDR 需要 10-bit 解码能力，本机未上报');
    } else if (quality == 127 && !hevc && !av1) {
      issues.add('8K 需要 HEVC 或 AV1 解码能力，本机都没有上报');
    }

    return issues;
  }

  /// 从可用档位里挑一个本机大概率能正常播的。
  ///
  /// 排序规则：先按偏好模式的清晰度顺序，逐档检查是否有「无警告」的编码；
  /// 全都有警告就返回 [fallback]（通常是最初选中的档位），不做强制拦截。
  int recommend({
    required PreferenceMode mode,
    required List<int> available,
    required int fallback,
  }) {
    if (!probed || available.isEmpty) return fallback;
    final ordered = kQualityPriority.where(available.contains).toList();
    if (ordered.isEmpty) return fallback;

    for (final quality in ordered) {
      for (final codec in SmartPicker.codecOrder(mode)) {
        if (warningsFor(quality: quality, codec: codec).isEmpty) return quality;
      }
    }
    return fallback;
  }

  /// 推荐文案，例如「推荐 1080P 高清 · AVC」；无法给出时返回 null
  String? describeRecommendation({
    required PreferenceMode mode,
    required List<int> available,
    required String Function(int quality) qualityLabel,
  }) {
    if (!probed) return null;
    final picked = recommend(mode: mode, available: available, fallback: -1);
    if (picked < 0) return null;
    for (final codec in SmartPicker.codecOrder(mode)) {
      if (warningsFor(quality: picked, codec: codec).isEmpty) {
        return '本机推荐 ${qualityLabel(picked)} · ${codecLabel(codec)}';
      }
    }
    return null;
  }
}
