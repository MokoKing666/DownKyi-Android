import 'package:downkyi/core/formatter.dart';
import 'package:downkyi/download/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// 文件名测试。
///
/// 文件名出问题的后果不是报错，而是**静默写失败或互相覆盖**：
/// 含 `/` 会被当成目录分隔符、结尾的 `.` 在 Windows/部分 ROM 上会被吞掉、
/// 超长会直接 IO 异常。批量下载同名标题则会两三个任务写进同一个文件。
void main() {
  group('sanitizeFileName 非法字符', () {
    test('逐个替换路径分隔符与通配符', () {
      final result = sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j');
      for (final ch in <String>[
        r'/',
        r'\',
        ':',
        '*',
        '?',
        '"',
        '<',
        '>',
        '|'
      ]) {
        expect(result.contains(ch), isFalse, reason: '仍包含 $ch');
      }
    });

    test('换行与制表替换为空格并压缩', () {
      expect(sanitizeFileName('a\nb\tc\rd'), 'a b c d');
    });

    test('连续空白压缩成一个空格', () {
      expect(sanitizeFileName('a     b'), 'a b');
    });

    test('去掉首尾空白', () {
      expect(sanitizeFileName('   标题   '), '标题');
    });

    test('去掉结尾的点和空格（Windows/Android 会吞掉）', () {
      expect(sanitizeFileName('name...   '), 'name');
      expect(sanitizeFileName('name.'), 'name');
    });
  });

  group('sanitizeFileName 边界', () {
    test('空标题回退为 video', () {
      expect(sanitizeFileName(''), 'video');
      expect(sanitizeFileName('   '), 'video');
    });

    test('全部是非法的字符也会回退', () {
      expect(sanitizeFileName('///'), 'video');
      expect(sanitizeFileName('***'), 'video');
    });

    test('超长标题按 maxLength 截断', () {
      final result = sanitizeFileName('a' * 200);
      expect(result.length, 80);
      expect(sanitizeFileName('a' * 200, maxLength: 10).length, 10);
    });

    test('刚好等于上限时不截断', () {
      expect(sanitizeFileName('a' * 80).length, 80);
    });

    test('保留 Emoji', () {
      expect(sanitizeFileName('标题🎬🔥'), '标题🎬🔥');
    });

    test('保留中日韩与全角符号', () {
      expect(sanitizeFileName('日本語のタイトル · 中文'), '日本語のタイトル · 中文');
    });
  });

  group('sanitizeFileName 安全性质', () {
    test('任何输入都不会残留路径分隔符', () {
      const nasty = <String>[
        '../../etc/passwd',
        r'..\..\windows\system32',
        '/sdcard/Download/x',
        r'C:\Users\x\file',
        '....//....//x',
        'a\u0000b',
        '名字/带斜杠/还有\\反斜杠',
      ];
      for (final input in nasty) {
        final result = sanitizeFileName(input);
        expect(result.contains('/'), isFalse, reason: '输入: $input -> $result');
        expect(result.contains(r'\'), isFalse, reason: '输入: $input -> $result');
        expect(result, isNotEmpty);
      }
    });

    test('结果不会是纯点号（避免被当成上级目录）', () {
      expect(sanitizeFileName('..'), 'video');
      expect(sanitizeFileName('...'), 'video');
    });
  });

  group('dedupeFileName', () {
    test('没有冲突时原样返回', () {
      expect(dedupeFileName('我的视频', <String>{}), '我的视频');
      expect(dedupeFileName('我的视频', <String>{'别的视频'}), '我的视频');
    });

    test('冲突时追加 (1)', () {
      expect(dedupeFileName('我的视频', <String>{'我的视频'}), '我的视频 (1)');
    });

    test('连续冲突时递增序号', () {
      final taken = <String>{'我的视频', '我的视频 (1)', '我的视频 (2)'};
      expect(dedupeFileName('我的视频', taken), '我的视频 (3)');
    });

    test('跳过已被占用的中间序号', () {
      final taken = <String>{'我的视频', '我的视频 (2)'};
      expect(dedupeFileName('我的视频', taken), '我的视频 (1)');
    });

    test('批量同名标题会得到互不相同的名字', () {
      // 模拟批量下载 5 个同名视频
      final taken = <String>{};
      final produced = <String>[];
      for (var i = 0; i < 5; i++) {
        final name = dedupeFileName('我的视频', taken);
        produced.add(name);
        taken.add(name);
      }
      expect(produced.toSet().length, 5);
      expect(produced.first, '我的视频');
      expect(produced.last, '我的视频 (4)');
    });
  });
}
