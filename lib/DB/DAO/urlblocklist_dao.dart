import 'package:sqflite/sqflite.dart';
import '../CORE/local_db_service.dart';
import '../models/schema_manager.dart';
import '../../utils/logger.dart';

/// UrlBlocklistDao v4.9（SchemaManager対応版）
///
/// 存在しない画像URLを記録・参照・削除するDAO。
/// 通信負荷を減らすため、404などのエラーURLを再取得対象から除外する。
class UrlBlocklistDao {
  final _dbService = LocalDBService.instance;

  /// 🔹 URLをブロックリストに追加または更新
  /// reason 例: "404 not found", "timeout", etc.
  Future<void> addOrUpdate(String url, [String reason = 'unknown']) async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();

    final data = {'url': url, 'reason': reason, 'updatedAt': now};

    // SchemaManagerで不要カラム除去（整合性チェック）
    final clean = SchemaManager.instance.sanitize('url_blocklist', data);

    await db.insert(
      'url_blocklist',
      clean,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    appLog('🚫 URL blocked: $url ($reason)');
  }

  /// 🔹 URLがブロック済みか確認
  Future<bool> isBlocked(String url) async {
    final db = await _dbService.database;
    final result =
        await db.query('url_blocklist', where: 'url = ?', whereArgs: [url]);
    final blocked = result.isNotEmpty;
    if (blocked) appLog('⛔ Blocked URL skipped: $url');
    return blocked;
  }

  /// 🔹 1日以上前のエントリを削除（ガベージ処理）
  Future<void> purgeOldEntries() async {
    final db = await _dbService.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final deleted = await db.delete(
      'url_blocklist',
      where: 'updatedAt < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
    appLog('🧹 Purged $deleted old URL block entries');
  }

  /// 🔹 現在のブロックリスト件数を取得（デバッグ用途）
  Future<int> count() async {
    final db = await _dbService.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM url_blocklist');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// 🔹 デバッグ用：最新10件を取得
  Future<List<Map<String, dynamic>>> getRecentEntries({int limit = 10}) async {
    final db = await _dbService.database;
    final result = await db.query(
      'url_blocklist',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );

    // SchemaManagerで整合性を確保
    return result
        .map((row) => SchemaManager.instance.sanitize('url_blocklist', row))
        .toList();
  }
}
