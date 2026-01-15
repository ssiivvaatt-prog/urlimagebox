import 'package:sqflite/sqflite.dart';
import '../../utils/logger.dart';

/// ------------------------------------------------------------
/// SchemaManager
/// ------------------------------------------------------------
/// - SQLite のテーブル構造（カラム一覧）を起動時にキャッシュする
/// - INSERT / UPDATE 時に「存在しないカラム」を除外するための仕組み
/// - スキーマ変更が多い開発中でも安全にデータを扱える
///
/// 例：
///   sanitize('cards', {'foo': 1, 'attr1': 10})
///   → 'foo' は存在しないので除外される
///
/// これにより、
/// - マイグレーション前後の不整合
/// - 古いデータモデルのまま INSERT してクラッシュ
/// を防ぐことができる。
/// ------------------------------------------------------------
class SchemaManager {
  static final SchemaManager _instance = SchemaManager._internal();
  factory SchemaManager() => _instance;
  SchemaManager._internal();

  /// テーブル名 → カラム名セット のキャッシュ
  final Map<String, Set<String>> _tableColumns = {};

  /// ------------------------------------------------------------
  /// DB 初期化時に全テーブルのカラム一覧を取得してキャッシュする
  /// ------------------------------------------------------------
  Future<void> initialize(Database db) async {
    final tables = [
      'series_list',
      'series_config',
      'series_filter',
      'cards',
      'text_slot_list',
      'text_item_list',
      'text_item_detail',
      'numeric_slot_list',
      'numeric_slot_detail',
      'date_slot_list',
      'date_slot_detail',
      'url_blocklist',
      'meta',
    ];

    for (final table in tables) {
      // PRAGMA table_info は SQLite のメタ情報取得コマンド
      final result = await db.rawQuery('PRAGMA table_info($table)');

      if (result.isEmpty) {
        appLog('⚠️ No columns found for $table');
        _tableColumns[table] = {};
        continue;
      }

      // カラム名だけを抽出して Set にする
      final columns = result.map((row) => row['name'] as String).toSet();
      _tableColumns[table] = columns;

      appLog('🧩 Cached columns for $table: $columns');
    }

    appLog('✅ SchemaManager initialized with ${_tableColumns.length} tables');
  }

  /// ------------------------------------------------------------
  /// 指定テーブルのカラム一覧を取得
  /// ------------------------------------------------------------
  Set<String>? getColumns(String table) => _tableColumns[table];

  /// ------------------------------------------------------------
  /// INSERT / UPDATE 用データを「存在するカラムだけ」にフィルタリング
  /// ------------------------------------------------------------
  Map<String, dynamic> sanitize(String table, Map<String, dynamic> data) {
    final columns = getColumns(table);

    if (columns == null) {
      appLog('⚠️ sanitize: unknown table $table');
      return {};
    }

    // カラムに存在するキーだけを残す
    final filtered = Map.fromEntries(
      data.entries.where((e) => columns.contains(e.key)),
    );

    // 除外されたキーがあればログに出す
    if (filtered.length != data.length) {
      final removed = data.keys.where((k) => !columns.contains(k)).toList();
      appLog('🧹 sanitize($table): removed unknown keys → $removed');
    }

    return filtered;
  }

  /// シングルトンインスタンス取得用
  static SchemaManager get instance => _instance;
}
