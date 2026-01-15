import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../CORE/local_db_service.dart';
import '../models/schema_manager.dart';

/// MetaDao v5.0（モード状態管理対応版＋後方互換維持）
///
/// 🔸 役割：
/// - key/value 形式のメタ情報を保存・取得
/// - 現在モードやサブモード状態を JSON 形式で一括管理
/// - 旧API（setValue/getValue）も下位互換として維持
class MetaDao {
  final _dbService = LocalDBService.instance;

  /// 🔹 メタ情報を登録／更新（既存キーがあれば上書き）
  Future<void> setMeta(String key, String value) async {
    final db = await _dbService.database;

    final data = {'key': key, 'value': value};
    final clean = SchemaManager.instance.sanitize('meta', data);

    await db.insert(
      'meta',
      clean,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔹 メタ情報を取得（存在しなければ null）
  Future<String?> getMeta(String key) async {
    final db = await _dbService.database;
    final res = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      final row = SchemaManager.instance.sanitize('meta', res.first);
      return row['value'] as String?;
    }
    return null;
  }

  // ----------------------------------------------------------
  // ✅ 下位互換メソッド（v4.8系までで使われていた名称）
  // ----------------------------------------------------------

  /// [旧API] setValue() → setMeta() のエイリアス
  Future<void> setValue(String key, String value) async {
    await setMeta(key, value);
  }

  /// [旧API] getValue() → getMeta() のエイリアス
  Future<String?> getValue(String key) async {
    return getMeta(key);
  }

  // ----------------------------------------------------------
  // 🧭 モード状態管理用メソッド（v5.0仕様対応）
  // ----------------------------------------------------------

  static const String _modeKey = 'modeState';

  /// 🔸 現在のモード状態を保存
  /// - currentMode: "rotate" / "remark" / "number"
  /// - 各モードのサブモード index（1〜3）
  Future<void> saveModeState({
    required String currentMode,
    required int rotateModeIndex,
    required int remarkModeIndex,
    required int numberModeIndex,
  }) async {
    final modeData = {
      'currentMode': currentMode,
      'rotateModeIndex': rotateModeIndex,
      'remarkModeIndex': remarkModeIndex,
      'numberModeIndex': numberModeIndex,
    };
    await setMeta(_modeKey, jsonEncode(modeData));
  }

  /// 🔸 現在のモード状態を取得（存在しない場合はデフォルト値を返す）
  Future<Map<String, dynamic>> loadModeState() async {
    final jsonStr = await getMeta(_modeKey);
    if (jsonStr == null) {
      return {
        'currentMode': 'rotate',
        'rotateModeIndex': 1,
        'remarkModeIndex': 1,
        'numberModeIndex': 1,
      };
    }
    try {
      final data = jsonDecode(jsonStr);
      return {
        'currentMode': data['currentMode'] ?? 'rotate',
        'rotateModeIndex': data['rotateModeIndex'] ?? 1,
        'remarkModeIndex': data['remarkModeIndex'] ?? 1,
        'numberModeIndex': data['numberModeIndex'] ?? 1,
      };
    } catch (e) {
      // JSON壊れ時は初期値でリセット
      return {
        'currentMode': 'rotate',
        'rotateModeIndex': 1,
        'remarkModeIndex': 1,
        'numberModeIndex': 1,
      };
    }
  }
}
