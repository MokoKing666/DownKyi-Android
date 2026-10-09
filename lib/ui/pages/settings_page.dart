import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../bili/subtitles.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../core/secret_store.dart';
import '../../data/http_client.dart';
import '../../data/settings_store.dart';
import '../../download/download_archive.dart';
import '../../download/download_manager.dart';
import '../../download/download_rules.dart';
import '../../subscription/subscription_scheduler.dart';
import '../td.dart';
import '../theme.dart';
import '../widgets/choice.dart';
import '../widgets/theme_picker.dart';

/// 设置页
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final manager = context.read<DownloadManager>();

    return TdPage(
      title: '设置',
      showDivider: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: TdSpacer.large),
        children: <Widget>[
          // ---------------- 凭据降级警告 ----------------
          // 加密存储不可用时，凭据会以明文落在 SharedPreferences。
          // 旧实现是静默降级——用户不知道自己的 SESSDATA 正以明文存储。
          // 审查明确要求「不得在未告知用户的情况下降级」，所以置顶显示。
          if (!SecretStore.available) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(TdSpacer.medium),
              decoration: BoxDecoration(
                color: TdPalette.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(TdRadius.large),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('加密存储不可用', style: TdText.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '系统密钥库初始化失败，Cookie 与 aria2 密钥正以明文存储。'
                    '请勿在不可信的设备上使用，也不要把运行日志贴给陌生人。',
                    style: TdText.bodySmall
                        .copyWith(color: TdPalette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
          ],

          // ---------------- 主题外观 ----------------
          TdSection(
            title: '主题外观',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ThemeSummary(
                  style: settings.themeStyle,
                  followSystem: settings.followSystemDark,
                  onTap: () => showThemePicker(context),
                ),
                const SizedBox(height: TdSpacer.xs),
                Text(
                  '默认「简洁白」，强调色为哔哩哔哩粉；已移除原有的蓝色主题。',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 保存位置 ----------------
          TdSection(
            title: '保存位置',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdChoiceGroup<SaveLocation>(
                  items: SaveLocation.values,
                  selected: settings.saveLocation,
                  labelBuilder: (value) => value.label,
                  onSelect: (value) =>
                      settings.update(() => settings.saveLocation = value),
                ),
                const SizedBox(height: TdSpacer.xs),
                FutureBuilder<String>(
                  future: manager.describeSaveLocation(),
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? '读取中…',
                    style: TdText.bodySmall,
                  ),
                ),
                if (settings.saveLocation == SaveLocation.custom) ...<Widget>[
                  const SizedBox(height: TdSpacer.xs),
                  Row(
                    children: <Widget>[
                      TDButton(
                        text: '设置自定义目录',
                        theme: TDButtonTheme.light,
                        size: TDButtonSize.small,
                        onTap: () => _editText(
                          context,
                          title: '自定义下载目录',
                          hint: '例如 /storage/emulated/0/Download/DownKyi',
                          initial: settings.downloadDir,
                          onSave: (value) => settings
                              .update(() => settings.downloadDir = value),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: TdSpacer.xs),
                Text(
                  settings.saveLocation == SaveLocation.gallery
                      ? '默认保存到系统相册：视频 → Movies/${AppInfo.englishName}，图片 → Pictures/${AppInfo.englishName}，'
                          '弹幕 / 字幕 → Downloads/${AppInfo.englishName}。其他应用与相册都能直接看到。'
                      : '保存在应用目录或自定义目录时不进入媒体库，卸载应用会删除应用目录内的文件；'
                          '需要长期保存请在下载页或工具箱用「导出到相册」。',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 下载引擎 ----------------
          TdSection(
            title: '下载引擎',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdChoiceGroup<DownloadEngine>(
                  items: DownloadEngine.values,
                  selected: settings.downloadEngine,
                  labelBuilder: (value) => value.label,
                  onSelect: (value) =>
                      settings.update(() => settings.downloadEngine = value),
                ),
                const SizedBox(height: TdSpacer.xs),
                Text(
                  settings.downloadEngine.description,
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
                if (settings.downloadEngine ==
                    DownloadEngine.aria2) ...<Widget>[
                  const SizedBox(height: TdSpacer.small),
                  TDCell(
                    title: 'RPC 地址',
                    description: settings.aria2RpcUrl,
                    arrow: true,
                    onClick: (cell) => _editText(
                      context,
                      title: 'aria2 RPC 地址',
                      hint: 'http://127.0.0.1:6800/jsonrpc',
                      initial: settings.aria2RpcUrl,
                      onSave: (value) => settings.update(
                        () => settings.aria2RpcUrl = value.isEmpty
                            ? SettingsStore.defaultAria2Url
                            : value,
                      ),
                    ),
                  ),
                  TDCell(
                    title: 'RPC 密钥',
                    description: settings.aria2Secret.isEmpty ? '未设置' : '已设置',
                    arrow: true,
                    onClick: (cell) => _editText(
                      context,
                      title: 'aria2 RPC 密钥（--rpc-secret）',
                      hint: '留空表示未启用',
                      initial: settings.aria2Secret,
                      obscure: true,
                      onSave: (value) =>
                          settings.update(() => settings.aria2Secret = value),
                    ),
                  ),
                  TDCell(
                    title: '落盘目录',
                    description: settings.aria2Dir.isEmpty
                        ? '使用 aria2 默认目录'
                        : settings.aria2Dir,
                    arrow: true,
                    onClick: (cell) => _editText(
                      context,
                      title: 'aria2 落盘目录',
                      hint: 'aria2 所在设备上的路径，例如 /volume1/downloads',
                      initial: settings.aria2Dir,
                      onSave: (value) =>
                          settings.update(() => settings.aria2Dir = value),
                    ),
                  ),
                  const SizedBox(height: TdSpacer.xs),
                  Text('单文件连接数：${settings.aria2Split}',
                      style: TdText.bodyMedium),
                  const SizedBox(height: TdSpacer.xs),
                  TdChoiceGroup<int>(
                    items: const <int>[4, 8, 16],
                    selected: settings.aria2Split,
                    labelBuilder: (value) => '$value',
                    onSelect: (value) =>
                        settings.update(() => settings.aria2Split = value),
                  ),
                  const SizedBox(height: TdSpacer.xs),
                  Row(
                    children: <Widget>[
                      TDButton(
                        text: '测试连接',
                        theme: TDButtonTheme.light,
                        size: TDButtonSize.small,
                        onTap: () => _testAria2(context, manager),
                      ),
                    ],
                  ),
                  const SizedBox(height: TdSpacer.xs),
                  Text(
                    'Aria2 模式下任务由 aria2 执行，文件落在 aria2 所在设备（NAS / 电脑 / Termux 等），'
                    'App 负责下发任务与显示进度，不参与合并与相册导出。\n'
                    '如果需要「自动合并并存入系统相册」，请使用内置下载器。',
                    style: TdText.bodySmall
                        .copyWith(color: TdPalette.textPlaceholder),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 并发 ----------------
          TdSection(
            title: '并发',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('同时下载任务数：${settings.concurrentTasks}',
                    style: TdText.bodyMedium),
                const SizedBox(height: TdSpacer.xs),
                TdChoiceGroup<int>(
                  items: const <int>[1, 2, 3, 4],
                  selected: settings.concurrentTasks,
                  labelBuilder: (value) => '$value 个',
                  onSelect: (value) =>
                      settings.update(() => settings.concurrentTasks = value),
                ),
                const SizedBox(height: TdSpacer.medium),
                Text('单任务分片线程数：${settings.segmentConcurrency}',
                    style: TdText.bodyMedium),
                const SizedBox(height: TdSpacer.xs),
                TdChoiceGroup<int>(
                  items: const <int>[1, 2, 4, 8, 16],
                  selected: settings.segmentConcurrency,
                  labelBuilder: (value) => '$value 线程',
                  onSelect: (value) => settings
                      .update(() => settings.segmentConcurrency = value),
                ),
                const SizedBox(height: TdSpacer.medium),
                Text(
                    '任务启动间隔：${settings.taskIntervalSeconds == 0 ? '不限' : '${settings.taskIntervalSeconds} 秒'}',
                    style: TdText.bodyMedium),
                const SizedBox(height: TdSpacer.xs),
                TdChoiceGroup<int>(
                  items: const <int>[0, 2, 5, 10],
                  selected: settings.taskIntervalSeconds,
                  labelBuilder: (value) => value == 0 ? '不限' : '$value 秒',
                  onSelect: (value) => settings
                      .update(() => settings.taskIntervalSeconds = value),
                ),
                const SizedBox(height: TdSpacer.xs),
                Text(
                  '批量下载时把任务启动错开，能显著降低被 B 站风控（-412）的概率。'
                  '只在批量下载经常失败时才需要调。',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 下载偏好（智能选档）----------------
          TdSection(
            title: '下载偏好',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdChoiceGroup<PreferenceMode>(
                  items: PreferenceMode.values,
                  selected: settings.preferenceMode,
                  labelBuilder: (value) => value.label,
                  onSelect: (value) =>
                      settings.update(() => settings.preferenceMode = value),
                ),
                const SizedBox(height: 6),
                Text(
                  settings.preferenceMode.description,
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
                const SizedBox(height: 4),
                Text(
                  '打开解析结果时会按偏好自动选好清晰度 / 编码 / 音轨，之后也可以手动改。'
                  '选档时会给出手势体积预估与本机解码能力提示。',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 字幕语言 ----------------
          TdSection(
            title: '字幕',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TDCell(
                  title: '下载语言',
                  description: settings.subtitleSummary,
                  arrow: true,
                  onClick: (cell) => _pickSubtitleLanguages(context, settings),
                ),
                const SizedBox(height: TdSpacer.small),
                Text('AI 字幕：${settings.aiSubtitleStrategy.label}',
                    style: TdText.bodyMedium),
                const SizedBox(height: TdSpacer.xs),
                TdChoiceGroup<AiSubtitleStrategy>(
                  items: AiSubtitleStrategy.values,
                  selected: settings.aiSubtitleStrategy,
                  labelBuilder: (value) => value.label,
                  onSelect: (value) => settings
                      .update(() => settings.aiSubtitleStrategy = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 合并方式 ----------------
          TdSection(
            title: '合并方式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdChoiceGroup<MuxEngine>(
                  items: MuxEngine.values,
                  selected: settings.muxEngine,
                  labelBuilder: (value) => value.label,
                  onSelect: (value) =>
                      settings.update(() => settings.muxEngine = value),
                ),
                const SizedBox(height: 6),
                Text(
                  settings.muxEngine.description,
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
                const SizedBox(height: TdSpacer.small),
                TdSwitchRow(
                  title: '写入标题与封面',
                  description: '合并后把标题 / UP 主 / 封面嵌入成品（FFmpeg，'
                      '部分机型对杜比视界片源可能不兼容，出问题请关闭）',
                  value: settings.embedMetadata,
                  onChanged: (value) =>
                      settings.update(() => settings.embedMetadata = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 弹幕样式 ----------------
          TdSection(
            title: '弹幕样式',
            child: Column(
              children: <Widget>[
                TDCell(
                  title: 'ASS 样式',
                  description: settings.danmakuStyle.summary,
                  arrow: true,
                  onClick: (cell) => _editDanmakuStyle(context, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 默认清晰度 ----------------
          TdSection(
            title: '默认清晰度',
            child: TdChoiceGroup<int>(
              items: BiliConst.qualityNames.keys.toList(),
              selected: settings.defaultQuality,
              labelBuilder: (value) =>
                  BiliConst.qualityNames[value] ?? '$value',
              onSelect: (value) =>
                  settings.update(() => settings.defaultQuality = value),
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 默认视频编码 ----------------
          TdSection(
            title: '默认视频编码',
            child: TdChoiceGroup<String>(
              items: const <String>['avc', 'hevc', 'av1'],
              selected: settings.codecPreference,
              labelBuilder: (value) => switch (value) {
                'hevc' => 'HEVC / H.265',
                'av1' => 'AV1',
                _ => 'AVC / H.264',
              },
              onSelect: (value) =>
                  settings.update(() => settings.codecPreference = value),
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 弹幕格式 ----------------
          TdSection(
            title: '弹幕格式',
            child: TdChoiceGroup<DanmakuFormat>(
              items: DanmakuFormat.values
                  .where((value) => value != DanmakuFormat.none)
                  .toList(growable: false),
              selected: settings.danmakuFormat,
              labelBuilder: (value) => value.label,
              onSelect: (value) =>
                  settings.update(() => settings.danmakuFormat = value),
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 文件命名 ----------------
          TdSection(
            title: '文件命名',
            child: TdChoiceGroup<String>(
              items: SettingsStore.templates,
              selected: settings.fileNameTemplate,
              labelBuilder: settings.describeTemplate,
              onSelect: (value) =>
                  settings.update(() => settings.fileNameTemplate = value),
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 默认下载内容 ----------------
          TdSection(
            title: '默认下载内容',
            child: Column(
              children: <Widget>[
                TdSwitchRow(
                  title: '视频',
                  value: settings.downloadVideo,
                  onChanged: (value) =>
                      settings.update(() => settings.downloadVideo = value),
                ),
                TdSwitchRow(
                  title: '音频',
                  value: settings.downloadAudio,
                  onChanged: (value) =>
                      settings.update(() => settings.downloadAudio = value),
                ),
                TdSwitchRow(
                  title: '封面',
                  value: settings.downloadCover,
                  onChanged: (value) =>
                      settings.update(() => settings.downloadCover = value),
                ),
                TdSwitchRow(
                  title: '弹幕',
                  value: settings.downloadDanmaku,
                  onChanged: (value) =>
                      settings.update(() => settings.downloadDanmaku = value),
                ),
                TdSwitchRow(
                  title: '字幕',
                  description: '需要视频本身有 CC 字幕',
                  value: settings.downloadSubtitle,
                  onChanged: (value) =>
                      settings.update(() => settings.downloadSubtitle = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 下载归档 ----------------
          TdSection(
            title: '下载归档',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdSwitchRow(
                  title: '跳过已下载过的视频',
                  description: '按 BV / 分P / 清晰度 / 编码判定；追更时不会重复下载旧视频',
                  value: settings.archiveEnabled,
                  onChanged: (value) =>
                      settings.update(() => settings.archiveEnabled = value),
                ),
                TDCell(
                  title: '清除归档记录',
                  description: '清除后允许重新下载以前下过的视频',
                  arrow: true,
                  onClick: (cell) async {
                    final count = await DownloadArchive.instance.clear();
                    if (context.mounted) {
                      tdToast(context, '已清除 $count 条归档记录');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- FFmpeg 转换 ----------------
          TdSection(
            title: '格式转换（FFmpeg）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('GIF 帧率：${settings.gifFps}', style: TdText.bodyMedium),
                const SizedBox(height: TdSpacer.xs),
                TdChoiceGroup<int>(
                  items: const <int>[8, 12, 16, 24],
                  selected: settings.gifFps,
                  labelBuilder: (value) => '$value fps',
                  onSelect: (value) =>
                      settings.update(() => settings.gifFps = value),
                ),
                const SizedBox(height: TdSpacer.xs),
                Text(
                  '转换入口在「工具」页：可把已下载的视频无损封装为 MP4 / MKV、'
                  '提取 MP3 / M4A 音频、生成 GIF、压缩体积或在 H.264 与 H.265 之间互转。',
                  style: TdText.bodySmall
                      .copyWith(color: TdPalette.textPlaceholder),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 订阅检查 ----------------
          TdSection(
            title: '订阅检查',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TdSwitchRow(
                  title: '周期后台检查',
                  description: '系统调度不保证准时，打开 App 时还会补检查一次',
                  value: settings.subscriptionCheckEnabled,
                  onChanged: (value) {
                    settings.update(
                        () => settings.subscriptionCheckEnabled = value);
                    unawaited(SubscriptionScheduler.instance.apply(
                      enabled: value,
                      intervalHours: settings.subscriptionIntervalHours,
                    ));
                  },
                ),
                if (settings.subscriptionCheckEnabled) ...<Widget>[
                  const SizedBox(height: TdSpacer.small),
                  TdChoiceGroup<int>(
                    items: SettingsStore.subscriptionIntervalOptions,
                    selected: settings.subscriptionIntervalHours,
                    labelBuilder: (value) => '$value 小时',
                    onSelect: (value) {
                      settings.update(
                          () => settings.subscriptionIntervalHours = value);
                      unawaited(SubscriptionScheduler.instance.apply(
                        enabled: settings.subscriptionCheckEnabled,
                        intervalHours: value,
                      ));
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),

          // ---------------- 其它 ----------------
          TdSection(
            title: '其它',
            child: Column(
              children: <Widget>[
                TdSwitchRow(
                  title: '自动合并音视频',
                  description: '关闭后只下载分片，可在工具箱手动合并',
                  value: settings.mergeAv,
                  onChanged: (value) =>
                      settings.update(() => settings.mergeAv = value),
                ),
                TdSwitchRow(
                  title: '仅 Wi-Fi 下载',
                  description: '移动网络下任务会自动暂停',
                  value: settings.wifiOnly,
                  onChanged: (value) =>
                      settings.update(() => settings.wifiOnly = value),
                ),
                const SizedBox(height: TdSpacer.xs),
                Row(
                  children: <Widget>[
                    TDButton(
                      text: '查看运行日志',
                      theme: TDButtonTheme.light,
                      size: TDButtonSize.small,
                      onTap: () => _showLog(context),
                    ),
                    const SizedBox(width: TdSpacer.xs),
                    TDButton(
                      text: '清空日志',
                      type: TDButtonType.text,
                      size: TDButtonSize.small,
                      onTap: () {
                        AppLog.clear();
                        tdToast(context, '日志已清空');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 通用文本编辑弹窗
  /// 字幕语言多选。
  ///
  /// 用「选语言」而不是「选一条字幕」：用户关心的是「我要中英双语」，
  /// 而具体挑哪条（人工 CC 还是 AI 字幕）是 SubtitleLanguage.select 的事。
  Future<void> _pickSubtitleLanguages(
    BuildContext context,
    SettingsStore settings,
  ) async {
    final selected = <String>{...settings.subtitleLanguages};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TdPalette.container,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(TdSpacer.medium),
                child: Text('下载哪些语言的字幕', style: TdText.titleSmall),
              ),
              for (final language in SubtitleLanguage.all)
                TdCheckRow(
                  title: language.label,
                  value: selected.contains(language.code),
                  onChanged: (value) => setSheetState(() {
                    if (value) {
                      selected.add(language.code);
                    } else {
                      selected.remove(language.code);
                    }
                  }),
                ),
              Padding(
                padding: const EdgeInsets.all(TdSpacer.medium),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await settings.update(() {
      settings.subtitleLanguages = selected.toList();
      // 选了语言等于要下字幕，顺手把开关打开，少一步操作
      settings.downloadSubtitle = selected.isNotEmpty;
    });
  }

  /// 弹幕 ASS 样式。
  ///
  /// 之前字号 / 时长 / 占屏比例全是写死的，手机上 40 号字偏小、4K 片源里又铺满整屏。
  /// 现在这几项都能调，并且实时给出摘要。
  Future<void> _editDanmakuStyle(
    BuildContext context,
    SettingsStore settings,
  ) async {
    var style = settings.danmakuStyle;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TdPalette.container,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(TdSpacer.medium),
                  child: Text('弹幕 ASS 样式', style: TdText.titleSmall),
                ),
                _styleGroup<double>(
                  '字号',
                  const <double>[0.6, 0.8, 1.0, 1.2, 1.5],
                  style.fontScale,
                  (value) => setSheetState(
                      () => style = style.copyWith(fontScale: value)),
                  (value) => '${(value * 100).round()}%',
                ),
                _styleGroup<double>(
                  '不透明度',
                  const <double>[0.5, 0.7, 0.85, 1.0],
                  style.opacity,
                  (value) => setSheetState(
                      () => style = style.copyWith(opacity: value)),
                  (value) => '${(value * 100).round()}%',
                ),
                _styleGroup<int>(
                  '滚动时长',
                  const <int>[4000, 6000, 8000, 12000],
                  style.scrollDurationMs,
                  (value) => setSheetState(
                      () => style = style.copyWith(scrollDurationMs: value)),
                  (value) => '${value ~/ 1000} 秒',
                ),
                _styleGroup<double>(
                  '占屏比例',
                  const <double>[0.4, 0.55, 0.75, 1.0],
                  style.laneRatio,
                  (value) => setSheetState(
                      () => style = style.copyWith(laneRatio: value)),
                  (value) => '${(value * 100).round()}%',
                ),
                TdSwitchRow(
                  title: '滚动弹幕',
                  value: style.enableScroll,
                  onChanged: (value) => setSheetState(
                      () => style = style.copyWith(enableScroll: value)),
                ),
                TdSwitchRow(
                  title: '顶部弹幕',
                  value: style.enableTop,
                  onChanged: (value) => setSheetState(
                      () => style = style.copyWith(enableTop: value)),
                ),
                TdSwitchRow(
                  title: '底部弹幕',
                  value: style.enableBottom,
                  onChanged: (value) => setSheetState(
                      () => style = style.copyWith(enableBottom: value)),
                ),
                Padding(
                  padding: const EdgeInsets.all(TdSpacer.medium),
                  child: Text(
                    style.summary,
                    style: TdText.bodySmall
                        .copyWith(color: TdPalette.textPlaceholder),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      TdSpacer.medium, 0, TdSpacer.medium, TdSpacer.medium),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await settings.update(() => settings.danmakuStyle = style);
  }

  Widget _styleGroup<T>(
    String title,
    List<T> items,
    T selected,
    ValueChanged<T> onSelect,
    String Function(T value) label,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TdText.titleSmall),
          const SizedBox(height: TdSpacer.xs),
          TdChoiceGroup<T>(
            items: items,
            selected: selected,
            labelBuilder: label,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required void Function(String value) onSave,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text(title, style: TdText.titleSmall),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消')),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    onSave(value);
    if (context.mounted) tdToast(context, '已保存');
  }

  Future<void> _testAria2(BuildContext context, DownloadManager manager) async {
    tdLoadingShow(context, text: '连接中');
    try {
      final version = await manager.aria2.getVersion();
      final stat = await manager.aria2.getGlobalStat();
      tdLoadingHide();
      if (context.mounted) {
        tdToastSuccess(
          context,
          '连接成功：aria2 $version（活动 ${stat.active} / 等待 ${stat.waiting}）',
        );
      }
    } on ApiException catch (error) {
      tdLoadingHide();
      if (context.mounted) tdToastError(context, error.message);
    } catch (error) {
      tdLoadingHide();
      if (context.mounted) tdToastError(context, '连接失败：$error');
    }
  }

  void _showLog(BuildContext context) {
    final lines = AppLog.lines;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text('运行日志', style: TdText.titleSmall),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: lines.isEmpty
              ? Text('暂无日志', style: TdText.bodySmall)
              : ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(lines[index], style: TdText.bodySmall),
                  ),
                ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭')),
        ],
      ),
    );
  }
}

/// 主题外观摘要行（点击进入主题选择）
class _ThemeSummary extends StatelessWidget {
  const _ThemeSummary({
    required this.style,
    required this.followSystem,
    required this.onTap,
  });

  final AppThemeStyle style;
  final bool followSystem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(TdRadius.medium),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Row(
                children: <Widget>[
                  for (final color in style.preview)
                    Expanded(child: ColoredBox(color: color)),
                ],
              ),
            ),
          ),
          const SizedBox(width: TdSpacer.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(style.label, style: TdText.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  followSystem ? '跟随系统深色模式' : '固定主题，不跟随系统',
                  style: TdText.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 22, color: TdPalette.gray6),
        ],
      ),
    );
  }
}
