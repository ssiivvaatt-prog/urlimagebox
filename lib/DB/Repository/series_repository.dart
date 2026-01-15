import '../DAO/series_list_dao.dart';
import '../DAO/series_config_dao.dart';
// import '../DAO/series_filter_dao.dart';
import '../DAO/cards_dao.dart';
import '../../utils/app_lock.dart';
import '../../utils/logger.dart';

/// ------------------------------------------------------------
/// SeriesRepository
/// ------------------------------------------------------------
/// - 「シリーズ」という概念を扱うユースケース層
/// - 複数 DAO をまとめて、UI に分かりやすい操作を提供する
/// - DAO はテーブル単位、Repository はユースケース単位
/// ------------------------------------------------------------
class SeriesRepository {
  static final SeriesRepository instance = SeriesRepository._internal();
  SeriesRepository._internal();

  final _listDao = SeriesListDao.instance;
  final _configDao = SeriesConfigDao.instance;
  // final _filterDao = SeriesFilterDao.instance;
  final _cardsDao = CardsDao.instance;

  /// ------------------------------------------------------------
  /// シリーズ作成
  /// - series_list に追加
  /// - series_config の初期値作成
  /// - series_filter の初期値作成
  /// - cards の初期番号セット作成
  /// ------------------------------------------------------------
  // }

  /// ------------------------------------------------------------
  /// シリーズ削除
  /// - cards → config → filter → list の順で削除
  /// ------------------------------------------------------------
  Future<void> deleteSeriescard(String id) async {
    // 1. cards 削除
    await _cardsDao.deleteBySeriesId(id);

    // 2. config 削除
    await _configDao.deleteConfig(id);

    // 3. filter 削除
    // await _filterDao.deleteFilter(id);

    // 4. series_list 削除
    await _listDao.deleteSeriesList(id);

    appLog('🗑 SeriesRepository.deleteSeries: $id (all related data removed)');
  }

  /// ------------------------------------------------------------
  /// シリーズ読み込み（編集・複製用）　edit画面用
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>?> loadSeries(String id) async {
    // ✅ series_list（基本情報）
    final list = await _listDao.getSeriesListById(id);
    if (list == null) return null;

    // ✅ series_config（設定）
    final config = await _configDao.getConfigById(id);

    // ✅ series_filter（フィルター設定）
    // final filter = await _filterDao.getFilterById(id);

    return {
      'list': list,
      'config': config,
      // 'filter': filter,
    };
  }

  Future<void> saveSeries({
    required String mode,
    required Map<String, dynamic> listData,
    required Map<String, dynamic> configData,
    // required Map<String, dynamic> filterData,
    String? originalSeriesId,
  }) async {
    final lock = LockManager.instance;

    // ========== ロックチェック ==========
    if (mode != "create") {
      if (originalSeriesId == null) {
        appLog("saveSeries: originalSeriesId が null（異常） mode=$mode");
        throw Exception('originalSeriesId is required for edit/duplicate');
      }

      if (!lock.canSeries(originalSeriesId)) {
        appLog("saveSeries: ロック中 original=$originalSeriesId");
        throw Exception('Series is locked');
      }
    }

    // ========== ロック開始 ==========
    if (mode == "edit" || mode == "duplicate") {
      lock.startSeries(originalSeriesId!);
    }
    if (mode == "duplicate") {
      lock.startSeries(listData['id']);
    }

    try {
      appLog('════════════════════════════════════════');
      appLog('SeriesRepository: saveSeries 開始');
      appLog('  → mode: $mode');
      appLog('════════════════════════════════════════');

      final newSeriesId = listData['id'] as String;
      final newFrom = configData['fromNum'] as int;
      final newTo = configData['toNum'] as int;

      // ========== 旧データ取得（edit/duplicate用） ==========
      Map<String, dynamic>? oldConfig;
      bool sameUrlConfig = true;

      if (mode == "edit" || mode == "duplicate") {
        oldConfig = await _configDao.getConfigById(originalSeriesId!);

        if (oldConfig != null) {
          final beforeSame =
              oldConfig['baseUrlBefore'] == configData['baseUrlBefore'];
          final afterSame =
              oldConfig['baseUrlAfter'] == configData['baseUrlAfter'];
          final digitSame = oldConfig['digitCount'] == configData['digitCount'];
          final padSame =
              oldConfig['zeroPadEnabled'] == configData['zeroPadEnabled'];

          sameUrlConfig = beforeSame && afterSame && digitSame && padSame;

          appLog('SeriesRepository: URL構成比較結果: $sameUrlConfig');
          appLog('  → before: ${beforeSame ? "一致" : "不一致"}');
          appLog('  → after : ${afterSame ? "一致" : "不一致"}');
          appLog('  → digit : ${digitSame ? "一致" : "不一致"}');
          appLog('  → pad   : ${padSame ? "一致" : "不一致"}');
        }
      }

      // ========== DB保存 ==========
      if (mode == 'create') {
        await _listDao.insertSeriesList(listData);
        await _configDao.insertConfig(configData);
        // await _filterDao.insertDefaultFilter(listData['id']);
        appLog("SeriesRepository: 新規作成完了");
      }

      if (mode == 'edit') {
        await _listDao.updateSeriesList(originalSeriesId!, listData);
        await _configDao.updateConfig(originalSeriesId, configData);
        // await _filterDao.updateFilter(originalSeriesId, filterData);
        appLog("SeriesRepository: 編集保存完了");

        // ========== カード処理（edit） ==========
        if (!sameUrlConfig) {
          // URL構成が変わった → 全削除
          await _cardsDao.deleteBySeriesId(originalSeriesId);
          appLog("SeriesRepository: URL構成変更 → カード全削除");
        } else {
          // 範囲外だけ削除
          await _cardsDao.deleteOutOfRange(
            seriesId: originalSeriesId,
            from: newFrom,
            to: newTo,
          );
          appLog("SeriesRepository: 範囲外カード削除");
        }
      }

      if (mode == 'duplicate') {
        await _listDao.insertSeriesList(listData);
        await _configDao.insertConfig(configData);
        // await _filterDao.insertFilter(filterData);
        appLog("SeriesRepository: 複製保存完了");

        // ========== カード複製処理 ==========
        if (sameUrlConfig) {
          int copied = 0;

          for (int num = newFrom; num <= newTo; num++) {
            final oldCard = await _cardsDao.getCardBySeriesAndNumber(
              originalSeriesId!,
              num,
            );

            if (oldCard != null) {
              final newCard = Map<String, dynamic>.from(oldCard)
                ..['seriesId'] = newSeriesId;

              await _cardsDao.insertOrReplace(newCard);
              copied++;
            }
          }

          appLog("SeriesRepository: 複製完了 - $copied枚コピー");
        } else {
          appLog("SeriesRepository: URL構成不一致 → カード複製なし");
        }
      }

      appLog("SeriesRepository: saveSeries 完了");
      appLog('════════════════════════════════════════\n');
    } catch (e, st) {
      appLog("SeriesRepository: saveSeries エラー: $e");
      appLog("スタックトレース:\n$st");
      rethrow;
    } finally {
      // ========== ロック解除 ==========
      if (mode == "edit" || mode == "duplicate") {
        lock.endSeries(originalSeriesId!);
      }
      if (mode == "duplicate") {
        lock.endSeries(listData['id']);
      }
    }
  }
}
