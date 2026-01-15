import 'package:sqflite/sqflite.dart';
import '../CORE/local_db_service.dart';
import '../../utils/logger.dart';
import '../models/schema_manager.dart';

/// ------------------------------------------------------------
/// SeriesConfigDao
/// ------------------------------------------------------------
/// - series_config テーブル専用 DAO
/// - URL・番号範囲・桁数・列数など「シリーズ設定」を扱う
/// - series_list / series_filter / cards には一切触れない
///   → 複合操作は Repository 側で行う
/// ------------------------------------------------------------
class SeriesConfigDao {
  static final SeriesConfigDao instance = SeriesConfigDao._internal();
  SeriesConfigDao._internal();

  final _dbService = LocalDBService.instance;

  /// ------------------------------------------------------------
  /// 設定を1件取得（seriesId 指定）
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>?> getConfigById(String seriesId) async {
    final db = await _dbService.database;

    final result = await db.query(
      'series_config',
      where: 'id = ?',
      whereArgs: [seriesId],
    );

    if (result.isEmpty) return null;

    final clean = SchemaManager.instance.sanitize(
      'series_config',
      Map<String, dynamic>.from(result.first),
    );

    return clean;
  }

  /// ------------------------------------------------------------
  /// 設定更新（部分更新OK）
  /// ------------------------------------------------------------
  Future<void> updateConfig(String seriesId, Map<String, dynamic> data) async {
    final db = await _dbService.database;

    final clean = SchemaManager.instance.sanitize('series_config', data);
    _logMapKeys('updateConfig', clean);

    await db.update(
      'series_config',
      clean,
      where: 'id = ?',
      whereArgs: [seriesId],
    );

    appLog('✏️ updateConfig: $seriesId (${clean.keys.length} keys)');
  }

  /// ------------------------------------------------------------
  /// 設定削除（series_config のみ）
  /// ------------------------------------------------------------
  Future<void> deleteConfig(String seriesId) async {
    final db = await _dbService.database;

    await db.delete(
      'series_config',
      where: 'id = ?',
      whereArgs: [seriesId],
    );

    appLog('🗑 deleteConfig: $seriesId (series_config only)');
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
        '🧩 [$label keys ${i + 1}-${(i + chunkSize).clamp(0, keys.length)}] $chunk',
      );
    }
  }

  Future<void> insertConfig(Map<String, dynamic> data) async {
    final db = await _dbService.database;

    final clean = SchemaManager.instance.sanitize('series_config', data);

    await db.insert(
      'series_config',
      clean,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    appLog('✅ insertConfig: ${data['id']}');
  }
}
