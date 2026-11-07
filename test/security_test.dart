import 'package:downkyi/core/logger.dart';
import 'package:downkyi/core/secret_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 敏感数据处理的测试。
///
/// 这一块的特殊之处在于**出错时不会有任何报错**：
/// 日志里多打一行 Cookie、或者迁移时把登录态弄丢，都不会抛异常，
/// 只会在用户那边表现为「莫名其妙掉登录」或者「贴到 issue 里的日志泄露了账号」。
/// 所以只能用测试把行为钉住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.moko.downkyi/native');

  group('AppLog.redact 日志脱敏', () {
    test('Cookie 的值只保留前 4 位', () {
      final out =
          AppLog.redact('Cookie: SESSDATA=abcdef1234567890; bili_jct=xyz789');
      expect(out.contains('abcdef1234567890'), isFalse);
      expect(out.contains('xyz789'), isFalse);
      expect(out.contains('abcd****'), isTrue);
    });

    test('键值对形式同样脱敏', () {
      final out = AppLog.redact('SESSDATA=abcdef1234');
      expect(out, 'SESSDATA=abcd****');
    });

    test('JSON 形式同样脱敏', () {
      final out = AppLog.redact('{"SESSDATA":"abcdef1234"}');
      expect(out.contains('abcdef1234'), isFalse);
      expect(out.contains('abcd****'), isTrue);
    });

    test('aria2 密钥与 token 也在名单里', () {
      expect(AppLog.redact('aria2Secret=supersecret').contains('supersecret'),
          isFalse);
      expect(AppLog.redact('--rpc-secret=supersecret').contains('supersecret'),
          isFalse);
      expect(
          AppLog.redact('access_token=abcdefgh').contains('abcdefgh'), isFalse);
    });

    test('大小写不敏感', () {
      expect(
          AppLog.redact('sessdata=abcdef1234').contains('abcdef1234'), isFalse);
    });

    test('不误伤普通内容', () {
      const plain = 'GET https://api.bilibili.com/x/web-interface/nav -> 200';
      expect(AppLog.redact(plain), plain);
    });

    test('值太短时不处理（避免把整行吃掉）', () {
      // 少于 4 个字符的值没有脱敏意义，正则也不该匹配
      expect(AppLog.redact('SESSDATA=abc'), 'SESSDATA=abc');
    });

    test('日志入队时已经脱敏', () {
      AppLog.clear();
      AppLog.d('Test', 'SESSDATA=abcdef1234567890');
      expect(AppLog.lines.any((line) => line.contains('abcdef1234567890')),
          isFalse);
      expect(AppLog.lines.any((line) => line.contains('abcd****')), isTrue);
    });
  });

  group('SecretStore', () {
    late Map<String, String> storage;
    late List<MethodCall> calls;
    bool failChannel = false;

    setUp(() {
      storage = <String, String>{};
      calls = <MethodCall>[];
      failChannel = false;
      SecretStore.resetForTest();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (failChannel) throw PlatformException(code: 'unavailable');
        final args =
            (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        switch (call.method) {
          case 'secureWrite':
            storage[args['key'] as String] = args['value'] as String;
            return true;
          case 'secureRead':
            return storage[args['key'] as String] ?? '';
          case 'secureDelete':
            storage.remove(args['key'] as String);
            return true;
          case 'secureClear':
            storage.clear();
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('写入后能从加密存储读回', () async {
      await SecretStore.write(SecretStore.keyCookie, 'SESSDATA=abc');
      expect(storage[SecretStore.keyCookie], 'SESSDATA=abc');

      SecretStore.resetForTest();
      expect(await SecretStore.read(SecretStore.keyCookie), 'SESSDATA=abc');
    });

    test('旧版明文会被迁移进加密存储', () async {
      // 场景：用户从明文版本升级上来，SharedPreferences 里还留着 cookie
      final value = await SecretStore.read(
        SecretStore.keyCookie,
        legacy: 'SESSDATA=legacy123',
      );

      expect(value, 'SESSDATA=legacy123');
      expect(storage[SecretStore.keyCookie], 'SESSDATA=legacy123',
          reason: '迁移后必须已经写进加密存储');
      expect(calls.any((c) => c.method == 'secureWrite'), isTrue);
    });

    test('加密存储已有值时不会被明文覆盖', () async {
      storage[SecretStore.keyCookie] = 'SESSDATA=fresh';

      final value = await SecretStore.read(
        SecretStore.keyCookie,
        legacy: 'SESSDATA=stale',
      );

      expect(value, 'SESSDATA=fresh');
      expect(storage[SecretStore.keyCookie], 'SESSDATA=fresh');
    });

    test('明文也为空时不写任何东西', () async {
      final value = await SecretStore.read(SecretStore.keyCookie);
      expect(value, '');
      expect(calls.any((c) => c.method == 'secureWrite'), isFalse);
    });

    test('平台通道异常时降级，但仍返回明文（不能弄丢登录态）', () async {
      failChannel = true;

      final value = await SecretStore.read(
        SecretStore.keyCookie,
        legacy: 'SESSDATA=fallback',
      );

      expect(value, 'SESSDATA=fallback');
      expect(SecretStore.available, isFalse, reason: '失败后应停止重试');
    });

    test('降级后写入不再打通道，只留内存态', () async {
      failChannel = true;
      await SecretStore.read(SecretStore.keyCookie, legacy: 'x');
      final before = calls.length;

      await SecretStore.write(SecretStore.keyCookie, 'SESSDATA=new');
      expect(calls.length, before, reason: '已降级就不该再打通道');
      expect(await SecretStore.read(SecretStore.keyCookie), 'SESSDATA=new');
    });

    test('clear 会清空加密存储与内存缓存', () async {
      await SecretStore.write(SecretStore.keyCookie, 'SESSDATA=abc');
      await SecretStore.clear();

      expect(storage, isEmpty);
      expect(await SecretStore.read(SecretStore.keyCookie), '');
    });

    test('delete 只删指定键', () async {
      await SecretStore.write(SecretStore.keyCookie, 'a');
      await SecretStore.write(SecretStore.keyAria2Secret, 'b');
      await SecretStore.delete(SecretStore.keyCookie);

      expect(storage.containsKey(SecretStore.keyCookie), isFalse);
      expect(storage[SecretStore.keyAria2Secret], 'b');
    });
  });
}
