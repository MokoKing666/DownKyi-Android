import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../state/login_controller.dart';
import '../td.dart';

/// 登录页：扫码登录 + Cookie 粘贴登录。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _cookieController = TextEditingController();

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginController>();

    return TdPage(
      title: '账号登录',
      showDivider: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: TdSpacer.large),
        children: <Widget>[
          if (login.isLogin) _buildProfile(context, login),
          TdSection(
            title: '扫码登录（推荐）',
            child: Column(
              children: <Widget>[
                const SizedBox(height: TdSpacer.xs),
                if (login.qr == null)
                  Text('点击下方按钮生成二维码，然后用 B 站客户端扫码', style: TdText.bodySmall)
                else
                  Center(
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(TdSpacer.small),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(TdRadius.medium),
                            border: Border.all(color: TdPalette.border),
                          ),
                          child: QrImageView(
                            data: login.qr!.url,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                        ),
                        const SizedBox(height: TdSpacer.small),
                        Text(_statusText(login), style: TdText.bodyMedium),
                        if (login.poll?.scanned == true)
                          Text('请在手机上确认登录', style: TdText.bodySmall),
                      ],
                    ),
                  ),
                const SizedBox(height: TdSpacer.medium),
                TDButton(
                  text: login.qr == null ? '生成登录二维码' : '刷新二维码',
                  theme: TDButtonTheme.primary,
                  size: TDButtonSize.medium,
                  isBlock: true,
                  disabled: login.loading,
                  onTap: () => context.read<LoginController>().startQrLogin(),
                ),
              ],
            ),
          ),
          const SizedBox(height: TdSpacer.small),
          TdSection(
            title: 'Cookie 登录',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '无法扫码时，可在浏览器登录 B 站后复制请求头里的 Cookie（需包含 SESSDATA）粘贴到下方。',
                  style: TdText.bodySmall,
                ),
                const SizedBox(height: TdSpacer.small),
                TDTextarea(
                  controller: _cookieController,
                  maxLines: 4,
                  minLines: 2,
                  hintText: 'SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx',
                  backgroundColor: TdPalette.gray1,
                ),
                const SizedBox(height: TdSpacer.small),
                TDButton(
                  text: '使用 Cookie 登录',
                  theme: TDButtonTheme.light,
                  size: TDButtonSize.medium,
                  isBlock: true,
                  disabled: login.loading,
                  onTap: () => _loginWithCookie(context),
                ),
              ],
            ),
          ),
          if (login.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
              child: Text(login.error!,
                  style: TdText.bodySmall.copyWith(color: TdPalette.error)),
            ),
        ],
      ),
    );
  }

  String _statusText(LoginController login) {
    final poll = login.poll;
    if (poll == null) return '等待扫码…';
    return switch (poll.code) {
      0 => '登录成功',
      86101 => '等待扫码…',
      86090 => '已扫码，请在手机上确认',
      86038 => '二维码已过期，请刷新',
      _ => poll.message,
    };
  }

  Widget _buildProfile(BuildContext context, LoginController login) {
    final info = login.navInfo;
    return TdSection(
      child: Row(
        children: <Widget>[
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: (info?.face.isEmpty ?? true)
                  ? Container(
                      color: TdPalette.gray2,
                      child: Icon(Icons.person, color: TdPalette.gray6))
                  : Image.network(info!.face, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: TdSpacer.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(info?.uname ?? '已登录', style: TdText.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'UID ${info?.mid ?? 0} · Lv${info?.level ?? 0}'
                  '${(info?.vipLabel.isNotEmpty ?? false) ? ' · ${info!.vipLabel}' : ''}',
                  style: TdText.bodySmall,
                ),
              ],
            ),
          ),
          TDButton(
            text: '退出登录',
            theme: TDButtonTheme.danger,
            type: TDButtonType.text,
            size: TDButtonSize.small,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithCookie(BuildContext context) async {
    final raw = _cookieController.text.trim();
    if (raw.isEmpty) {
      tdToast(context, '请先粘贴 Cookie');
      return;
    }
    final ok = await context.read<LoginController>().loginWithCookie(raw);
    if (!context.mounted) return;
    if (ok) {
      tdToastSuccess(context, '登录成功');
    } else {
      tdToastError(context, 'Cookie 无效或已过期');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await tdConfirm(
      context,
      title: '退出登录',
      content: '退出后将无法下载高清与会员内容。',
      confirmText: '退出',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<LoginController>().logout();
    if (context.mounted) tdToast(context, '已退出登录');
  }
}
