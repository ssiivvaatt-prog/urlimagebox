import 'package:sqflite/sqflite.dart';
import '../CORE/local_db_service.dart';
import '../../utils/logger.dart';
import '../models/schema_manager.dart';

/// ------------------------------------------------------------
/// SeriesListDao
/// ------------------------------------------------------------
/// - series_list テーブル専用 DAO
/// - 「シリーズ一覧画面」で使う名前・sortIndex のみを扱う
/// - series_config / series_filter / cards には一切触れない
///   → シリーズ削除の複合処理は Repository 側で行う
/// ------------------------------------------------------------
class SeriesListDao {
  static final SeriesListDao instance = SeriesListDao._internal();
  SeriesListDao._internal();

  final _dbService = LocalDBService.instance;

  /// ------------------------------------------------------------
  /// 全シリーズ取得（sortIndex 昇順）
  /// ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllSeriesList() async {
    final db = await _dbService.database;

    final list = await db.query(
      'series_list',
      orderBy: 'sortIndex ASC',
    );

    appLog('📄 getAllSeries: ${list.length} items');
    return list.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// ------------------------------------------------------------
  /// 最大 sortIndex を取得（新規追加時用）
  /// ------------------------------------------------------------
  Future<int> getMaxSortIndex() async {
    final db = await _dbService.database;
    final result =
        await db.rawQuery('SELECT MAX(sortIndex) as max FROM series_list');
    return (result.first['max'] as int?) ?? 0;
  }

  /// ------------------------------------------------------------
  /// シリーズ新規登録（series_list に追加）
  /// ------------------------------------------------------------
  Future<void> insertSeriesList(Map<String, dynamic> data) async {
    final db = await _dbService.database;
    final maxSort = await getMaxSortIndex();

    final toInsert = Map<String, dynamic>.from(data);
    toInsert['sortIndex'] = maxSort + 1;

    final clean = SchemaManager.instance.sanitize('series_list', toInsert);
    _logMapKeys('insertSeries', clean);

    await db.insert(
      'series_list',
      clean,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    appLog('✅ insertSeries: ${clean['id']} (${clean['name']})');
  }

  /// ------------------------------------------------------------
  /// シリーズ削除（series_list のみ）
  /// ------------------------------------------------------------
  Future<void> deleteSeriesList(String id) async {
    final db = await _dbService.database;

    await db.delete(
      'series_list',
      where: 'id = ?',
      whereArgs: [id],
    );

    appLog('🗑 deleteSeries: $id (series_list only)');
  }

  /// ------------------------------------------------------------
  /// ロングログ対応：キー一覧を分割して出力
  /// ------------------------------------------------------------
  void _logMapKeys(String label, Map<String, dynamic> data) {
    final keys = data.keys.toList();
    const chunkSize = 20;

    for (int i = 0; i < keys.length; i += chunkSize) {
      final chunk = keys.skip(i).take(chunkSize).join(', ');
      appLog(
          '🧩 [$label keys ${i + 1}-${(i + chunkSize).clamp(0, keys.length)}] $chunk');
    }
  }

  Future<void> updateOrderByIds(List<String> ids) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      for (int i = 0; i < ids.length; i++) {
        await txn.update(
          'series_list',
          {'sortIndex': i},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
    });

    appLog('🔄 updateOrderByIds: ${ids.length} items');
  }

  /// ------------------------------------------------------------
  /// ID 指定で 1 件取得（series_list）
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>?> getSeriesListById(String id) async {
    final db = await _dbService.database;

    final result = await db.query(
      'series_list',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final clean = SchemaManager.instance.sanitize(
      'series_list',
      Map<String, dynamic>.from(result.first),
    );

    return clean;
  }

  Future<void> updateSeriesList(String id, Map<String, dynamic> data) async {
    final db = await _dbService.database;

    final clean = SchemaManager.instance.sanitize('series_list', data);
    _logMapKeys('updateSeriesList', clean);

    await db.update(
      'series_list',
      clean,
      where: 'id = ?',
      whereArgs: [id],
    );

    appLog('✏️ updateSeriesList: $id');
  }
  // ============================================================
  // ✅ バックアップ・リストア用メソッド
  // ============================================================

  /// 全データ取得（バックアップ用）
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _dbService.database;
    final result = await db.query('series_list');
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// series_config 全データ取得（バックアップ用）
  Future<List<Map<String, dynamic>>> getAllConfigs() async {
    final db = await _dbService.database;
    final result = await db.query('series_config');
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 全データ復元（リストア用: series_list）
  Future<void> restoreAll(List<Map<String, dynamic>> data) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete('series_list');

      for (final row in data) {
        final clean = SchemaManager.instance.sanitize('series_list', row);
        await txn.insert('series_list', clean);
      }
    });

    appLog('✅ restoreAll: series_list (${data.length}件)');
  }

  /// 全データ復元（リストア用: series_config）
  Future<void> restoreAllConfigs(List<Map<String, dynamic>> data) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete('series_config');

      for (final row in data) {
        final clean = SchemaManager.instance.sanitize('series_config', row);
        await txn.insert('series_config', clean);
      }
    });

    appLog('✅ restoreAll: series_config (${data.length}件)');
  }
}
