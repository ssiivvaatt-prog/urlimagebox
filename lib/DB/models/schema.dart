// ========================================
// ⚠️ TODO: Schema変更時の重要な注意事項
// ========================================
// このファイルでテーブル構造を変更した場合は、
// 必ず backup_provider.dart の DATA_VERSION を増やすこと！
//
// 例: static const int DATA_VERSION = 1; → 2;
// ========================================

import 'package:sqflite/sqflite.dart';
import '../../utils/logger.dart';

class Schema {
  // ------------------------------------------------------------
  // シリーズ一覧（最初の画面用）
  // ------------------------------------------------------------
  static String get createSeriesListTable => '''
    CREATE TABLE IF NOT EXISTS series_list ( 
      id TEXT PRIMARY KEY,          -- シリーズUUID
      name TEXT DEFAULT '',         -- シリーズ名
      sortIndex INTEGER DEFAULT 0   -- 並び順
    );
  ''';

  // ------------------------------------------------------------
  // シリーズ設定（URL・番号範囲・桁数など）
  // ------------------------------------------------------------
  static String get createSeriesConfigTable => '''
    CREATE TABLE IF NOT EXISTS series_config ( 
      id TEXT PRIMARY KEY,          -- シリーズUUID
      baseUrlBefore TEXT DEFAULT '',-- URL前半
      baseUrlAfter TEXT DEFAULT '', -- URL後半
      fromNum INTEGER DEFAULT 1,    -- 開始番号
      toNum INTEGER DEFAULT 100,    -- 終了番号
      digitCount INTEGER DEFAULT 3, -- ゼロ埋め桁数
      columns INTEGER DEFAULT 5,    -- 一覧の列数
      zeroPadEnabled INTEGER NOT NULL DEFAULT 1 -- ゼロ埋め有効
    );
  ''';

  // ------------------------------------------------------------
  // カード（シリーズごとのカードデータ）
  // ------------------------------------------------------------
  static String get createCardsTable => '''
    CREATE TABLE IF NOT EXISTS cards (
      seriesId TEXT NOT NULL,       -- シリーズUUID
      number INTEGER NOT NULL,      -- カード番号

      -- テキスト属性
      attr1 INTEGER DEFAULT 0,
      attr2 INTEGER DEFAULT 0,
      attr3 INTEGER DEFAULT 0,
      attr4 INTEGER DEFAULT 0,
      attr5 INTEGER DEFAULT 0,
      attr6 INTEGER DEFAULT 0,

      -- 数値属性
      numeric1 INTEGER DEFAULT 0,
      numeric2 INTEGER DEFAULT 0,
      numeric3 INTEGER DEFAULT 0,
      numeric4 INTEGER DEFAULT 0,
      numeric5 INTEGER DEFAULT 0,
      numeric6 INTEGER DEFAULT 0,

      -- 日付属性
      date1 INTEGER DEFAULT 0,
      date2 INTEGER DEFAULT 0,
      date3 INTEGER DEFAULT 0,
      date4 INTEGER DEFAULT 0,
      date5 INTEGER DEFAULT 0,
      date6 INTEGER DEFAULT 0,

      rotationAngle INTEGER NOT NULL DEFAULT 0, -- 回転角度(0〜359)

      imageUrl TEXT DEFAULT '',       -- 画像URL
      imagePath TEXT DEFAULT '',      -- ローカルキャッシュパス

      PRIMARY KEY (seriesId, number)
    );
  ''';

  // ------------------------------------------------------------
  // テキストスロット（アプリ共通）
  // ------------------------------------------------------------
  static String get createTextSlotListTable => '''
    CREATE TABLE IF NOT EXISTS text_slot_list (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      enabled INTEGER NOT NULL DEFAULT 0, -- 有効/無効
      name TEXT DEFAULT 'カスタマイズ',   -- スロット名
      PRIMARY KEY (slotIndex)
    );
  ''';

  // テキストアイテム一覧（アプリ共通）
  static String get createTextItemListTable => '''
    CREATE TABLE IF NOT EXISTS text_item_list (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      itemIndex INTEGER NOT NULL,   -- 1〜20
      enabled INTEGER NOT NULL DEFAULT 0, -- 有効/無効
      name TEXT DEFAULT 'カスタマイズ',   -- アイテム名
      PRIMARY KEY (slotIndex, itemIndex)
    );
  ''';

  // テキストアイテム詳細（アプリ共通）
  static String get createTextItemDetailTable => '''
    CREATE TABLE IF NOT EXISTS text_item_detail (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      itemIndex INTEGER NOT NULL,   -- 1〜20

      label TEXT DEFAULT '',        -- 表示ラベル
      font TEXT DEFAULT 'Arial',    -- フォント
      fontSize INTEGER DEFAULT 60,  -- フォントサイズ
      color TEXT DEFAULT '#FF000000', -- 文字色
      backgroundColor TEXT DEFAULT '#00000000', -- 背景色
      isVertical INTEGER DEFAULT 0, -- 縦書き(1) / 横書き(0)
      posX REAL DEFAULT 0.5,        -- X位置
      posY REAL DEFAULT 0.5,        -- Y位置

      PRIMARY KEY (slotIndex, itemIndex)
    );
  ''';

  // ------------------------------------------------------------
  // 数値スロット（アプリ共通）
  // ------------------------------------------------------------
  static String get createNumericSlotListTable => '''
    CREATE TABLE IF NOT EXISTS numeric_slot_list (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      enabled INTEGER NOT NULL DEFAULT 0,
      name TEXT DEFAULT 'カスタマイズ',
      PRIMARY KEY (slotIndex)
    );
  ''';

  static String get createNumericSlotDetailTable => '''
    CREATE TABLE IF NOT EXISTS numeric_slot_detail (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      frontlabel TEXT DEFAULT '',   -- 前ラベル
      afterlabel TEXT DEFAULT '',   -- 後ラベル
      font TEXT DEFAULT 'Arial',
      fontSize INTEGER DEFAULT 60,
      color TEXT DEFAULT '#FF000000',
      backgroundColor TEXT DEFAULT '#00000000',
      isVertical INTEGER DEFAULT 0,
      posX REAL DEFAULT 0.5,
      posY REAL DEFAULT 0.5,
      useThousandsSeparator INTEGER DEFAULT 0, -- ✅ 追加: 3桁カンマ区切り
      PRIMARY KEY (slotIndex)
    );
  ''';

  // ------------------------------------------------------------
  // 日付スロット（アプリ共通）
  // ------------------------------------------------------------
  static String get createDateSlotListTable => '''
    CREATE TABLE IF NOT EXISTS date_slot_list (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      enabled INTEGER NOT NULL DEFAULT 0,
      name TEXT DEFAULT 'カスタマイズ',
      PRIMARY KEY (slotIndex)
    );
  ''';

  static String get createDateSlotDetailTable => '''
    CREATE TABLE IF NOT EXISTS date_slot_detail (
      slotIndex INTEGER NOT NULL,   -- 1〜6
      frontlabel TEXT DEFAULT '',
      afterlabel TEXT DEFAULT '',
      font TEXT DEFAULT 'Arial',
      fontSize INTEGER DEFAULT 60,
      color TEXT DEFAULT '#FF000000',
      backgroundColor TEXT DEFAULT '#00000000',
      isVertical INTEGER DEFAULT 0,
      posX REAL DEFAULT 0.5,
      posY REAL DEFAULT 0.5,
      displayFormat TEXT DEFAULT 'yyyy/MM/dd', -- 表示形式
      PRIMARY KEY (slotIndex)
    );
  ''';

  // ------------------------------------------------------------
  // URLブロックリスト（キャッシュ制御など）
  // ------------------------------------------------------------
  static String get createUrlBlocklistTable => '''
    CREATE TABLE IF NOT EXISTS url_blocklist (
      url TEXT PRIMARY KEY,
      reason TEXT DEFAULT '',
      updatedAt TEXT DEFAULT CURRENT_TIMESTAMP
    );
  ''';

  // ------------------------------------------------------------
  // メタ情報（アプリ内部用）
  // ------------------------------------------------------------
  static String get createMetaTable => '''
    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT DEFAULT '{}'
    );
  ''';

  // ------------------------------------------------------------
  // 全テーブル作成
  // ------------------------------------------------------------
  static Future<void> createTables(Database db) async {
    await db.execute(createSeriesListTable);
    await db.execute(createSeriesConfigTable);
    await db.execute(createCardsTable);

    await db.execute(createTextSlotListTable);
    await db.execute(createTextItemListTable);
    await db.execute(createTextItemDetailTable);

    await db.execute(createNumericSlotListTable);
    await db.execute(createNumericSlotDetailTable);

    await db.execute(createDateSlotListTable);
    await db.execute(createDateSlotDetailTable);

    await db.execute(createMetaTable);
    await db.execute(createUrlBlocklistTable);

    appLog('✅ Tables created (v5.0 / text+numeric+date slots/items)');
  }
}
