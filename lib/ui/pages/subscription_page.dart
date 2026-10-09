import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../bili/link_parser.dart';
import '../../bili/models.dart';
import '../../data/subscription.dart';
import '../../data/subscription_dao.dart';
import '../../download/download_manager.dart';
import '../../state/parse_controller.dart';
import '../../subscription/subscription_service.dart';
import '../td.dart';
import '../widgets/video_card.dart';
import 'media_list_page.dart';

/// 订阅列表：持久化 + 增量检查 + 主动通知。
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionDao _dao = SubscriptionDao.instance;

  List<Subscription> _subscriptions = <Subscription>[];
  final Map<int, int> _pending = <int, int>{};
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  SubscriptionService get _service => SubscriptionService(
        api: context.read<ParseController>().api,
        dao: _dao,
        manager: context.read<DownloadManager>(),
      );

  Future<void> _load() async {
    final list = await _dao.loadAll();
    final pending = <int, int>{};
    for (final item in list) {
      pending[item.id] = await _dao.pendingCount(item.id);
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = list;
      _pending
        ..clear()
        ..addAll(pending);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TdPage(
      title: '订阅',
      showDivider: true,
      backgroundColor: TdPalette.pageBackground,
      child: _loading
          ? const Center(
              child: TDLoading(
                  size: TDLoadingSize.medium, icon: TDLoadingIcon.circle))
          : Column(
              children: <Widget>[
                Expanded(
                  child: _subscriptions.isEmpty
                      ? TdEmptyView(
                          text: '还没有订阅',
                          operationText: '添加订阅',
                          onTap: () => unawaited(_addSubscription()),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(TdSpacer.medium),
                          children: <Widget>[
                            for (final item in _subscriptions) _buildItem(item),
                          ],
                        ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildItem(Subscription subscription) {
    final pending = _pending[subscription.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: TdSpacer.small),
      padding: const EdgeInsets.all(TdSpacer.medium),
      decoration: BoxDecoration(
        color: TdPalette.container,
        borderRadius: BorderRadius.circular(TdRadius.large),
        border: Border.all(color: TdPalette.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  subscription.title.isEmpty
                      ? '未命名订阅 ${subscription.sourceId}'
                      : subscription.title,
                  style: TdText.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pending > 0) TdLabel('$pending 个未处理'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              TdLabel(
                subscription.kind.label,
                color: TdPalette.textSecondary,
                background: TdPalette.gray2,
              ),
              const SizedBox(width: TdSpacer.xs),
              Expanded(
                child: Text(
                  _describeChecked(subscription),
                  style: TdText.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TdSpacer.small),
          Wrap(
            spacing: TdSpacer.xs,
            runSpacing: TdSpacer.xs,
            children: <Widget>[
              TDButton(
                text: pending > 0 ? '查看 $pending 个新内容' : '查看内容',
                theme: TDButtonTheme.primary,
                type: TDButtonType.outline,
                size: TDButtonSize.extraSmall,
                onTap: () => unawaited(_openItems(subscription)),
              ),
              TDButton(
                text: '立即检查',
                theme: TDButtonTheme.light,
                type: TDButtonType.fill,
                size: TDButtonSize.extraSmall,
                onTap: () => unawaited(_checkOne(subscription)),
              ),
              TDButton(
                text: subscription.autoDownload ? '自动下载：开' : '自动下载：关',
                theme: subscription.autoDownload
                    ? TDButtonTheme.primary
                    : TDButtonTheme.light,
                type: subscription.autoDownload
                    ? TDButtonType.outline
                    : TDButtonType.fill,
                size: TDButtonSize.extraSmall,
                onTap: () => unawaited(_toggleAutoDownload(subscription)),
              ),
              TDButton(
                text: '删除',
                theme: TDButtonTheme.light,
                type: TDButtonType.text,
                size: TDButtonSize.extraSmall,
                onTap: () => unawaited(_confirmDelete(subscription)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: TdPalette.container,
      padding: const EdgeInsets.symmetric(
          horizontal: TdSpacer.medium, vertical: TdSpacer.small),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: TDButton(
                text: '添加订阅',
                theme: TDButtonTheme.light,
                type: TDButtonType.fill,
                size: TDButtonSize.medium,
                isBlock: true,
                onTap: () => unawaited(_addSubscription()),
              ),
            ),
            const SizedBox(width: TdSpacer.small),
            Expanded(
              child: TDButton(
                text: _checking ? '检查中…' : '全部检查',
                theme: TDButtonTheme.primary,
                size: TDButtonSize.medium,
                isBlock: true,
                disabled: _checking || _subscriptions.isEmpty,
                onTap: () => unawaited(_checkAll()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _describeChecked(Subscription subscription) {
    if (subscription.lastCheckedAt == 0) return '尚未检查';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(subscription.lastCheckedAt),
    );
    if (diff.inMinutes < 1) return '刚刚检查过';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前检查';
    if (diff.inHours < 24) return '${diff.inHours} 小时前检查';
    return '${diff.inDays} 天前检查';
  }

  // ------------------------------------------------------------------
  // 操作
  // ------------------------------------------------------------------

  Future<void> _addSubscription() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => TDAlertDialog(
        title: '添加订阅',
        contentWidget: TDTextarea(
          controller: controller,
          maxLines: 3,
          minLines: 1,
          hintText: '粘贴 UP 主空间 / 合集 / 收藏夹 / 番剧 ss 链接',
          backgroundColor: TdPalette.gray1,
        ),
        leftBtn: TDDialogButtonOptions(
          title: '取消',
          action: () => Navigator.of(dialogContext).pop(),
        ),
        rightBtn: TDDialogButtonOptions(
          title: '添加',
          action: () => Navigator.of(dialogContext).pop(controller.text.trim()),
        ),
      ),
    );
    if (input == null || input.isEmpty || !mounted) return;
    await _createFromLink(input);
  }

  Future<void> _createFromLink(String input) async {
    final parse = context.read<ParseController>();
    var link = parseLink(input);
    if (link.kind == LinkKind.shortLink) {
      try {
        final target = input.contains('http') ? input : 'https://$input';
        final resolved = await parse.api.resolveShortLink(target);
        link = parseLink(resolved);
      } catch (error) {
        if (mounted) tdToastError(context, '短链解析失败：$error');
        return;
      }
    }
    final kind = SubscriptionKind.ofLink(link.kind);
    if (kind == null || link.id == null) {
      if (mounted) {
        tdToast(context, '这类链接不能订阅。支持：UP 主空间 / 合集 / 收藏夹 / 番剧整季（ss）');
      }
      return;
    }
    final subscription = Subscription(kind: kind, sourceId: link.id!);
    await _dao.insert(subscription);
    // 新增后立刻检查一次：首次检查只播种，不会误报一堆「新内容」
    await _checkOne(subscription, silent: true);
    if (!mounted) return;
    tdToastSuccess(context, '已添加订阅');
  }

  Future<void> _checkOne(Subscription subscription,
      {bool silent = false}) async {
    if (mounted) setState(() => _checking = true);
    try {
      final result = await _service.check(subscription);
      if (!mounted) return;
      if (result.failed) {
        tdToastError(context, '检查失败：${result.error}');
      } else if (!silent) {
        if (result.seeded) {
          tdToast(context, '已记录当前 ${_pending[subscription.id] ?? 0} 条内容作为基准');
        } else if (result.hasNew) {
          tdToastSuccess(context, '发现 ${result.newItems.length} 个新内容');
        } else {
          tdToast(context, '暂无更新');
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
      await _load();
    }
  }

  Future<void> _checkAll() async {
    setState(() => _checking = true);
    try {
      final results = await _service.checkAll();
      if (!mounted) return;
      final found =
          results.fold<int>(0, (sum, item) => sum + item.newItems.length);
      final failed = results.where((item) => item.failed).length;
      if (failed == results.length && results.isNotEmpty) {
        tdToastError(context, '全部检查失败，请确认已登录');
      } else if (found > 0) {
        tdToastSuccess(context, '发现 $found 个新内容');
      } else {
        tdToast(context, '暂无更新');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
      await _load();
    }
  }

  Future<void> _toggleAutoDownload(Subscription subscription) async {
    subscription.autoDownload = !subscription.autoDownload;
    await _dao.update(subscription);
    if (!mounted) return;
    if (subscription.autoDownload) {
      tdToast(context, '已开启自动下载：发现新内容会直接创建任务');
    }
    await _load();
  }

  Future<void> _confirmDelete(Subscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => TDAlertDialog(
        title: '删除订阅',
        content:
            '将同时清除「${subscription.title.isEmpty ? subscription.sourceId : subscription.title}」'
            '已发现的内容记录。已下载的文件不受影响。',
        leftBtn: TDDialogButtonOptions(
          title: '取消',
          action: () => Navigator.of(dialogContext).pop(false),
        ),
        rightBtn: TDDialogButtonOptions(
          title: '删除',
          action: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    );
    if (confirmed != true) return;
    await _dao.delete(subscription.id);
    if (!mounted) return;
    tdToast(context, '已删除订阅');
    await _load();
  }

  Future<void> _openItems(Subscription subscription) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionItemsPage(subscription: subscription),
      ),
    );
    await _load();
  }
}

/// 单个订阅已发现的内容；未处理的可勾选后走批量下载流程。
class SubscriptionItemsPage extends StatefulWidget {
  const SubscriptionItemsPage({super.key, required this.subscription});

  final Subscription subscription;

  @override
  State<SubscriptionItemsPage> createState() => _SubscriptionItemsPageState();
}

class _SubscriptionItemsPageState extends State<SubscriptionItemsPage> {
  final SubscriptionDao _dao = SubscriptionDao.instance;
  final Set<String> _selected = <String>{};

  List<SeenItem> _items = <SeenItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final items = await _dao.pendingItems(widget.subscription.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _selected
        ..clear()
        ..addAll(items.map((item) => item.key));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TdPage(
      title: widget.subscription.title.isEmpty
          ? '订阅内容'
          : widget.subscription.title,
      showDivider: true,
      backgroundColor: TdPalette.pageBackground,
      child: _loading
          ? const Center(
              child: TDLoading(
                  size: TDLoadingSize.medium, icon: TDLoadingIcon.circle))
          : _items.isEmpty
              ? const TdEmptyView(text: '没有未处理的新内容')
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TdSpacer.medium),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return VideoInfoTile(
                            title: item.title,
                            cover: item.cover,
                            subtitle: item.epId == null
                                ? item.bvid
                                : 'ep${item.epId}',
                            durationMs: item.durationMs,
                            leading: TdCheckboxField(
                              checked: _selected.contains(item.key),
                              onChanged: (_) => _toggle(item),
                            ),
                            onTap: () => _toggle(item),
                          );
                        },
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  void _toggle(SeenItem item) {
    setState(() {
      if (_selected.contains(item.key)) {
        _selected.remove(item.key);
      } else {
        _selected.add(item.key);
      }
    });
  }

  Widget _buildBottomBar() {
    return Container(
      color: TdPalette.container,
      child: SafeArea(
        top: false,
        child: TdPrimaryAction(
          text: _selected.isEmpty ? '下载选中（0）' : '下载选中（${_selected.length}）',
          onTap: _selected.isEmpty ? null : () => unawaited(_download()),
        ),
      ),
    );
  }

  Future<void> _download() async {
    final selected =
        _items.where((item) => _selected.contains(item.key)).toList();
    if (selected.isEmpty) return;
    final items = selected
        .map((item) => MediaItem(
              bvid: item.bvid,
              cid: item.cid,
              aid: 0,
              title: item.title,
              cover: item.cover,
              durationMs: item.durationMs,
              epId: item.epId,
              btype: item.epId == null
                  ? BiliConst.typeVideo
                  : BiliConst.typeBangumi,
            ))
        .toList();

    final parse = context.read<ParseController>();
    // 复用批量列表页：勾选 / 清晰度弹窗（含真实档位解析）/ 创建任务全部现成
    parse.setBatchDirectly(
      BatchResult(title: widget.subscription.title, items: items),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaListPage(
          onEnqueued: (enqueued) async {
            await _dao.markDownloaded(
              widget.subscription.id,
              enqueued.map((item) => '${item.bvid}|${item.epId ?? 0}'),
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }
}
