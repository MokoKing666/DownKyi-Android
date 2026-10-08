import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import 'download_options.dart';

/// 批量下载前的设置弹窗。
///
/// 与「解析结果页」共用 [DownloadOptionsPanel]，选项来自
/// [ParseController.loadBatchReference] 取回的**真实 playurl 数据**，
/// 所以不会把视频并不支持的清晰度列出来。
///
/// [referenceLoaded] 为 false 表示参考视频没解析成功（未登录 / 会员内容 / 网络异常），
/// 此时退回通用档位并明确提示用户。
Future<bool> showDownloadOptionsSheet(
  BuildContext context, {
  required int count,
  required bool referenceLoaded,
}) async {
  final parse = context.read<ParseController>();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DownloadOptionsSheet(
      parse: parse,
      count: count,
      referenceLoaded: referenceLoaded,
    ),
  );
  return confirmed ?? false;
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({
    required this.parse,
    required this.count,
    required this.referenceLoaded,
  });

  final ParseController parse;
  final int count;
  final bool referenceLoaded;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  ParseController get parse => widget.parse;

  /// 参考视频解析失败时的通用档位（去掉几乎用不到的 240P）
  List<int> get _genericQualities =>
      BiliConst.qualityNames.keys.where((key) => key != 6).toList();

  @override
  Widget build(BuildContext context) {
    final canDownload = parse.wantVideo || parse.wantAudio;

    return Container(
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(TdRadius.extraLarge)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                    if (widget.referenceLoaded)
                      _buildReferenceNote()
                    else
                      _buildFailureNote(),
                    const SizedBox(height: TdSpacer.medium),
                    DownloadOptionsPanel(
                      parse: parse,
                      onChanged: () => setState(() {}),
                      fallbackQualities:
                          widget.referenceLoaded ? null : _genericQualities,
                    ),
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
      padding: const EdgeInsets.fromLTRB(
        TdSpacer.medium,
        TdSpacer.medium,
        TdSpacer.medium,
        TdSpacer.small,
      ),
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

  Widget _buildReferenceNote() {
    return _note(
      color: TdPalette.brandLight,
      title: '可选项按参考视频解析：${parse.referenceTitle ?? ''}',
      body: '下面列出的都是该视频真实支持的档位。其余视频若没有同一档位，'
          '会自动回退到各自可用的最高清晰度与最佳音轨。',
    );
  }

  Widget _buildFailureNote() {
    final reason = parse.referenceError;
    return _note(
      color: TdPalette.warningLight,
      title: '未能解析参考视频的可选项',
      body: '${reason == null ? '' : '$reason；'}'
          '下面列出的是通用档位。每个视频下载时都会自动回退到它实际支持的档位，'
          '常见的失败原因是未登录或需要大会员。',
    );
  }

  Widget _note(
      {required Color color, required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TdSpacer.small),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TdRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: TdText.bodySmall.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(body,
              style: TdText.bodySmall.copyWith(color: TdPalette.textSecondary)),
        ],
      ),
    );
  }
}
