// lib/providers/series_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DB/DAO/series_list_dao.dart';
import '../../DB/Repository/series_repository.dart';
import '../utils/logger.dart';
import '../utils/app_lock.dart';
import '../providers/cards_provider.dart';

/// ✅ シリーズ一覧画面の状態
class SeriesState {
  final List<Map<String, dynamic>> seriesList;

  const SeriesState({this.seriesList = const []});

  SeriesState copyWith({
    List<Map<String, dynamic>>? seriesList,
  }) {
    return SeriesState(
      seriesList: seriesList ?? this.seriesList,
    );
  }
}

/// ✅ Notifier
class SeriesNotifier extends Notifier<SeriesState> {
  @override
  SeriesState build() {
    return const SeriesState();
  }

  final lzSeriesListDao = SeriesListDao.instance;
  final lzSeriesRepository = SeriesRepository.instance;

  Future<void> reorderSeries(int oldIndex, int newIndex) async {
    final list = [...state.seriesList];

    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    state = state.copyWith(seriesList: list); //再描写

    final ids = list.map((e) => e['id'] as String).toList();
    await lzSeriesListDao.updateOrderByIds(ids);
  }

  Future<void> loadSeriesList() async {
    final list = await lzSeriesListDao.getAllSeriesList();
    state = state.copyWith(seriesList: list);
  }

  Future<void> deleteSeries(String seriesId) async {
    final lock = LockManager.instance;

    if (!lock.canSeries(seriesId)) {
      appLog('deleteSeries: ロック中 seriesId=$seriesId');
      throw Exception('Series is locked');
    }

    lock.startSeries(seriesId);

    // ✅ ref を使う処理を事前にキャプチャ
    void removeFromCache() =>
        ref.read(cacheManagerProvider).removeSeriesCards(seriesId);
    void invalidateCardsAll() => ref.invalidate(cardsProvider("ALL"));

    try {
      appLog('SeriesListNotifier: シリーズ削除開始 - ID: $seriesId');

      await lzSeriesRepository.deleteSeriescard(seriesId);
      await loadSeriesList();

      removeFromCache();
      invalidateCardsAll();
      appLog('SeriesNotifier: cardsProvider("ALL") 無効化 (delete)');

      appLog('SeriesNotifier: シリーズ削除完了');
    } catch (e, st) {
      appLog('SeriesNotifier: deleteSeries 失敗: $e\n$st');
      rethrow;
    } finally {
      lock.endSeries(seriesId);
    }
  }
}

/// ✅ Provider
final seriesProvider = NotifierProvider<SeriesNotifier, SeriesState>(
  SeriesNotifier.new,
);
