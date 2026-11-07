import 'dart:async';
import 'dart:io';

import '../data/http_client.dart';

/// 任务失败的结构化信息：失败阶段 + 给用户的处置建议。
///
/// 对应桌面版「下载失败可展开查看原因」：过去任务只存一句自由文本，
/// 「解析失败」和「磁盘写不下」长得差不多，用户不知道该登录还是该清存储。
class FailureInfo {
  const FailureInfo(this.stage, this.hint);

  /// 失败阶段：账号 / 解析 / 下载 / 封装 / 写入 / 网络 / Aria2
  final String stage;

  /// 下一步建议（给用户看的操作指引）
  final String hint;
}

/// 把异常归类成「哪个阶段失败、用户下一步该做什么」。
FailureInfo classifyFailure(Object error) {
  final message = error is ApiException ? error.message : '$error';

  if (error is ApiException && error.needLogin ||
      message.contains('未登录') ||
      message.contains('登录已失效')) {
    return const FailureInfo('账号', '登录已失效或未登录，请在「我的」页登录后重试');
  }
  if (message.contains('封装')) {
    return const FailureInfo('封装', '设备不支持该编码的封装，可在「工具」页重新合并或改用 FFmpeg 转换');
  }
  if (message.contains('未获取到') || message.contains('下载地址')) {
    return const FailureInfo('解析', '可能是会员 / 付费内容或已下架，请确认账号权限后重试');
  }
  if (message.contains('仅 Wi-Fi')) {
    return const FailureInfo('网络', '连接 Wi-Fi 后点「继续」，或在设置里关闭「仅 Wi-Fi 下载」');
  }
  if (message.contains('Aria2') || message.contains('aria2')) {
    return const FailureInfo('Aria2', '请确认 aria2 已启动并可访问，恢复连接后点「继续」自动接管');
  }
  if (error is FileSystemException ||
      error is PathAccessException ||
      message.contains('空间不足') ||
      message.contains('No space')) {
    return const FailureInfo('写入', '存储空间不足或无写入权限，请清理存储后重试');
  }
  if (error is TimeoutException ||
      error is SocketException ||
      message.contains('网络') ||
      message.contains('停滞')) {
    return const FailureInfo('下载', '网络不稳定，可稍后点「继续」或「重试」');
  }
  return const FailureInfo('下载', '可点「重试」再试一次；若一直失败，请在设置页查看运行日志');
}

/// 附加资源（封面 / 弹幕 / 字幕）失败时的简短原因标签。
///
/// 用于「已完成，但 字幕（需登录）、封面（网络）未成功」这类提示，
/// 让用户一眼分辨是重新登录、换网络还是清存储。
String extrasFailureTag(Object error) {
  if (error is ApiException &&
      (error.needLogin || error.message.contains('未登录'))) {
    return '需登录';
  }
  if (error is FileSystemException || error is PathAccessException) {
    return '写入';
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return '网络';
  }
  final message = '$error';
  if (message.contains('网络') ||
      message.contains('SocketException') ||
      message.contains('Timeout')) {
    return '网络';
  }
  if (message.contains('No space') || message.contains('空间')) {
    return '写入';
  }
  return '失败';
}
