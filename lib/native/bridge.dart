import 'package:flutter/services.dart';

import '../core/logger.dart';

/// 原生能力桥接：合并 / 通知栏服务 / 文件操作。
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.moko.downkyi/native');

  /// MediaMuxer 重新封装：video / audio 允许只传其中一个（传 null 表示该轨不存在）
  static Future<bool> mux({
    String? video,
    String? audio,
    required String output,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('mux', <String, dynamic>{
        'video': video,
        'audio': audio,
        'output': output,
      });
      return result ?? false;
    } catch (error) {
      AppLog.e('Native', '合并失败', error);
      return false;
    }
  }

  static Future<bool> openFile(String path, {String mime = 'video/mp4'}) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('openFile', <String, dynamic>{
        'path': path,
        'mime': mime,
      });
      return result ?? false;
    } catch (error) {
      AppLog.e('Native', '打开文件失败', error);
      return false;
    }
  }

  /// 导出到系统公共目录，返回公共路径或 content uri
  ///
  /// [category] 显式指定目标目录，不再靠 MIME 推断：
  /// - `video` → `Movies/<album>`
  /// - `image` → `Pictures/<album>`
  /// - `file`（默认，含封面/弹幕/字幕）→ `Download/<album>`
  static Future<String?> exportToPublic({
    required String path,
    required String name,
    String mime = 'video/mp4',
    String album = 'DownKyi',
    String category = 'file',
  }) async {
    try {
      return await _channel
          .invokeMethod<String>('exportToPublic', <String, dynamic>{
        'path': path,
        'name': name,
        'mime': mime,
        'album': album,
        'category': category,
      });
    } catch (error) {
      AppLog.e('Native', '导出失败', error);
      return null;
    }
  }

  /// 删除本地文件或 MediaStore 条目（兼容 content:// ）
  static Future<bool> deletePath(String path) async {
    try {
      final result = await _channel
          .invokeMethod<bool>('deletePath', <String, dynamic>{'path': path});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统文件选择器（SAF），返回所选文件的 content uri；取消返回 null
  static Future<String?> pickFile() async {
    try {
      return await _channel.invokeMethod<String>('pickFile');
    } catch (error) {
      AppLog.e('Native', '选择文件失败', error);
      return null;
    }
  }

  /// 把文件或 content uri 复制为真实文件，返回可用的本地路径。
  ///
  /// FFmpeg 只能读真实文件，因此处理相册里的文件前先「落地」到工作目录。
  static Future<String?> materialize({
    required String path,
    required String dest,
  }) async {
    if (!path.startsWith('content://')) return path;
    try {
      final ok =
          await _channel.invokeMethod<bool>('copyToFile', <String, dynamic>{
        'path': path,
        'dest': dest,
      });
      return (ok ?? false) ? dest : null;
    } catch (error) {
      AppLog.e('Native', '复制相册文件失败', error);
      return null;
    }
  }

  static Future<int> fileSize(String path) async {
    try {
      final result = await _channel
          .invokeMethod<int>('fileSize', <String, dynamic>{'path': path});
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> deleteFile(String path) async {
    try {
      final result = await _channel
          .invokeMethod<bool>('deleteFile', <String, dynamic>{'path': path});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> renameFile(
      {required String from, required String to}) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('renameFile', <String, dynamic>{
        'from': from,
        'to': to,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> externalFilesDir([String sub = '']) async {
    try {
      return await _channel.invokeMethod<String>(
          'externalFilesDir', <String, dynamic>{'sub': sub});
    } catch (_) {
      return null;
    }
  }

  static Future<void> startService({
    required String title,
    required String text,
    int progress = -1,
  }) async {
    try {
      await _channel.invokeMethod<bool>('startService', <String, dynamic>{
        'title': title,
        'text': text,
        'progress': progress,
      });
    } catch (error) {
      AppLog.e('Native', '启动前台服务失败', error);
    }
  }

  static Future<void> updateService({
    required String title,
    required String text,
    int progress = -1,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateService', <String, dynamic>{
        'title': title,
        'text': text,
        'progress': progress,
      });
    } catch (_) {
      // 服务未运行，忽略
    }
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod<bool>('stopService');
    } catch (_) {
      // 忽略
    }
  }

  /// 是否处于 Wi-Fi / 以太网
  static Future<bool> isWifi() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWifi');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod<bool>('requestNotificationPermission');
    } catch (_) {
      // 忽略
    }
  }

  static Future<String?> sharedText() async {
    try {
      return await _channel.invokeMethod<String>('sharedText');
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 敏感数据加密存储（AndroidKeyStore + AES/GCM，实现见 SecureStore.kt）
  //
  // 这些方法失败时**不抛异常**，由 lib/core/secret_store.dart 决定回退策略：
  // 宁可暂时不够安全，也不能因为加密存储不可用就把用户的登录状态弄丢。
  // ---------------------------------------------------------------------------

  static Future<bool> secureWrite(String key, String value) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          'secureWrite', <String, dynamic>{'key': key, 'value': value});
      return ok ?? false;
    } catch (error) {
      AppLog.e('Native', '写入加密存储失败：$key', error);
      return false;
    }
  }

  static Future<String?> secureRead(String key) async {
    try {
      return await _channel
          .invokeMethod<String>('secureRead', <String, dynamic>{'key': key});
    } catch (error) {
      AppLog.e('Native', '读取加密存储失败：$key', error);
      return null;
    }
  }

  static Future<void> secureDelete(String key) async {
    try {
      await _channel
          .invokeMethod<void>('secureDelete', <String, dynamic>{'key': key});
    } catch (error) {
      AppLog.e('Native', '删除加密存储失败：$key', error);
    }
  }

  static Future<void> secureClear() async {
    try {
      await _channel.invokeMethod<void>('secureClear');
    } catch (error) {
      AppLog.e('Native', '清空加密存储失败', error);
    }
  }

  /// 硬件解码能力探测（供选档时给建议，见 DecoderCapabilities.kt）。
  /// 失败返回 null，调用方按「未知」处理，不影响任何下载功能。
  static Future<Map<Object?, Object?>?> decoderCapabilities() async {
    try {
      return await _channel
          .invokeMethod<Map<Object?, Object?>>('decoderCapabilities');
    } catch (error) {
      AppLog.e('Native', '读取解码能力失败', error);
      return null;
    }
  }
}
