import 'package:sqflite/sqflite.dart';

import '../core/logger.dart';
import 'subscription.dart';

/// 订阅持久化。
///
/// 刻意与 `downkyi.db`（下载任务）分成两个库文件：两张表与任务表之间没有关联查询，
/// 合在一起只会让版本号互相牵制——以后任一方加字段都要为对方考虑迁移顺序。
class SubscriptionDao {
  SubscriptionDao._internal();

  static final SubscriptionDao instance = SubscriptionDao._internal();

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final path = '${await getDatabasesPath()}/downkyi_subscription.db';
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE subscription(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            source_id TEXT NOT NULL,
            title TEXT,
            cover TEXT,
            last_checked_at INTEGER,
            last_bvid TEXT,
            enabled INTEGER DEFAULT 1,
            auto_download INTEGER DEFAULT 0,
            quality INTEGER DEFAULT 80,
            codec TEXT DEFAULT 'avc',
            want_video INTEGER DEFAULT 1,
            want_audio INTEGER DEFAULT 1,
            want_cover INTEGER DEFAULT 0,
            want_danmaku INTEGER DEFAULT 1,
            want_subtitle INTEGER DEFAULT 0,
            UNIQUE(kind, source_id)
          )
        ''');
        // ep_id 用 NOT NULL DEFAULT 0 而不是 NULL：
        // SQLite 的联合主键里 NULL 彼此不相等，用 NULL 会让同一条番剧记录被反复插入。
        await db.execute('''
          CREATE TABLE subscription_seen(
            subscription_id INTEGER NOT NULL,
            bvid TEXT NOT NULL,
            ep_id INTEGER NOT NULL DEFAULT 0,
            title TEXT,
            cover TEXT,
            duration_ms INTEGER,
            cid INTEGER,
            discovered_at INTEGER,
            downloaded INTEGER DEFAULT 0,
            PRIMARY KEY(subscription_id, bvid, ep_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_seen_pending ON subscription_seen(subscription_id, downloaded)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLog.d('DB', '订阅库升级 $oldVersion -> $newVersion');
      },
    );
    _database = database;
    return database;
  }

  // ------------------------------------------------------------------
  // 订阅
  // ------------------------------------------------------------------

  Future<List<Subscription>> loadAll() async {
    try {
      final db = await _db;
      final rows = await db.query('subscription', orderBy: 'id ASC');
      return rows.map(Subscription.fromMap).toList();
    } catch (error) {
      AppLog.e('DB', '读取订阅失败', error);
      return <Subscription>[];
    }
  }

  Future<Subscription?> findBySource(
      SubscriptionKind kind, String sourceId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'subscription',
        where: 'kind = ? AND source_id = ?',
        whereArgs: <Object?>[kind.name, sourceId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Subscription.fromMap(rows.first);
    } catch (error) {
      AppLog.e('DB', '查找订阅失败', error);
      return null;
    }
  }

  /// 新增订阅并返回带 id 的实例；若同 kind + sourceId 已存在则返回已存在的那条
  Future<Subscription> insert(Subscription subscription) async {
    final existing =
        await findBySource(subscription.kind, subscription.sourceId);
    if (existing != null) return existing;
    try {
      final db = await _db;
      final id = await db.insert('subscription', subscription.toMap());
      subscription.id = id;
    } catch (error) {
      AppLog.e('DB', '写入订阅失败', error);
    }
    return subscription;
  }

  Future<void> update(Subscription subscription) async {
    if (subscription.id == 0) {
      await insert(subscription);
      return;
    }
    try {
      final db = await _db;
      await db.update(
        'subscription',
        subscription.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[subscription.id],
      );
    } catch (error) {
      AppLog.e('DB', '更新订阅失败', error);
    }
  }

  /// 删除订阅及其全部已发现记录
  Future<void> delete(int id) async {
    try {
      final db = await _db;
      await db
          .delete('subscription', where: 'id = ?', whereArgs: <Object?>[id]);
      await db.delete(
        'subscription_seen',
        where: 'subscription_id = ?',
        whereArgs: <Object?>[id],
      );
    } catch (error) {
      AppLog.e('DB', '删除订阅失败', error);
    }
  }

  // ------------------------------------------------------------------
  // 已发现内容
  // ------------------------------------------------------------------

  /// 批量写入（已存在的键自动忽略）
  Future<int> insertSeen(List<SeenItem> items) async {
    if (items.isEmpty) return 0;
    try {
      final db = await _db;
      var inserted = 0;
      final batch = db.batch();
      for (final item in items) {
        batch.insert(
          'subscription_seen',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      final results = await batch.commit(noResult: false);
      for (final result in results) {
        if (result is int && result > 0) inserted++;
      }
      return inserted;
    } catch (error) {
      AppLog.e('DB', '写入已发现内容失败', error);
      return 0;
    }
  }

  /// 判重用的键集合，形如 `bvid|epId`
  Future<Set<String>> seenKeys(int subscriptionId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'subscription_seen',
        columns: <String>['bvid', 'ep_id'],
        where: 'subscription_id = ?',
        whereArgs: <Object?>[subscriptionId],
      );
      return rows
          .map((row) => '${row['bvid']}|${(row['ep_id'] as int?) ?? 0}')
          .toSet();
    } catch (error) {
      AppLog.e('DB', '读取已发现键失败', error);
      return <String>{};
    }
  }

  Future<int> seenCount(int subscriptionId) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM subscription_seen WHERE subscription_id = ?',
        <Object?>[subscriptionId],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (error) {
      return 0;
    }
  }

  /// 未处理（未下载）的新内容数量，用于列表角标
  Future<int> pendingCount(int subscriptionId) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM subscription_seen '
        'WHERE subscription_id = ? AND downloaded = 0',
        <Object?>[subscriptionId],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (error) {
      return 0;
    }
  }

  /// 未处理的新内容，按发现时间正序（旧的在前，便于按集数顺序下载）
  Future<List<SeenItem>> pendingItems(int subscriptionId,
      {int limit = 200}) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'subscription_seen',
        where: 'subscription_id = ? AND downloaded = 0',
        whereArgs: <Object?>[subscriptionId],
        orderBy: 'discovered_at ASC',
        limit: limit,
      );
      return rows.map(SeenItem.fromMap).toList();
    } catch (error) {
      AppLog.e('DB', '读取未处理内容失败', error);
      return <SeenItem>[];
    }
  }

  /// 标记为已处理（下载或手动忽略）
  Future<void> markDownloaded(int subscriptionId, Iterable<String> keys) async {
    if (keys.isEmpty) return;
    try {
      final db = await _db;
      for (final key in keys) {
        final parts = key.split('|');
        final bvid = parts.isNotEmpty ? parts.first : '';
        final epId = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        await db.update(
          'subscription_seen',
          <String, Object?>{'downloaded': 1},
          where: 'subscription_id = ? AND bvid = ? AND ep_id = ?',
          whereArgs: <Object?>[subscriptionId, bvid, epId],
        );
      }
    } catch (error) {
      AppLog.e('DB', '标记已处理失败', error);
    }
  }

  /// 清空某订阅的已发现记录（下次检查会重新播种，不会误报新内容）
  Future<void> clearSeen(int subscriptionId) async {
    try {
      final db = await _db;
      await db.delete(
        'subscription_seen',
        where: 'subscription_id = ?',
        whereArgs: <Object?>[subscriptionId],
      );
    } catch (error) {
      AppLog.e('DB', '清空已发现记录失败', error);
    }
  }
}
