import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../data/bili_api.dart';
import '../../data/http_client.dart';
import '../../data/models.dart';
import '../../state/parse_controller.dart';
import '../td.dart';
import '../widgets/video_card.dart';
import 'media_list_page.dart';
import 'video_detail_page.dart';

/// 站内搜索：不用切到 B 站 App 就能找视频并直接下载。
///
/// 结果复用 [MediaItem] / [BatchResult]，于是「批量下载 + 清晰度弹窗 + cid 补查」
/// 全部走现成链路——搜索接口本身不返回 cid，下载前由
/// `DownloadManager._ensureCid` 与 `ParseController.loadBatchReference` 补查。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialKeyword = ''});

  final String initialKeyword;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialKeyword);

  final List<MediaItem> _items = <MediaItem>[];
  final Set<String> _selected = <String>{};

  String _keyword = '';
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword.trim().isNotEmpty) {
      unawaited(_search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BiliApi get _api => context.read<ParseController>().api;

  Future<void> _search({bool more = false}) async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      tdToast(context, '请输入搜索关键词');
      return;
    }
    if (more) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      _keyword = keyword;
      _items.clear();
      _selected.clear();
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final next = more ? _page + 1 : 1;
      final result = await _api.searchVideo(keyword: keyword, page: next);
      if (!mounted) return;
      setState(() {
        _page = next;
        _hasMore = result.hasMore;
        _items.addAll(result.items);
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = _describe(error);
      });
    }
  }

  String _describe(Object error) {
    if (error is ApiException) {
      // -412 是搜索接口特有的风控返回：Cookies 校验不足会被直接拦截
      if (error.code == -412) {
        return '搜索被 B 站拦截（-412）\n请先到「我的」里登录，登录后再试';
      }
      if (error.needLogin) return '${error.message}\n登录后可正常搜索';
      return error.message;
    }
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return TdPage(
      title: '站内搜索',
      showDivider: true,
      backgroundColor: TdPalette.pageBackground,
      child: Column(
        children: <Widget>[
          _buildSearchBar(),
          Expanded(child: _buildBody()),
          if (_selected.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: TdPalette.container,
      padding: const EdgeInsets.fromLTRB(
        TdSpacer.medium,
        TdSpacer.small,
        TdSpacer.medium,
        TdSpacer.small,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: TdPalette.gray1,
                borderRadius: BorderRadius.circular(TdRadius.medium),
              ),
              padding: const EdgeInsets.symmetric(horizontal: TdSpacer.small),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => unawaited(_search()),
                style: TdText.bodyMedium,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '搜索视频 / UP 主投稿',
                  hintStyle: TextStyle(color: TdPalette.textPlaceholder, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: TdSpacer.small),
          TDButton(
            text: _loading ? '搜索中…' : '搜索',
            theme: TDButtonTheme.primary,
            size: TDButtonSize.medium,
            disabled: _loading,
            onTap: () => unawaited(_search()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return TdEmptyView(
        text: error,
        operationText: '重试',
        onTap: () => unawaited(_search()),
      );
    }
    if (_items.isEmpty) {
      return const TdEmptyView(text: '输入关键词开始搜索，点结果可直接解析下载');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: TdSpacer.medium),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: TdSpacer.medium),
            child: Center(
              child: _loadingMore
                  ? const TdLoadingView(text: '加载更多')
                  : TDButton(
                      text: '加载更多',
                      theme: TDButtonTheme.light,
                      size: TDButtonSize.small,
                      onTap: () => unawaited(_search(more: true)),
                    ),
            ),
          );
        }
        final item = _items[index];
        return VideoInfoTile(
          title: item.title,
          cover: item.cover,
          subtitle: item.ownerName.isEmpty ? item.bvid : '${item.ownerName} · ${item.bvid}',
          durationMs: item.durationMs,
          leading: TDCheckbox(
            checked: _selected.contains(item.bvid),
            size: TDCheckBoxSize.small,
            insetSpacing: 0,
            showDivider: false,
            onCheckBoxChanged: (_) => _toggle(item),
          ),
          // 点整行 = 直接解析这个视频（单下载）；批量靠左侧复选框
          onTap: () => unawaited(_openVideo(item)),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: TdPalette.container,
      child: SafeArea(
        top: false,
        child: TdPrimaryAction(
          text: '下载选中（${_selected.length}）',
          onTap: () => unawaited(_downloadSelected()),
        ),
      ),
    );
  }

  void _toggle(MediaItem item) {
    setState(() {
      if (_selected.contains(item.bvid)) {
        _selected.remove(item.bvid);
      } else {
        _selected.add(item.bvid);
      }
    });
  }

  Future<void> _openVideo(MediaItem item) async {
    final parse = context.read<ParseController>();
    final ok = await parse.parse(item.bvid);
    if (!mounted) return;
    if (!ok) {
      tdToastError(context, parse.error ?? '解析失败');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VideoDetailPage()),
    );
  }

  Future<void> _downloadSelected() async {
    final selected = _items.where((item) => _selected.contains(item.bvid)).toList();
    if (selected.isEmpty) return;
    final parse = context.read<ParseController>();
    parse.setBatchDirectly(
      BatchResult(title: '搜索：$_keyword', items: selected),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MediaListPage()),
    );
  }
}
