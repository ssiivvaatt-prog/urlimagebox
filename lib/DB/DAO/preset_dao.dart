import '../CORE/local_db_service.dart';
import '../../utils/logger.dart';
import '../models/schema_manager.dart';

class SlotPreset {
  final String name;
  final bool enabled;

  // Numeric / Date 用
  final String? frontLabel;
  final String? afterLabel;
  final String? font;
  final int? fontSize;
  final String? color;
  final String? backgroundColor;
  final bool? isVertical;
  final double? posX;
  final double? posY;
  final int? useThousandsSeparator;

  const SlotPreset({
    required this.name,
    this.enabled = true,
    this.frontLabel,
    this.afterLabel,
    this.font,
    this.fontSize,
    this.color,
    this.backgroundColor,
    this.isVertical,
    this.posX,
    this.posY,
    this.useThousandsSeparator,
  });
}

class TextItemPreset {
  final bool enabled;
  final String label;
  final String? font;
  final String color;
  final String? backgroundColor;
  final int fontSize;
  final bool isVertical;
  final double posX;
  final double posY;

  const TextItemPreset({
    required this.enabled,
    required this.label,
    this.font,
    required this.color,
    this.backgroundColor,
    required this.fontSize,
    this.isVertical = false,
    required this.posX,
    required this.posY,
  });
}

class DefaultPresets {
  static final Map<int, Map<int, TextItemPreset>> presetMap = {
    0: {
      0: const TextItemPreset(
        enabled: true,
        label: "求",
        font: "Arial",
        color: "#FF000000",
        backgroundColor: "#FFFFFFFF",
        fontSize: 45,
        isVertical: false,
        posX: 0.0,
        posY: 0.0,
      ),
      1: const TextItemPreset(
        enabled: true,
        label: "出",
        font: "Arial",
        color: "#FF000000",
        backgroundColor: "#FFFFFFFF",
        fontSize: 45,
        isVertical: false,
        posX: 0.0,
        posY: 0.0,
      ),
      2: const TextItemPreset(
        enabled: true,
        label: "済",
        font: "Arial",
        color: "#FF000000",
        backgroundColor: "#FFFFFFFF",
        fontSize: 45,
        isVertical: false,
        posX: 0.0,
        posY: 0.0,
      ),
      3: const TextItemPreset(
        enabled: true,
        label: "所持",
        font: "Arial",
        color: "#FF000000",
        backgroundColor: "#FFFFFFFF",
        fontSize: 45,
        isVertical: false,
        posX: 0.0,
        posY: 0.0,
      ),
    },
    1: {
      0: const TextItemPreset(
        enabled: true,
        label: "★",
        font: "Arial",
        color: "#FF00FF00",
        backgroundColor: "#00000000",
        fontSize: 35,
        isVertical: false,
        posX: 0.00,
        posY: 0.7,
      ),
      1: const TextItemPreset(
        enabled: true,
        label: "★★",
        font: "Arial",
        color: "#FF00FF00",
        backgroundColor: "#00000000",
        fontSize: 35,
        isVertical: false,
        posX: 0.00,
        posY: 0.7,
      ),
      2: const TextItemPreset(
        enabled: true,
        label: "★★★",
        font: "Arial",
        color: "#FF00FF00",
        backgroundColor: "#00000000",
        fontSize: 35,
        isVertical: false,
        posX: 0.00,
        posY: 0.7,
      ),
    },
  };

  static const List<SlotPreset> textSlotPresets = [
    SlotPreset(name: '交換', enabled: true),
    SlotPreset(name: 'レア', enabled: true),
  ];

  static const List<SlotPreset> numericSlotPresets = [
    SlotPreset(
      enabled: true,
      name: '所持数',
      frontLabel: "所持",
      afterLabel: "個",
      font: "Arial",
      fontSize: 28,
      color: "#FF000000",
      backgroundColor: "#FFF2C9C9",
      isVertical: false,
      posX: 0.24,
      posY: 0.24,
      useThousandsSeparator: 0,
    ),
    SlotPreset(
      enabled: true,
      name: '希望数',
      frontLabel: "求",
      afterLabel: "個",
      font: "Arial",
      fontSize: 28,
      color: "#FF000000",
      backgroundColor: "#FFF2C9C9",
      isVertical: false,
      posX: 0.24,
      posY: 0.43,
      useThousandsSeparator: 0,
    ),
    SlotPreset(
      enabled: true,
      name: '値段',
      frontLabel: "",
      afterLabel: "円",
      font: "Arial",
      fontSize: 28,
      color: "#FF000000",
      backgroundColor: "#FFF2C9C9",
      isVertical: false,
      posX: 0.24,
      posY: 0.62,
      useThousandsSeparator: 1,
    ),
  ];

  static const List<SlotPreset> dateSlotPresets = [
    SlotPreset(
      enabled: true,
      name: '日付',
      frontLabel: "",
      afterLabel: "",
      font: "Arial",
      fontSize: 23,
      color: "#FF000000",
      backgroundColor: "#FFC7D6FB",
      isVertical: false,
      posX: 0.45,
      posY: 0.0,
    ),
  ];
}

class PresetDao {
  static final PresetDao instance = PresetDao._internal();
  PresetDao._internal();

  final _dbService = LocalDBService.instance;

  // ============================================================
  // ✅ 全プリセットデータを削除（初期化用）
  // ============================================================
  Future<void> deleteAllPresets() async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete('text_slot_list');
      await txn.delete('text_item_list');
      await txn.delete('text_item_detail');
      await txn.delete('numeric_slot_list');
      await txn.delete('numeric_slot_detail');
      await txn.delete('date_slot_list');
      await txn.delete('date_slot_detail');
    });

    appLog('🗑️ deleteAllPresets: 全プリセットデータ削除完了');
  }

// ============================================================
  // ✅ デフォルトデータ挿入（既存のメソッドを修正）
  // ============================================================
  Future<void> insertDefaults() async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      final batch = txn.batch();

      for (var i = 0; i < 6; i++) {
        final slotIndex = i + 1;

        // ========================================
        // text_slot_list
        // ========================================
        final textPreset = i < DefaultPresets.textSlotPresets.length
            ? DefaultPresets.textSlotPresets[i]
            : null;

        final textSlotData = <String, dynamic>{
          'slotIndex': slotIndex,
          'enabled': textPreset?.enabled == true ? 1 : 0,
          'name': textPreset?.name ?? 'カスタマイズ',
        };

        batch.insert('text_slot_list',
            SchemaManager.instance.sanitize('text_slot_list', textSlotData));

        // ========================================
        // numeric_slot_list
        // ========================================
        final numPreset = i < DefaultPresets.numericSlotPresets.length
            ? DefaultPresets.numericSlotPresets[i]
            : null;

        final numSlotData = <String, dynamic>{
          'slotIndex': slotIndex,
          'enabled': numPreset?.enabled == true ? 1 : 0,
          'name': numPreset?.name ?? 'カスタマイズ',
        };

        batch.insert('numeric_slot_list',
            SchemaManager.instance.sanitize('numeric_slot_list', numSlotData));

        // ========================================
// numeric_slot_detail
// ========================================
        final numDetailData = <String, dynamic>{
          'slotIndex': slotIndex,
          'frontlabel': numPreset?.frontLabel ?? '',
          'afterlabel': numPreset?.afterLabel ?? '',
          'font': numPreset?.font ?? 'Arial',
          'fontSize': numPreset?.fontSize ?? 20,
          'color': numPreset?.color ?? '#FF000000',
          'backgroundColor': numPreset?.backgroundColor ?? '#00000000',
          'isVertical': (numPreset?.isVertical ?? false) ? 1 : 0,
          'posX': numPreset?.posX ?? 0.5,
          'posY': numPreset?.posY ?? 0.5,
          'useThousandsSeparator': numPreset?.useThousandsSeparator ?? 0,
        };

        batch.insert(
            'numeric_slot_detail',
            SchemaManager.instance
                .sanitize('numeric_slot_detail', numDetailData));

        // ========================================
        // date_slot_list
        // ========================================
        final datePreset = i < DefaultPresets.dateSlotPresets.length
            ? DefaultPresets.dateSlotPresets[i]
            : null;

        final dateSlotData = <String, dynamic>{
          'slotIndex': slotIndex,
          'enabled': datePreset?.enabled == true ? 1 : 0,
          'name': datePreset?.name ?? 'カスタマイズ',
        };

        batch.insert('date_slot_list',
            SchemaManager.instance.sanitize('date_slot_list', dateSlotData));

        // ========================================
        // date_slot_detail
        // ========================================
        final dateDetailData = <String, dynamic>{
          'slotIndex': slotIndex,
          'frontlabel': datePreset?.frontLabel ?? '',
          'afterlabel': datePreset?.afterLabel ?? '',
          'font': datePreset?.font ?? 'Arial',
          'fontSize': datePreset?.fontSize ?? 20,
          'color': datePreset?.color ?? '#FF000000',
          'backgroundColor': datePreset?.backgroundColor ?? '#00000000',
          'isVertical': (datePreset?.isVertical ?? false) ? 1 : 0,
          'posX': datePreset?.posX ?? 0.5,
          'posY': datePreset?.posY ?? 0.5,
          'displayFormat': 'yyyy/MM/dd',
        };

        batch.insert(
            'date_slot_detail',
            SchemaManager.instance
                .sanitize('date_slot_detail', dateDetailData));

        // ========================================
        // text_item_list + text_item_detail (20個)
        // ========================================
        for (var j = 0; j < 20; j++) {
          final itemIndex = j + 1;
          final preset = DefaultPresets.presetMap[i]?[j];

          // text_item_list
          final itemListData = <String, dynamic>{
            'slotIndex': slotIndex,
            'itemIndex': itemIndex,
            'enabled': preset?.enabled == true ? 1 : 0,
            'name': preset?.label ?? 'カスタマイズ',
          };

          batch.insert('text_item_list',
              SchemaManager.instance.sanitize('text_item_list', itemListData));

          // text_item_detail
          final itemDetailData = <String, dynamic>{
            'slotIndex': slotIndex,
            'itemIndex': itemIndex,
            'label': preset?.label ?? '',
            'font': preset?.font ?? 'Arial',
            'fontSize': preset?.fontSize ?? 60,
            'color': preset?.color ?? '#FF000000',
            'backgroundColor': preset?.backgroundColor ?? '#00000000',
            'isVertical': (preset?.isVertical ?? false) ? 1 : 0,
            'posX': preset?.posX ?? 0.5,
            'posY': preset?.posY ?? 0.5,
          };

          batch.insert(
              'text_item_detail',
              SchemaManager.instance
                  .sanitize('text_item_detail', itemDetailData));
        }
      }

      await batch.commit(noResult: true);
    });

    appLog('✅ insertDefaults: 全プリセットデータ作成完了');
  }

  Future<void> updateSlotList(
    int slotIndex,
    Map<String, dynamic> data,
    String mode,
  ) async {
    final db = await _dbService.database;
    String table;
    if (mode == 'text') {
      table = 'text_slot_list'; // ✅ 修正
    } else if (mode == 'numeric') {
      table = 'numeric_slot_list'; // ✅ 修正
    } else if (mode == 'date') {
      table = 'date_slot_list'; // ✅ 修正
    } else {
      appLog('⚠️ updateSlotList: unknown mode $mode');
      return;
    }

    final clean = SchemaManager.instance.sanitize(table, data);
    await db.update(
      table,
      clean,
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );
    appLog('✏️ updateSlot: $mode#$slotIndex');
  }

  /// スロット詳細設定を更新（numeric_slot_detail / date_slot_detail）
  Future<void> updateSlotDetail(
    int slotIndex,
    Map<String, dynamic> data,
    String mode,
  ) async {
    final db = await _dbService.database;
    String table;
    if (mode == 'numeric') {
      table = 'numeric_slot_detail';
    } else if (mode == 'date') {
      table = 'date_slot_detail';
    } else {
      appLog('⚠️ updateSlotDetail: mode $mode does not have detail table');
      return;
    }

    final clean = SchemaManager.instance.sanitize(table, data);
    await db.update(
      table,
      clean,
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );
    appLog('✏️ updateSlotDetail: $mode#$slotIndex');
  }

  Future<Map<String, dynamic>?> getTextSlot(int slotIndex) async {
    final db = await _dbService.database;
    final result = await db.query(
      'text_slot_list', // ✅ 修正
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );

    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first);
  }

  Future<Map<String, dynamic>?> getNumericSlot(int slotIndex) async {
    final db = await _dbService.database;
    final result = await db.query(
      'numeric_slot_list', // ✅ 修正
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );

    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first);
  }

  Future<Map<String, dynamic>?> getDateSlot(int slotIndex) async {
    final db = await _dbService.database;
    final result = await db.query(
      'date_slot_list', // ✅ 修正
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );

    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first);
  }

  Future<List<Map<String, dynamic>>> getTextItems(int slotIndex) async {
    final db = await _dbService.database;
    final result = await db.query(
      'text_item_list', // ✅ 修正
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
      orderBy: 'itemIndex ASC',
    );

    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// text_item_detail を1件取得
  Future<Map<String, dynamic>?> getTextItemDetail(
    int slotIndex,
    int itemIndex,
  ) async {
    final db = await _dbService.database;

    final result = await db.query(
      'text_item_detail',
      where: 'slotIndex = ? AND itemIndex = ?',
      whereArgs: [slotIndex, itemIndex],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Map<String, dynamic>.from(result.first);
  }

  Future<void> updateTextItemField(
    int slotIndex,
    int itemIndex,
    String fieldName,
    dynamic value,
  ) async {
    final db = await _dbService.database;
    await db.update(
      'text_item_detail', // ✅ 修正
      {fieldName: value},
      where: 'slotIndex = ? AND itemIndex = ?',
      whereArgs: [slotIndex, itemIndex],
    );
  }

  Future<Map<String, dynamic>> getSlotDetail(int slotIndex, String mode) async {
    final db = await _dbService.database;

    String table;
    if (mode == 'numeric') {
      table = 'numeric_slot_detail';
    } else if (mode == 'date') {
      table = 'date_slot_detail';
    } else {
      appLog('⚠️ getSlotDetail: mode $mode has no detail table');
      return {};
    }

    final result = await db.query(
      table,
      where: 'slotIndex = ?',
      whereArgs: [slotIndex],
    );

    if (result.isEmpty) {
      appLog('⚠️ getSlotDetail: no detail found for $mode#$slotIndex');
      return {};
    }

    return Map<String, dynamic>.from(result.first);
  }

  /// デバッグ用：text_item の詳細を確認
  /// デバッグ用：text_item の詳細を確認
  Future<void> debugTextItems(int slotIndex) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
    SELECT 
      list.slotIndex, 
      list.itemIndex, 
      list.name, 
      list.enabled,
      detail.label,
      detail.fontSize,
      detail.color
    FROM text_item_list as list
    LEFT JOIN text_item_detail as detail 
      ON list.slotIndex = detail.slotIndex 
      AND list.itemIndex = detail.itemIndex
    WHERE list.slotIndex = ?
    ORDER BY list.itemIndex
  ''', [slotIndex]);

    appLog('📊 Debug text_item for slot $slotIndex:');
    for (final row in result) {
      appLog(
          '  #${row['itemIndex']}: name="${row['name']}", label="${row['label']}", enabled=${row['enabled']}');
    }
  }
  // ============================================================
  // ✅ バックアップ・リストア用メソッド
  // ============================================================

  /// 全データ取得（バックアップ用）
  Future<List<Map<String, dynamic>>> getAllFromTable(String tableName) async {
    final db = await _dbService.database;
    final result = await db.query(tableName);
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 全データ復元（リストア用: 全削除 → 一括挿入）
  Future<void> restoreTable(
    String tableName,
    List<Map<String, dynamic>> data,
  ) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      // 既存データを全削除
      await txn.delete(tableName);

      // 新データを一括挿入
      for (final row in data) {
        final clean = SchemaManager.instance.sanitize(tableName, row);
        await txn.insert(tableName, clean);
      }
    });

    appLog('✅ restoreTable: $tableName (${data.length}件)');
  }
//////////////////////////////////
}
