import 'dart:io';

import 'package:downkyi/data/download_task.dart';
import 'package:downkyi/download/download_archive.dart';
import 'package:downkyi/download/safe_replace.dart';
import 'package:flutter_test/flutter_test.dart';

/// v2.2.0 审查修复的测试：参数快照、归档时机、安全替换。
///
/// 这三块的共同点是**错了也不会抛异常**——快照丢了只是「行为跟着新设置走」、
/// 归档时机错了只是「再也下不了」、替换顺序错了只在 rename 失败时丢文件。
/// 只能靠测试把行为钉住。
void main() {
  group('DownloadTask 参数快照', () {
    DownloadTask sample() => DownloadTask(
          key: 'k',
          title: '标题',
          cid: 123,
          flags: 0,
          subtitleLanguages: 'zh-Hans+en-US',
          aiSubtitleStrategy: 'excludeAi',
          danmakuStyleJson: '{"fontScale":1.2,"opacity":0.8}',
          muxEngine: 'ffmpeg',
          embedMetadata: true,
          mergeAv: false,
          saveToGallery: true,
          engine: 'aria2',
          aria2Dir: '/downloads/bili',
          aria2GidsJson: '{"video":"g-v","audio":"g-a"}',
        );

    test('快照字段 toMap/fromMap 完整往返', () {
      final task = sample();
      final restored = DownloadTask.fromMap(task.toMap());
      expect(restored.subtitleLanguages, 'zh-Hans+en-US');
      expect(restored.aiSubtitleStrategy, 'excludeAi');
      expect(restored.danmakuStyleJson, '{"fontScale":1.2,"opacity":0.8}');
      expect(restored.muxEngine, 'ffmpeg');
      expect(restored.embedMetadata, isTrue);
      expect(restored.mergeAv, isFalse);
      expect(restored.saveToGallery, isTrue);
      expect(restored.engine, 'aria2');
      expect(restored.aria2Dir, '/downloads/bili');
      expect(restored.aria2GidsJson, '{"video":"g-v","audio":"g-a"}');
    });

    test('旧任务（缺列）回退为「无快照」而不是崩掉', () {
      // 模拟 v3 数据库读出来的 Map：没有 v4 的新列
      final task = DownloadTask.fromMap(<String, Object?>{
        'task_key': 'k',
        'title': '旧任务',
        'cid': 1,
        'flags': 0,
        'status': 'completed',
      });
      expect(task.subtitleLanguages, '');
      expect(task.aiSubtitleStrategy, '');
      expect(task.muxEngine, '');
      expect(task.embedMetadata, isNull);
      expect(task.mergeAv, isNull);
      expect(task.saveToGallery, isNull);
      expect(task.engine, '');
      expect(task.aria2Gids, isEmpty);
      expect(task.hasSnapshot, isFalse);
    });

    test('aria2Gids 映射的读写', () {
      final task = sample();
      expect(task.aria2Gids, <String, String>{'video': 'g-v', 'audio': 'g-a'});
      task.aria2Gids = const <String, String>{'direct': 'g-d'};
      expect(task.aria2GidsJson, '{"direct":"g-d"}');
      task.aria2Gids = const <String, String>{};
      expect(task.aria2GidsJson, '');
      expect(task.aria2Gids, isEmpty);
    });

    test('aria2GidsJson 损坏时按空处理', () {
      final task = DownloadTask(key: 'k', title: 't', cid: 1, flags: 0);
      task.aria2GidsJson = '不是 json';
      expect(task.aria2Gids, isEmpty);
      task.aria2GidsJson = '[1,2,3]';
      expect(task.aria2Gids, isEmpty);
    });

    test('snapshotSubtitleLanguages 拆分', () {
      final task = sample();
      expect(task.snapshotSubtitleLanguages, <String>['zh-Hans', 'en-US']);
      final old = DownloadTask(key: 'k', title: 't', cid: 1, flags: 0);
      expect(old.snapshotSubtitleLanguages, isEmpty);
    });
  });

  group('归档时机：只有真正成功才登记', () {
    test('合并成功的媒体任务：登记', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: true,
          usesAria2: false,
          merged: true,
          mergeAvEffective: true,
          hasError: false,
        ),
        isTrue,
      );
    });

    test('合并失败：不登记（否则把重下通道堵死）', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: true,
          usesAria2: false,
          merged: false,
          mergeAvEffective: true,
          hasError: true,
        ),
        isFalse,
      );
    });

    test('用户选择不合并且无错误：登记（主动选择的产物）', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: true,
          usesAria2: false,
          merged: false,
          mergeAvEffective: false,
          hasError: false,
        ),
        isTrue,
      );
    });

    test('纯附加资源任务：不构成「已经有了」', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: false,
          usesAria2: false,
          merged: true,
          mergeAvEffective: true,
          hasError: false,
        ),
        isFalse,
      );
    });

    test('aria2 远端完成：登记（失败路径不会走到这里）', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: true,
          usesAria2: true,
          merged: false,
          mergeAvEffective: true,
          hasError: false,
        ),
        isTrue,
      );
    });

    test('aria2 纯附加资源同样不登记', () {
      expect(
        isTaskSuccessForArchive(
          hasMedia: false,
          usesAria2: true,
          merged: false,
          mergeAvEffective: true,
          hasError: false,
        ),
        isFalse,
      );
    });
  });

  group('SafeReplace 安全文件替换', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('safe_replace_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('成功路径：临时文件到位，备份被清理', () async {
      final target = '${dir.path}/video.mp4';
      final temp = '${dir.path}/video.mp4.meta.mp4';
      await File(target).writeAsString('原始内容');
      await File(temp).writeAsString('注入后内容');

      await SafeReplace.replace(temp, target);

      expect(await File(target).readAsString(), '注入后内容');
      expect(File(temp).existsSync(), isFalse);
      expect(File('$target.bak').existsSync(), isFalse);
    });

    test('目标原本不存在：视为首次写入', () async {
      final target = '${dir.path}/new.mp4';
      final temp = '${dir.path}/new.mp4.meta.mp4';
      await File(temp).writeAsString('内容');

      await SafeReplace.replace(temp, target);

      expect(await File(target).readAsString(), '内容');
      expect(File('$target.bak').existsSync(), isFalse);
    });

    test('临时文件缺失：原文件回滚，内容不变', () async {
      final target = '${dir.path}/video.mp4';
      final temp = '${dir.path}/不存在.mp4';
      await File(target).writeAsString('原始内容');

      await expectLater(
        SafeReplace.replace(temp, target),
        throwsA(isA<FileSystemException>()),
      );
      // 回滚后原文件必须原样还在——这是旧顺序（先删后 rename）做不到的
      expect(await File(target).readAsString(), '原始内容');
      expect(File('$target.bak').existsSync(), isFalse);
    });

    test('任何时刻磁盘上至少有一份有效成品', () async {
      final target = '${dir.path}/video.mp4';
      final temp = '${dir.path}/video.mp4.meta.mp4';
      await File(target).writeAsString('原始内容');
      await File(temp).writeAsString('新内容');

      // 模拟「替换进行到一半」的视角：过程结束后要么是新内容、要么是旧内容，
      // 绝不允许两份都不在
      await SafeReplace.replace(temp, target);
      final exists =
          File(target).existsSync() || File('$target.bak').existsSync();
      expect(exists, isTrue);
      expect(await File(target).readAsString(), '新内容');
    });
  });
}
