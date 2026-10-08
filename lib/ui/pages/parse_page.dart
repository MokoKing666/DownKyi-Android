import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/constants.dart';
import '../../bili/link_parser.dart';
import '../../bili/bili_api.dart';
import '../../data/http_client.dart';
import '../../bili/models.dart';
import '../../data/subscription.dart';
import '../../data/subscription_dao.dart';
import '../../state/login_controller.dart';
import '../../state/parse_controller.dart';
import '../../subscription/notification_service.dart';
import '../td.dart';
import 'login_page.dart';
import 'media_list_page.dart';
import 'search_page.dart';
import 'subscription_page.dart';
import 'video_detail_page.dart';

/// 首页：粘贴链接解析 + 常用入口。
class ParsePage extends StatefulWidget {
  const ParsePage({super.key});

  @override
  State<ParsePage> createState() => _ParsePageState();
}

class _ParsePageState extends State<ParsePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 点击订阅通知时（App 已在前台）直接跳到该订阅的新内容页
    NotificationService.instance.onOpenSubscription = _openSubscriptionById;
    // 冷启动：App 是因为点击通知才被拉起的
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = NotificationService.instance.consumePendingSubscriptionId();
      if (id != 0) unawaited(_openSubscriptionById(id));
    });
  }

  @override
  void dispose() {
    NotificationService.instance.onOpenSubscription = null;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      tdToast(context, '请先粘贴视频链接或 BV 号');
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = context.read<ParseController>();
    final success = await controller.parse(input);
    if (!mounted) return;
    if (!success) {
      // 输入既不是链接也不是 BV 号时，引导到站内搜索——
      // 用户手里往往只有「视频标题」，不该逼他切到 B 站去复制链接
      if (parseLink(input).kind == LinkKind.unknown) {
        await _offerSearch(input);
        return;
      }
      tdToastError(context, controller.error ?? '解析失败');
      return;
    }
    if (controller.video != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VideoDetailPage()),
      );
    } else if (controller.batch != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MediaListPage()),
      );
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      tdToast(context, '剪贴板为空');
      return;
    }
    _controller.text = text;
    setState(() {});
  }

  Future<void> _openLink(String input) async {
    _controller.text = input;
    await _parse();
  }

  @override
  Widget build(BuildContext context) {
    final parse = context.watch<ParseController>();
    final login = context.watch<LoginController>();

    return Container(
      color: TdPalette.pageBackground,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: TdSpacer.large),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(TdSpacer.medium,
                  TdSpacer.large, TdSpacer.medium, TdSpacer.small),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(AppInfo.name,
                            style: TdText.display.copyWith(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          '解析 B 站视频 / 番剧 / 收藏夹 / 合集，支持多线程下载与断点续传',
                          style: TdText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '站内搜索',
                    onPressed: () => unawaited(_openSearch(context)),
                    icon: Icon(Icons.search, color: TdPalette.textPrimary),
                  ),
                  TdLabel(login.isLogin ? '已登录' : '未登录',
                      color:
                          login.isLogin ? TdPalette.success : TdPalette.warning,
                      background: login.isLogin
                          ? TdPalette.successLight
                          : TdPalette.warningLight),
                ],
              ),
            ),
            TdSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: TdPalette.gray1,
                      borderRadius: BorderRadius.circular(TdRadius.medium),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: TdSpacer.small),
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 3,
                      style: TdText.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '粘贴视频链接 / BV 号 / ep、ss 号 / 收藏夹 / 合集链接',
                        hintStyle: TextStyle(
                            color: TdPalette.textPlaceholder, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: TdSpacer.small),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TDButton(
                          text: '从剪贴板粘贴',
                          theme: TDButtonTheme.light,
                          type: TDButtonType.fill,
                          size: TDButtonSize.medium,
                          isBlock: true,
                          onTap: _paste,
                        ),
                      ),
                      const SizedBox(width: TdSpacer.small),
                      Expanded(
                        child: TDButton(
                          text: parse.loading ? '解析中…' : '开始解析',
                          theme: TDButtonTheme.primary,
                          size: TDButtonSize.medium,
                          isBlock: true,
                          disabled: parse.loading,
                          onTap: _parse,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            TdSection(
              title: '常用入口',
              // 按实际可用宽度等分两列：固定宽度在宽屏下每行只占 312px，
              // 右侧会留出一条参差的空隙，窄屏又容易挤掉文字。
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = TdSpacer.small;
                  const columns = 2;
                  final itemWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Column(
                    children: <Widget>[
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: <Widget>[
                          _shortcut(
                            width: itemWidth,
                            icon: Icons.star_outline,
                            title: '我的收藏夹',
                            onTap: () => _openFavorites(context),
                          ),
                          _shortcut(
                            width: itemWidth,
                            icon: Icons.history,
                            title: '观看历史',
                            onTap: () => _openHistory(context),
                          ),
                          _shortcut(
                            width: itemWidth,
                            icon: Icons.watch_later_outlined,
                            title: '稍后再看',
                            onTap: () => _openToView(context),
                          ),
                          _shortcut(
                            width: itemWidth,
                            icon: Icons.playlist_play,
                            title: 'UP 主合集',
                            onTap: () => _promptMid(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: spacing),
                      // 订阅是「常驻跟踪 + 主动通知」，和上面四个一次性入口不是一类，
                      // 所以单独占满整行：既在视觉上区分开，也避免 5 个卡片排成 2+2+1 的参差
                      _shortcut(
                        width: constraints.maxWidth,
                        icon: Icons.notifications_active_outlined,
                        title: '订阅更新（追 UP 主 / 合集 / 番剧）',
                        onTap: () => _openSubscriptions(context),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            TdSection(
              title: '账号',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      login.isLogin
                          ? '当前账号：${login.navInfo?.uname ?? '已登录'}'
                          : '未登录。登录后可下载 1080P+ / 4K 及会员内容',
                      style: TdText.bodyMedium,
                    ),
                  ),
                  TDButton(
                    text: login.isLogin ? '切换' : '去登录',
                    theme: TDButtonTheme.primary,
                    type: TDButtonType.text,
                    size: TDButtonSize.small,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TdSpacer.small),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
              child: Text(
                AppInfo.disclaimer,
                style:
                    TdText.bodySmall.copyWith(color: TdPalette.textPlaceholder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcut({
    required double width,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TdRadius.large),
      child: Container(
        width: width,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: TdSpacer.small),
        decoration: BoxDecoration(
          color: TdPalette.gray1,
          borderRadius: BorderRadius.circular(TdRadius.large),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: TdPalette.brand),
            const SizedBox(width: TdSpacer.xs),
            Expanded(
              child: Text(title,
                  style: TdText.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.chevron_right, size: 16, color: TdPalette.gray6),
          ],
        ),
      ),
    );
  }

  Future<void> _openFavorites(BuildContext context) async {
    final login = context.read<LoginController>();
    final mid = login.navInfo?.mid ?? 0;
    if (mid == 0) {
      tdToast(context, '请先登录后再查看收藏夹');
      return;
    }
    final api = context.read<ParseController>().api;
    try {
      tdLoadingShow(context, text: '读取收藏夹');
      final folders = await api.favFolders(mid);
      tdLoadingHide();
      if (!mounted) return;
      if (folders.isEmpty) {
        tdToast(context, '没有找到收藏夹');
        return;
      }
      final selected = await showModalBottomSheet<FavFolder>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: BoxDecoration(
            color: TdPalette.container,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TdRadius.extraLarge)),
          ),
          padding: const EdgeInsets.all(TdSpacer.medium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('选择收藏夹', style: TdText.titleSmall),
              const SizedBox(height: TdSpacer.small),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final folder in folders)
                      TDCell(
                        title: folder.title,
                        note: '${folder.count} 个视频',
                        arrow: true,
                        onClick: (cell) =>
                            Navigator.of(sheetContext).pop(folder),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      await _openLink(
          'https://www.bilibili.com/medialist/detail/ml${selected.id}?fid=${selected.id}');
    } catch (error) {
      tdLoadingHide();
      if (!mounted) return;
      tdToastError(context, '读取收藏夹失败：${_describeError(error)}');
    }
  }

  Future<void> _openHistory(BuildContext context) async {
    await _runBatch(context, (controller) async {
      final items = await controller.api.history();
      if (items.isEmpty) return null;
      return BatchResult(title: '观看历史', items: items);
    }, loginRequired: true);
  }

  Future<void> _openToView(BuildContext context) async {
    await _runBatch(context, (controller) async {
      final items = await controller.api.toView();
      if (items.isEmpty) return null;
      return BatchResult(title: '稍后再看', items: items);
    }, loginRequired: true);
  }

  Future<void> _openSubscriptions(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchPage()),
    );
  }

  /// 输入既不是链接也不是 BV 号时，问一下要不要把它当关键词去站内搜索
  Future<void> _offerSearch(String keyword) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text('这不是链接', style: TdText.titleSmall),
        content: Text('要在站内搜索「$keyword」吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => SearchPage(initialKeyword: keyword)),
    );
  }

  /// 从通知跳到某个订阅的新内容页；订阅已被删除时退回到订阅列表
  Future<void> _openSubscriptionById(int id) async {
    if (!mounted) return;
    Subscription? found;
    for (final item in await SubscriptionDao.instance.loadAll()) {
      if (item.id == id) {
        found = item;
        break;
      }
    }
    if (!mounted) return;
    final target = found;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => target == null
            ? const SubscriptionPage()
            : SubscriptionItemsPage(subscription: target),
      ),
    );
  }

  Future<void> _promptMid(BuildContext context) async {
    final controller = TextEditingController();
    final mid = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TdPalette.container,
        title: Text('输入 UP 主 UID', style: TdText.titleSmall),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '例如 2（可在空间地址里找到）'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消')),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (mid == null || mid.isEmpty) return;
    if (!mounted) return;
    await _openLink('https://space.bilibili.com/$mid');
  }

  Future<void> _runBatch(
    BuildContext context,
    Future<BatchResult?> Function(ParseController controller) loader, {
    bool loginRequired = false,
  }) async {
    final login = context.read<LoginController>();
    if (loginRequired && !login.isLogin) {
      tdToast(context, '请先登录');
      return;
    }
    final controller = context.read<ParseController>();
    try {
      tdLoadingShow(context, text: '加载中');
      final batch = await loader(controller);
      controller.setBatchDirectly(batch);
      tdLoadingHide();
      if (!mounted) return;
      if (batch == null || batch.items.isEmpty) {
        tdToast(context, '没有可取的内容');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MediaListPage()),
      );
    } catch (error) {
      tdLoadingHide();
      if (!mounted) return;
      tdToastError(context, '加载失败：${_describeError(error)}');
    }
  }

  /// 把接口错误翻译成用户能看懂的原因
  String _describeError(Object error) {
    if (error is ApiException) {
      if (error.needLogin) {
        return '${error.message}（请重新登录刷新 Cookie）';
      }
      return error.message;
    }
    return '$error';
  }
}
