import 'package:flutter/foundation.dart';

import '../native/bridge.dart';
import 'logger.dart';

/// 敏感数据（Cookie / Token / aria2 密钥）的加密存储门面。
///
/// 底层是 Android 的 AndroidKeyStore（见 `SecureStore.kt`）。这里额外负责两件事：
///
/// **1. 从旧版明文迁移。**
/// 历史版本把 Cookie 与 aria2 密钥明文写在 SharedPreferences 里，升级后不能直接丢掉——
/// 那会让所有已登录用户莫名其妙掉登录。所以 [read] 接受一个 [legacy] 明文兜底值，
/// 读到就立刻加密回写，由调用方负责删掉明文残留。
///
/// **2. 失败降级。**
/// 加密存储在某些设备上可能不可用（keystore 异常、定制 ROM、平台通道问题）。
/// 这时绝不能把登录状态弄丢，因此失败后退化为「内存缓存」并记录日志，
/// 调用方可以把明文写回 SharedPreferences 作为兜底。
/// 安全性与可用性之间，这里明确选择可用性。
class SecretStore {
  SecretStore._();

  /// 与 `SettingsStore` 里的旧明文 key 同名，迁移时一一对应
  static const String keyCookie = 'cookie_header';
  static const String keyAria2Secret = 'aria2_rpc_secret';

  static const List<String> allKeys = <String>[keyCookie, keyAria2Secret];

  /// 加密存储是否可用。一旦失败就不再反复重试，避免每次保存都卡一下。
  static bool _available = true;

  static bool get available => _available;

  static final Map<String, String> _cache = <String, String>{};

  /// 读取。命中缓存直接返回；否则读加密存储；仍为空且给了 [legacy] 时，
  /// 视为「从旧版本升级」，把明文加密回写。
  static Future<String> read(String key, {String legacy = ''}) async {
    final cached = _cache[key];
    if (cached != null) return cached;

    var value = '';
    if (_available) {
      final stored = await NativeBridge.secureRead(key);
      if (stored == null) {
        _available = false;
        AppLog.e('Secure', '加密存储不可用，$key 退化为内存态');
      } else {
        value = stored;
      }
    }

    if (value.isEmpty && legacy.isNotEmpty) {
      value = legacy;
      await write(key, value);
      AppLog.d('Secure', '已把 $key 从明文迁移到加密存储');
    }
    _cache[key] = value;
    return value;
  }

  static Future<void> write(String key, String value) async {
    _cache[key] = value;
    if (!_available) return;
    if (!await NativeBridge.secureWrite(key, value)) {
      _available = false;
      AppLog.e('Secure', '写入加密存储失败，$key 退化为内存态');
    }
  }

  static Future<void> delete(String key) async {
    _cache.remove(key);
    if (_available) await NativeBridge.secureDelete(key);
  }

  /// 退出登录：清空全部敏感数据
  static Future<void> clear() async {
    _cache.clear();
    if (_available) await NativeBridge.secureClear();
  }

  /// 仅供测试：重置内部状态
  @visibleForTesting
  static void resetForTest({bool available = true}) {
    _available = available;
    _cache.clear();
  }
}
