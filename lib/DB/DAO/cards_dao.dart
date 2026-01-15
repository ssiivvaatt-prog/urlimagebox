import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../CORE/local_db_service.dart';
import '../../utils/logger.dart';
import '../models/schema_manager.dart';

/// ------------------------------------------------------------
/// CardsDao
/// ------------------------------------------------------------
/// - cards テーブル専用 DAO
/// - カードの取得 / 追加 / 更新 / 削除 を担当
/// - series_list / series_config / series_filter には一切触れない
///   → 複合操作は Repository 側で行う
/// ------------------------------------------------------------
class CardsDao {
  static final CardsDao instance = CardsDao._internal();
  CardsDao._internal();

  final _dbService = LocalDBService.instance;

  /// ------------------------------------------------------------
  /// 指定シリーズのカードをすべて削除
  /// ------------------------------------------------------------
  Future<void> deleteBySeriesId(String seriesId) async {
    final db = await _dbService.database;

    await db.delete(
      'cards',
      where: 'seriesId = ?',
      whereArgs: [seriesId],
    );

    appLog('🗑️ Cards deleted for series: $seriesId');
  }

  /// ------------------------------------------------------------
  /// カード登録（既存があれば上書き）
  /// ------------------------------------------------------------
  Future<void> insertOrReplace(Map<String, dynamic> card) async {
    final db = await _dbService.database;

    final clean = SchemaManager.instance.sanitize('cards', card);

    await db.insert(
      'cards',
      clean,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    appLog('💾 Card saved: ${clean['seriesId']}_${clean['number']}');
  }

  /// ------------------------------------------------------------
  /// 画像パス更新（キャッシュ保存時に使用）
  /// ------------------------------------------------------------
  Future<void> updateImagePath(
      String seriesId, int number, String imagePath) async {
    final db = await _dbService.database;

    await db.update(
      'cards',
      {
        'imagePath': imagePath,
      },
      where: 'seriesId = ? AND number = ?',
      whereArgs: [seriesId, number],
    );
  }

  /// ------------------------------------------------------------
  /// 指定シリーズのカード一覧を取得（番号昇順）
  /// ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getCardsBySeriesId(String seriesId) async {
    final db = await _dbService.database;

    final result = await db.query(
      'cards',
      where: 'seriesId = ?',
      whereArgs: [seriesId],
      orderBy: 'number ASC',
    );

    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// ------------------------------------------------------------
  /// 全カード取得（デバッグ・管理用）
  /// ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllCards() async {
    final db = await _dbService.database;
    return await db.query('cards');
  }

  /// ------------------------------------------------------------
  /// from〜to の範囲外カードを削除（番号変更時に使用）
  /// ------------------------------------------------------------
  Future<void> deleteOutOfRange({
    required String seriesId,
    required int from,
    required int to,
  }) async {
    final db = await _dbService.database;

    await db.delete(
      'cards',
      where: 'seriesId = ? AND (number < ? OR number > ?)',
      whereArgs: [seriesId, from, to],
    );

    appLog('🧹 deleteOutOfRange: $seriesId (keep $from〜$to)');
  }

  /// ------------------------------------------------------------
  /// 単一カード取得（複製処理などで使用）
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>?> getCardBySeriesAndNumber(
      String seriesId, int number) async {
    final db = await _dbService.database;

    final result = await db.query(
      'cards',
      where: 'seriesId = ? AND number = ?',
      whereArgs: [seriesId, number],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Map<String, dynamic>.from(result.first);
  }

  /// ------------------------------------------------------------
  /// 全カードの imagePath を NULL にリセット（キャッシュ削除時）
  /// ------------------------------------------------------------
  Future<void> resetAllImagePaths() async {
    final db = await _dbService.database;

    await db.update(
      'cards',
      {
        'imagePath': null,
      },
    );

    appLog('🧼 All imagePath reset to NULL');
  }

  /// ------------------------------------------------------------
  /// 任意の int カラムを更新（attrX / numericX / dateX / rotationAngle）
  /// ------------------------------------------------------------
  Future<void> updateField(
    String seriesId,
    int number,
    String columnName,
    int value,
  ) async {
    final db = await _dbService.database;

    await db.update(
      'cards',
      {
        columnName: value,
      },
      where: 'seriesId = ? AND number = ?',
      whereArgs: [seriesId, number],
    );

    appLog('✏️ $columnName updated: $seriesId#$number → $value');
  }

  /// ------------------------------------------------------------
  /// attrX 更新
  /// ------------------------------------------------------------
  Future<void> updateCardAttr({
    required String seriesId,
    required int number,
    required int slotIndex,
    required int value,
  }) async {
    await updateField(seriesId, number, 'attr$slotIndex', value);
  }

  /// ------------------------------------------------------------
  /// numericX 更新
  /// ------------------------------------------------------------
  Future<void> updateCardNumeric({
    required String seriesId,
    required int number,
    required int slotIndex,
    required int value,
  }) async {
    await updateField(seriesId, number, 'numeric$slotIndex', value);
  }

  /// ------------------------------------------------------------
  /// dateX 更新
  /// ------------------------------------------------------------
  Future<void> updateCardDate({
    required String seriesId,
    required int number,
    required int slotIndex,
    required int value,
  }) async {
    await updateField(seriesId, number, 'date$slotIndex', value);
  }

  /// ------------------------------------------------------------
  /// 回転角度更新
  /// ------------------------------------------------------------
  Future<void> updateRotation({
    required String seriesId,
    required int number,
    required int angle,
  }) async {
    await updateField(seriesId, number, 'rotationAngle', angle);
  }

  /// ------------------------------------------------------------
  /// 回転角度更新（正規化あり）
  /// ------------------------------------------------------------
  Future<void> updateRotationAngle(
      String seriesId, int number, int angle) async {
    final db = await _dbService.database;

    final normalized = ((angle % 360) + 360) % 360;

    await db.update(
      'cards',
      {
        'rotationAngle': normalized,
      },
      where: 'seriesId = ? AND number = ?',
      whereArgs: [seriesId, number],
    );

    appLog('🔄 rotationAngle updated: $seriesId#$number → $normalized°');
  }
  // ============================================================
  // ✅ バックアップ・リストア用メソッド
  // ============================================================

  /// 全データ取得（バックアップ用）
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _dbService.database;
    final result = await db.query('cards');
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 全データ復元（リストア用: 全削除 → 一括挿入）
  Future<void> restoreAll(List<Map<String, dynamic>> data) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete('cards');

      for (final row in data) {
        final clean = SchemaManager.instance.sanitize('cards', row);
        await txn.insert('cards', clean);
      }
    });

    appLog('✅ restoreAll: cards (${data.length}件)');
  }
}
