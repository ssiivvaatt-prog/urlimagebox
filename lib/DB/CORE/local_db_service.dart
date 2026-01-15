import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../utils/logger.dart';
import '../models/schema.dart';

class LocalDBService {
  static final LocalDBService instance = LocalDBService._internal();
  LocalDBService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    // 🟦 Windows の場合は FFI 版 SQLite を使う
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      appLog('🖥️ Windows: sqflite_common_ffi を使用');
    }

    final dbPath = await getDatabasesPath();

    final existing = await _findExistingDB(dbPath);
    final path = existing ?? await _createNewDBName(dbPath);

    appLog('📦 DB path: $path');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        appLog('🆕 Creating tables...');

        await db.execute(Schema.createSeriesListTable);
        await db.execute(Schema.createSeriesConfigTable);
        await db.execute(Schema.createCardsTable);

        await db.execute(Schema.createTextSlotListTable);
        await db.execute(Schema.createTextItemListTable);
        await db.execute(Schema.createTextItemDetailTable);

        await db.execute(Schema.createNumericSlotListTable);
        await db.execute(Schema.createNumericSlotDetailTable);

        await db.execute(Schema.createDateSlotListTable);
        await db.execute(Schema.createDateSlotDetailTable);

        await db.execute(Schema.createUrlBlocklistTable);
        await db.execute(Schema.createMetaTable);

        appLog('✅ All tables created successfully.');
      },
    );

    return _db!;
  }

  Future<String?> _findExistingDB(String dbPath) async {
    final dir = Directory(dbPath);

    if (await dir.exists()) {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.contains('card_collection_') && f.path.endsWith('.db'))
          .toList();

      if (files.isNotEmpty) {
        appLog('📂 Existing DB found: ${basename(files.first.path)}');
        return files.first.path;
      }
    }

    return null;
  }

  Future<String> _createNewDBName(String dbPath) async {
    final now = DateTime.now();
    final timestamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final newPath = join(dbPath, 'card_collection_$timestamp.db');
    appLog('🆕 No existing DB found, creating new one: $newPath');
    return newPath;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      appLog('🛑 LocalDB closed manually');
    } else {
      appLog('⚠️ LocalDB.close() called, but DB was not open');
    }
  }
}
