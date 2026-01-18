import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'pages/home_ui.dart';
import 'DB/CORE/local_db_service.dart';
import 'DB/models/schema_manager.dart';
import 'utils/logger.dart';
import 'constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'DB/DAO/urlblocklist_dao.dart';
import 'utils/app_lock.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:sqflite/sqflite.dart';
import 'DB/DAO/preset_dao.dart';
import '../providers/sharedpreferences_provider.dart';
// import 'services/ad_service.dart';
// import 'package:flutter/foundation.dart';
// import 'dart:io';
// 🟦 デスクトップ用 SQLite 初期化に必要
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🟥 GoogleSignIn 初期化は削除（backup_ui.dart でのみ行う）
  // appLog('ℹ️ GoogleSignIn 初期化は backup_ui.dart に移動済み');

  // 🟥 広告は Android / iOS のみ
  // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  //   await AdService.initialize();
  //   appLog('✅ AdService 初期化完了');
  // } else {
  //   appLog('ℹ️ このプラットフォームでは AdService をスキップ');
  // }
// 🟦 デスクトップ（Windows / macOS / Linux）用 SQLite 初期化
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    appLog('🟦 sqflite_common_ffi 初期化完了（デスクトップ）');
  }
  runApp(const ProviderScope(child: CardCollectionApp()));
}

class CardCollectionApp extends StatelessWidget {
  const CardCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
      ],
      home: const AppInitializer(),
      debugShowCheckedModeBanner: !AppConstants.isDebug,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    final db = await LocalDBService.instance.database;
    await SchemaManager.instance.initialize(db);

    LockManager.instance.resetAll();
    appLog("🔓 LockManager: 全ロック解除(アプリ起動)");

    final container = ProviderContainer();
    await container
        .read(sharedpreferencesProvider.notifier)
        .setLayerWidgetValid(false);
    container.dispose();
    appLog("🔄 layerWidgetValid をリセット(アプリ起動)");

    try {
      final dao = UrlBlocklistDao();
      await dao.purgeOldEntries();
      appLog('🧹 URLブロックリストの古いデータ削除(初回起動)');
    } catch (e) {
      appLog('❌ URLブロックリスト削除失敗: $e');
    }

    try {
      await _initializePresets(db);
    } catch (e, st) {
      appLog('❌ Preset初期化失敗: $e\n$st');
    }

    // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    //   try {
    //     await AdService().loadInterstitialAd();
    //     appLog('✅ インタースティシャル広告読み込み開始');
    //   } catch (e) {
    //     appLog('❌ 広告読み込み失敗: $e');
    //   }
    // } else {
    //   appLog('ℹ️ このプラットフォームでは広告読み込みをスキップ');
    // }

    appLog("起動処理完了");
  }

  Future<void> _initializePresets(Database db) async {
    const expectedCounts = {
      'text_slot_list': 6,
      'text_item_list': 120,
      'text_item_detail': 120,
      'numeric_slot_list': 6,
      'numeric_slot_detail': 6,
      'date_slot_list': 6,
      'date_slot_detail': 6,
    };

    bool needsReset = false;

    for (final entry in expectedCounts.entries) {
      final table = entry.key;
      final expected = entry.value;

      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
      final actual = (result.first['cnt'] as int?) ?? 0;

      if (actual != expected) {
        appLog('⚠️ $table: レコード数不一致(想定: $expected, 実際: $actual)');
        needsReset = true;
      }
    }

    if (needsReset) {
      appLog('🔄 Presetデータ再構築開始');
      await PresetDao.instance.deleteAllPresets();
      await PresetDao.instance.insertDefaults();
      appLog('✅ Presetデータ再構築完了');
    } else {
      appLog('✅ Preset整合性チェックOK(再構築不要)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'エラーが発生しました\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return const HomeUi();
        } else {
          return const SplashScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'バックアップは手動で行う必要があるので、\n必要に応じて行ってください\n\nBackups must be performed manually.\nPlease execute as needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, color: Color.fromARGB(255, 1, 27, 59)),
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: AppConstants.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
