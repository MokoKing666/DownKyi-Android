import 'package:sqflite/sqflite.dart';

import '../core/logger.dart';
import 'download_task.dart';

/// 任务持久化：断点续传所需的分片进度也保存在这里。
class TaskDao {
  TaskDao._internal();

  static final TaskDao instance = TaskDao._internal();

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final path = '${await getDatabasesPath()}/downkyi.db';
    final database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE download_task(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_key TEXT NOT NULL,
            title TEXT,
            sub_title TEXT,
            cover TEXT,
            owner TEXT,
            bvid TEXT,
            cid INTEGER,
            ep_id INTEGER,
            btype TEXT,
            duration_ms INTEGER,
            quality INTEGER,
            quality_name TEXT,
            audio_id INTEGER,
            codec TEXT,
            flags INTEGER,
            danmaku_format TEXT,
            status TEXT,
            total_bytes INTEGER,
            downloaded_bytes INTEGER,
            video_path TEXT,
            audio_path TEXT,
            output_path TEXT,
            error TEXT,
            video_segments TEXT,
            audio_segments TEXT,
            file_name TEXT,
            created_at INTEGER,
            finished_at INTEGER,
            merged INTEGER,
            aria2_gid TEXT,
            exported INTEGER,
            exported_path TEXT,
            extras_error TEXT,
            subtitle_languages TEXT,
            ai_subtitle_strategy TEXT,
            danmaku_style_json TEXT,
            mux_engine TEXT,
            embed_metadata INTEGER,
            merge_av INTEGER,
            save_to_gallery INTEGER,
            engine TEXT,
            aria2_dir TEXT,
            aria2_gids TEXT
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX idx_task_key ON download_task(task_key)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLog.d('DB', '数据库升级 $oldVersion -> $newVersion');
        // v2：Aria2 引擎任务 id + 相册导出状态
        if (oldVersion < 2) {
          await db
              .execute('ALTER TABLE download_task ADD COLUMN aria2_gid TEXT');
          await db
              .execute('ALTER TABLE download_task ADD COLUMN exported INTEGER');
          await db.execute(
              'ALTER TABLE download_task ADD COLUMN exported_path TEXT');
        }
        // v3：附加资源（封面 / 弹幕 / 字幕）的失败项
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE download_task ADD COLUMN extras_error TEXT');
        }
        // v4：任务参数快照 + aria2 多 gid。
        // 旧任务这些列为 NULL / 空串，执行时回退到全局设置，与旧行为一致。
        if (oldVersion < 4) {
          const newColumns = <String>[
            'subtitle_languages TEXT',
            'ai_subtitle_strategy TEXT',
            'danmaku_style_json TEXT',
            'mux_engine TEXT',
            'embed_metadata INTEGER',
            'merge_av INTEGER',
            'save_to_gallery INTEGER',
            'engine TEXT',
            'aria2_dir TEXT',
            'aria2_gids TEXT',
          ];
          for (final column in newColumns) {
            await db.execute('ALTER TABLE download_task ADD COLUMN $column');
          }
        }
      },
    );
    _database = database;
    return database;
  }

  Future<List<DownloadTask>> loadAll() async {
    try {
      final db = await _db;
      final rows = await db.query('download_task', orderBy: 'id ASC');
      return rows.map(DownloadTask.fromMap).toList();
    } catch (error) {
      AppLog.e('DB', '读取任务失败', error);
      return <DownloadTask>[];
    }
  }

  Future<void> insert(DownloadTask task) async {
    try {
      final db = await _db;
      final id = await db.insert(
        'download_task',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      task.id = id;
    } catch (error) {
      AppLog.e('DB', '写入任务失败', error);
    }
  }

  Future<void> update(DownloadTask task) async {
    if (task.id == 0) {
      await insert(task);
      return;
    }
    try {
      final db = await _db;
      await db.update(
        'download_task',
        task.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[task.id],
      );
    } catch (error) {
      AppLog.e('DB', '更新任务失败', error);
    }
  }

  Future<void> delete(int id) async {
    try {
      final db = await _db;
      await db
          .delete('download_task', where: 'id = ?', whereArgs: <Object?>[id]);
    } catch (error) {
      AppLog.e('DB', '删除任务失败', error);
    }
  }

  Future<void> deleteByStatus(TaskStatus status) async {
    try {
      final db = await _db;
      await db.delete('download_task',
          where: 'status = ?', whereArgs: <Object?>[status.name]);
    } catch (error) {
      AppLog.e('DB', '批量删除任务失败', error);
    }
  }

  Future<bool> exists(String key) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'download_task',
        columns: <String>['id'],
        where: 'task_key = ?',
        whereArgs: <Object?>[key],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (error) {
      return false;
    }
  }
}
