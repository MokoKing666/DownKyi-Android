import 'dart:async';
import 'dart:io';

import 'package:downkyi/data/http_client.dart';
import 'package:downkyi/download/failure_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyFailure', () {
    test('需要登录：阶段=账号，建议引导登录', () {
      final info = classifyFailure(ApiException(-101, '账号未登录'));
      expect(info.stage, '账号');
      expect(info.hint, contains('登录'));
    });

    test('未获取到下载地址：阶段=解析，提示会员/付费/下架', () {
      final info =
          classifyFailure(ApiException(-1, '未获取到下载地址，可能是大会员 / 付费内容或已下架'));
      expect(info.stage, '解析');
      expect(info.hint, contains('会员'));
    });

    test('封装失败：阶段=封装', () {
      final info = classifyFailure(
          ApiException(-1, '封装失败，已保留原始文件，可在「工具」里重新合并或改用 FFmpeg 转换'));
      expect(info.stage, '封装');
    });

    test('仅 Wi-Fi 限制：阶段=网络', () {
      final info = classifyFailure(Exception('已开启「仅 Wi-Fi 下载」，当前不是 Wi-Fi 网络'));
      expect(info.stage, '网络');
    });

    test('Aria2 连接失败：阶段=Aria2', () {
      final info = classifyFailure(Exception('无法连接 Aria2，恢复连接后点「继续」自动接管'));
      expect(info.stage, 'Aria2');
    });

    test('磁盘写入失败：阶段=写入', () {
      final info = classifyFailure(const FileSystemException(
          'write failed', '/data/x', OSError('No space left on device')));
      expect(info.stage, '写入');
      expect(info.hint, contains('存储'));
    });

    test('网络类异常：阶段=下载，建议重试', () {
      final info = classifyFailure(const SocketException('连接被重置'));
      expect(info.stage, '下载');
      expect(info.hint, contains('重试'));
    });

    test('超时/停滞：阶段=下载', () {
      final info =
          classifyFailure(ApiException(-3, '分片 0 下载停滞（30000 毫秒无数据），已断开重连'));
      expect(info.stage, '下载');
    });

    test('未知异常兜底：阶段=下载，不抛出', () {
      final info = classifyFailure(StateError('未知错误'));
      expect(info.stage, '下载');
      expect(info.hint, isNotEmpty);
    });
  });

  group('extrasFailureTag', () {
    test('需要登录', () {
      expect(extrasFailureTag(ApiException(-101, '未登录')), '需登录');
    });

    test('文件系统异常 → 写入', () {
      expect(
          extrasFailureTag(const FileSystemException(
              'no space', '/x', OSError('No space left on device'))),
          '写入');
    });

    test('Socket 异常 → 网络', () {
      expect(extrasFailureTag(const SocketException('reset')), '网络');
    });

    test('超时 → 网络', () {
      expect(extrasFailureTag(TimeoutException('t')), '网络');
    });

    test('未知 → 失败', () {
      expect(extrasFailureTag(StateError('x')), '失败');
    });
  });
}
