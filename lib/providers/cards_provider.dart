// lib/providers/cards_provider.dart

import '../DB/DAO/series_list_dao.dart';
//aaaa
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import '../utils/app_lock.dart';
import 'dart:io';
import '../../DB/DAO/cards_dao.dart';
import '../../DB/DAO/preset_dao.dart';
import '/providers/sharedpreferences_provider.dart';
import '../services/card_generation_service.dart';
import '../DB/DAO/urlblocklist_dao.dart';
import '../services/network_service.dart';
import '../DB/Repository/series_repository.dart';

/// ============================================================
/// CardsState（Family 対応版）
/// ============================================================
class CardsState {
  final String seriesId;
  final Map<String, Map<String, dynamic>> cards;

  final double progress; // 0.0〜1.0
  final bool isLoading;
  final Map<String, int> sortIndexMap;
  final Map<String, String> seriesNameMap;

  const CardsState({
    required this.seriesId,
    this.cards = const {},
    this.progress = 0.0,
    this.isLoading = false,
    this.sortIndexMap = const {},
    this.seriesNameMap = const {},
  });

  CardsState copyWith({
    Map<String, Map<String, dynamic>>? cards,
    double? progress,
    bool? isLoading,
    Map<String, int>? sortIndexMap,
    Map<String, String>? seriesNameMap,
  }) {
    return CardsState(
      seriesId: seriesId,
      cards: cards ?? this.cards,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      sortIndexMap: sortIndexMap ?? this.sortIndexMap,
      seriesNameMap: seriesNameMap ?? this.seriesNameMap,
    );
  }

  bool get isReady => !isLoading && progress >= 1.0;
}

/// ============================================================
/// CardsNotifier（Family 対応版）
/// ============================================================
class CardsNotifier extends Notifier<CardsState> {
  final String seriesId;

  CardsNotifier(this.seriesId);

  final lzCardDao = CardsDao.instance;
  final lzPresetDao = PresetDao.instance;

  @override
  CardsState build() {
    // ✅ seriesId ごとに独立した state
    return CardsState(seriesId: seriesId);
  }

  // prepareCards メソッドの修正版（一部抜粋）

// ============================================================
// ✅ prepareCards（このシリーズ専用）
// ============================================================
  // prepareCards メソッドの修正版（一部抜粋）

// ============================================================
// ✅ prepareCards（このシリーズ専用）
// ============================================================
  Future<void> prepareCards() async {
    final seriesId = state.seriesId;
    if (state.isReady) {
      appLog('prepareCards: すでに準備済み → スキップ seriesId=$seriesId');
      return;
    }

    state = state.copyWith(progress: 0.0, isLoading: true);

    // ✅ "ALL" の場合は全シリーズのカードを取得
    if (seriesId == "ALL") {
      await _prepareAllCards();
      return;
    }

    // ========================================
    // 通常のシリーズ処理
    // ========================================
    final lock = LockManager.instance;

    if (!lock.canSeries(seriesId)) {
      appLog('prepareCards: ロック中のため実行不可 seriesId=$seriesId');
      return;
    }
    appLog('prepareCards: ロック開始 seriesId=$seriesId');
    lock.startSeries(seriesId);

    appLog('prepareCards start: $seriesId');
    try {
      final seriesData = await SeriesRepository.instance.loadSeries(seriesId);
      if (seriesData == null) {
        appLog('⚠️ prepareCards: シリーズが見つかりません seriesId=$seriesId');
        return;
      }

      final series = seriesData['config'] as Map<String, dynamic>;

      final from = series['fromNum'] as int;
      final to = series['toNum'] as int;
      final before = (series['baseUrlBefore'] ?? '') as String;
      final after = (series['baseUrlAfter'] ?? '') as String;
      final digitCount = (series['digitCount'] ?? 3) as int;
      final zeroPad = (series['zeroPadEnabled'] ?? 1) == 1;

      final blockDao = UrlBlocklistDao();
      final generator = CardGenerationService();
      final network = NetworkService();

      Map<String, Map<String, dynamic>> existing = {};

      final rows = await lzCardDao.getCardsBySeriesId(seriesId);
      for (final row in rows) {
        existing[row['number'].toString()] = Map<String, dynamic>.from(row);
      }

      appLog('📄 prepareCards: DB から ${existing.length} 枚読み込み');

      // ✅ UIに反映
      state = state.copyWith(cards: existing);

      // --- from〜to をループ ---
      final total = to - from + 1;
      int processed = 0;

      for (int number = from; number <= to; number++) {
        processed++;
        final p = processed / total;
        state = state.copyWith(progress: p);

        final numStr = zeroPad
            ? number.toString().padLeft(digitCount, '0')
            : number.toString();

        final url = '$before$numStr$after';
        final key = number.toString();

        final card = existing[key];
        final existsCard = card != null;

        // =============================
        // 🟦 新規カード作成
        // =============================
        if (!existsCard) {
          if (await blockDao.isBlocked(url)) {
            appLog('🚫 Blocked → skip $url');
            continue;
          }

          final exists = await network.checkImageExists(url);
          if (!exists) {
            appLog('❌ URLなし → block & skip $url');
            await blockDao.addOrUpdate(url, '404');
            continue;
          }

          final cardData = {
            'seriesId': seriesId,
            'number': number,
            'attr1': 0,
            'attr2': 0,
            'attr3': 0,
            'attr4': 0,
            'attr5': 0,
            'attr6': 0,
            'numeric1': 0,
            'numeric2': 0,
            'numeric3': 0,
            'numeric4': 0,
            'numeric5': 0,
            'numeric6': 0,
            'date1': 0,
            'date2': 0,
            'date3': 0,
            'date4': 0,
            'date5': 0,
            'date6': 0,
            'rotationAngle': 0,
            'imageUrl': url,
            'imagePath': '',
          };

          await lzCardDao.insertOrReplace(cardData);
          existing[key] = cardData;

          state = state.copyWith(cards: Map.from(existing));

          final newPath = await generator.generateCacheFromUrl(url);

          if (newPath != null) {
            existing[key] = {
              ...cardData,
              'imagePath': newPath,
            };
            await lzCardDao.updateImagePath(seriesId, number, newPath);
            state = state.copyWith(cards: Map.from(existing));
            appLog('prepareCards キャッシュセット: $seriesId #$number');
          }

          continue;
        }

        // =============================
        // 🟩 既存カード
        // =============================
        final currentPath = card['imagePath'] as String? ?? '';

        if (currentPath.isNotEmpty) continue;

        final newPath = await generator.generateCacheFromUrl(url);

        if (newPath != null) {
          existing[key] = {
            ...card,
            'imagePath': newPath,
          };
          await lzCardDao.updateImagePath(seriesId, number, newPath);
          state = state.copyWith(cards: Map.from(existing));
          appLog('prepareCards キャッシュセット: $seriesId #$number');
        }
      }

      appLog('prepareCards 完了: ${existing.length} 枚');
    } finally {
      lock.endSeries(seriesId);
      appLog('prepareCards: ロック解除 seriesId=$seriesId');
      state = state.copyWith(progress: 1.0, isLoading: false);
    }
  }

  // ============================================================
  // ✅ 全シリーズのカードを準備（ALL 専用）
  // ============================================================
  Future<void> _prepareAllCards() async {
    appLog('_prepareAllCards: 全シリーズのカード準備開始');

    final lock = LockManager.instance;

    // ========================================
    // 排他制御: グローバルロック + 全シリーズチェック
    // ========================================
    if (!lock.canGlobal()) {
      appLog('_prepareAllCards: グローバルロック中のため実行不可');
      return;
    }

    // ✅ 全シリーズIDを取得
    final allSeriesList = await SeriesListDao.instance.getAllSeriesList();
    final allSeriesIds = allSeriesList.map((s) => s['id'] as String).toList();

    // ✅ いずれかのシリーズがロック中ならスキップ
    for (final seriesId in allSeriesIds) {
      if (!lock.canSeries(seriesId)) {
        appLog('_prepareAllCards: シリーズ $seriesId がロック中 → 中断');
        return;
      }
    }

    // ✅ グローバルロック開始
    lock.startGlobal();
    appLog('_prepareAllCards: グローバルロック開始');

// 全シリーズ一覧を取得
    final seriesList = await SeriesListDao.instance.getAllSeriesList();

// seriesId → sortIndex, seriesId → seriesName のマップを作成
    final sortIndexMap = <String, int>{};
    final seriesNameMap = <String, String>{};

    for (final s in seriesList) {
      final id = s['id'] as String;
      sortIndexMap[id] = s['sortIndex'] as int? ?? 0;
      seriesNameMap[id] = s['name'] as String? ?? '';
    }

// state に保存
    state = state.copyWith(
      sortIndexMap: sortIndexMap,
      seriesNameMap: seriesNameMap,
    );

    try {
      // ========================================
      // ✅ 総カード数を事前計算
      // ========================================
      int totalCards = 0;
      for (final seriesId in allSeriesIds) {
        final seriesData = await SeriesRepository.instance.loadSeries(seriesId);
        if (seriesData != null) {
          final config = seriesData['config'] as Map<String, dynamic>;
          final from = config['fromNum'] as int;
          final to = config['toNum'] as int;
          totalCards += (to - from + 1);
        }
      }

      appLog('_prepareAllCards: 総カード数 $totalCards 枚');

      int processedCards = 0;

      // ========================================
      // 全シリーズをループ処理
      // ========================================
      for (final seriesId in allSeriesIds) {
        appLog('_prepareAllCards: シリーズ処理開始 ($seriesId)');

        // ========================================
        // シリーズごとのロック（念のため）
        // ========================================
        lock.startSeries(seriesId);

        try {
          final seriesData =
              await SeriesRepository.instance.loadSeries(seriesId);
          if (seriesData == null) {
            appLog('⚠️ _prepareAllCards: シリーズが見つかりません seriesId=$seriesId');
            continue;
          }

          final series = seriesData['config'] as Map<String, dynamic>;

          final from = series['fromNum'] as int;
          final to = series['toNum'] as int;
          final before = (series['baseUrlBefore'] ?? '') as String;
          final after = (series['baseUrlAfter'] ?? '') as String;
          final digitCount = (series['digitCount'] ?? 3) as int;
          final zeroPad = (series['zeroPadEnabled'] ?? 1) == 1;

          final blockDao = UrlBlocklistDao();
          final generator = CardGenerationService();
          final network = NetworkService();

          Map<String, Map<String, dynamic>> existing = {};

          final rows = await lzCardDao.getCardsBySeriesId(seriesId);
          for (final row in rows) {
            existing[row['number'].toString()] = Map<String, dynamic>.from(row);
          }

          appLog(
              '📄 _prepareAllCards: DB から ${existing.length} 枚読み込み ($seriesId)');

          // --- from〜to をループ ---
          for (int number = from; number <= to; number++) {
            // ✅ カード1枚ごとに進捗更新
            processedCards++;
            final p = totalCards > 0 ? processedCards / totalCards : 1.0;
            state = state.copyWith(progress: p);

            final numStr = zeroPad
                ? number.toString().padLeft(digitCount, '0')
                : number.toString();

            final url = '$before$numStr$after';
            final key = number.toString();

            final card = existing[key];
            final existsCard = card != null;

            // =============================
            // 🟦 新規カード作成
            // =============================
            if (!existsCard) {
              if (await blockDao.isBlocked(url)) {
                appLog('🚫 Blocked → skip $url');
                continue;
              }

              final exists = await network.checkImageExists(url);
              if (!exists) {
                appLog('❌ URLなし → block & skip $url');
                await blockDao.addOrUpdate(url, '404');
                continue;
              }

              final cardData = {
                'seriesId': seriesId,
                'number': number,
                'attr1': 0,
                'attr2': 0,
                'attr3': 0,
                'attr4': 0,
                'attr5': 0,
                'attr6': 0,
                'numeric1': 0,
                'numeric2': 0,
                'numeric3': 0,
                'numeric4': 0,
                'numeric5': 0,
                'numeric6': 0,
                'date1': 0,
                'date2': 0,
                'date3': 0,
                'date4': 0,
                'date5': 0,
                'date6': 0,
                'rotationAngle': 0,
                'imageUrl': url,
                'imagePath': '',
              };

              await lzCardDao.insertOrReplace(cardData);
              existing[key] = cardData;

              // キャッシュ生成
              final newPath = await generator.generateCacheFromUrl(url);

              if (newPath != null) {
                existing[key] = {
                  ...cardData,
                  'imagePath': newPath,
                };
                await lzCardDao.updateImagePath(seriesId, number, newPath);
                appLog('_prepareAllCards キャッシュセット: $seriesId #$number');
              }

              continue;
            }

            // =============================
            // 🟩 既存カード
            // =============================
            final currentPath = card['imagePath'] as String? ?? '';

            if (currentPath.isNotEmpty) continue;

            final newPath = await generator.generateCacheFromUrl(url);

            if (newPath != null) {
              existing[key] = {
                ...card,
                'imagePath': newPath,
              };
              await lzCardDao.updateImagePath(seriesId, number, newPath);
              appLog('_prepareAllCards キャッシュセット: $seriesId #$number');
            }
          }

          appLog('_prepareAllCards: シリーズ完了 $seriesId (${existing.length} 枚)');
        } finally {
          lock.endSeries(seriesId);
        }
      }

      // ========================================
      // 全カード取得して state に反映
      // ========================================
      final allCards = await lzCardDao.getAllCards();
      final cardsMap = <String, Map<String, dynamic>>{};

      for (final card in allCards) {
        final key = '${card['seriesId']}_${card['number']}';
        cardsMap[key] = card;
      }

      state = state.copyWith(cards: cardsMap);

      appLog('_prepareAllCards: 完了 - 総カード数: ${cardsMap.length}');
    } catch (e, st) {
      appLog('❌ _prepareAllCards error: $e\n$st');
    } finally {
      lock.endGlobal();
      appLog('_prepareAllCards: グローバルロック解除');
      state = state.copyWith(progress: 1.0, isLoading: false);
    }
  }

  // ============================================================
  // ✅ カード個別更新（seriesId は state から取得）
  // ============================================================
  Future<void> updateCardDate(
    String cardSeriesId,
    int number,
    int slotIndex,
    int value,
  ) async {
    try {
      // ✅ DB更新
      await lzCardDao.updateField(
        cardSeriesId,
        number,
        'date$slotIndex',
        value,
      );

      final cardKey = state.seriesId == "ALL"
          ? '${cardSeriesId}_$number' // ALL の場合
          : number.toString(); // 個別シリーズの場合

      final updatedCards = Map<String, Map<String, dynamic>>.from(state.cards);
      final card = Map<String, dynamic>.from(updatedCards[cardKey] ?? {});

      if (card.isEmpty) {
        appLog('⚠️ updateCardDate: カードが見つかりません key=$cardKey');
        return;
      }

      card['date$slotIndex'] = value;
      updatedCards[cardKey] = card;

      state = state.copyWith(cards: updatedCards);

      appLog(
          '✅ updateCardDate: $cardSeriesId #$number date$slotIndex = $value');
    } catch (e, st) {
      appLog('❌ updateCardDate error: $e\n$st');
    }
  }

  Future<void> updateCardNumeric(
    String cardSeriesId,
    int number,
    int slotIndex,
    int value,
  ) async {
    try {
      // ✅ DB更新
      await lzCardDao.updateField(
        cardSeriesId,
        number,
        'numeric$slotIndex',
        value,
      );

      final cardKey = state.seriesId == "ALL"
          ? '${cardSeriesId}_$number' // ALL の場合
          : number.toString(); // 個別シリーズの場合

      final updatedCards = Map<String, Map<String, dynamic>>.from(state.cards);
      final card = Map<String, dynamic>.from(updatedCards[cardKey] ?? {});

      if (card.isEmpty) {
        appLog('⚠️ updateCardNumeric: カードが見つかりません key=$cardKey');
        return;
      }

      card['numeric$slotIndex'] = value;
      updatedCards[cardKey] = card;

      state = state.copyWith(cards: updatedCards);

      appLog(
          '✅ updateCardNumeric: $cardSeriesId #$number numeric$slotIndex = $value');
    } catch (e, st) {
      appLog('❌ updateCardNumeric error: $e\n$st');
    }
  }

  Future<void> rotateCard(
    String cardSeriesId,
    int number,
    String direction,
  ) async {
    try {
      final cardKey = state.seriesId == "ALL"
          ? '${cardSeriesId}_$number' // ALL の場合
          : number.toString(); // 個別シリーズの場合

      final card = state.cards[cardKey];
      if (card == null) {
        appLog('⚠️ rotateCard: カードが見つかりません key=$cardKey');
        return;
      }

      final currentAngle = card['rotationAngle'] ?? 0;

      final newAngle = direction == 'right'
          ? (currentAngle + 90) % 360
          : (currentAngle - 90 + 360) % 360;

      // ✅ DB更新
      await lzCardDao.updateRotationAngle(cardSeriesId, number, newAngle);

      // ✅ state更新
      final updatedCards = Map<String, Map<String, dynamic>>.from(state.cards);
      final updatedCard = Map<String, dynamic>.from(card);
      updatedCard['rotationAngle'] = newAngle;
      updatedCards[cardKey] = updatedCard;

      state = state.copyWith(cards: updatedCards);

      appLog('✅ rotateCard: $cardSeriesId #$number → $newAngle°');
    } catch (e, st) {
      appLog('❌ rotateCard error: $e\n$st');
    }
  }

  Future<void> stampCard(
    String cardSeriesId,
    int number,
    int slotIndex,
  ) async {
    try {
      final items = await lzPresetDao.getTextItems(slotIndex);

      final enabledItems = [
        0,
        ...items
            .where((item) => item['enabled'] == 1)
            .map((item) => item['itemIndex'] as int),
      ];

      final cardKey = state.seriesId == "ALL"
          ? '${cardSeriesId}_$number' // ALL の場合
          : number.toString(); // 個別シリーズの場合

      final card = state.cards[cardKey];
      if (card == null) {
        appLog('⚠️ stampCard: カードが見つかりません key=$cardKey');
        return;
      }

      final currentValue = card['attr$slotIndex'] ?? 0;

      final currentIndex = enabledItems.indexOf(currentValue);
      final nextValue = currentIndex == -1
          ? enabledItems[0]
          : enabledItems[(currentIndex + 1) % enabledItems.length];

      // ✅ DB更新
      await lzCardDao.updateCardAttr(
        seriesId: cardSeriesId,
        number: number,
        slotIndex: slotIndex,
        value: nextValue,
      );

      // ✅ state更新
      final updatedCards = Map<String, Map<String, dynamic>>.from(state.cards);
      final updatedCard = Map<String, dynamic>.from(card);
      updatedCard['attr$slotIndex'] = nextValue;
      updatedCards[cardKey] = updatedCard;

      state = state.copyWith(cards: updatedCards);

      appLog('✅ stampCard: $cardSeriesId #$number attr$slotIndex = $nextValue');
    } catch (e, st) {
      appLog('❌ stampCard error: $e\n$st');
    }
  }

  Future<void> clearCard(String cardSeriesId, int number) async {
    try {
      final cardKey = state.seriesId == "ALL"
          ? '${cardSeriesId}_$number'
          : number.toString();

      final card = state.cards[cardKey];
      if (card == null) {
        appLog('⚠️ clearCard: カードが見つかりません key=$cardKey');
        return;
      }

      // --- DB更新 ---
      await lzCardDao.updateRotationAngle(cardSeriesId, number, 0);

      for (int i = 1; i <= 6; i++) {
        await lzCardDao.updateCardAttr(
          seriesId: cardSeriesId,
          number: number,
          slotIndex: i,
          value: 0,
        );
        await lzCardDao.updateField(cardSeriesId, number, 'numeric$i', 0);
        await lzCardDao.updateField(cardSeriesId, number, 'date$i', 0);
      }

      // --- state更新（rotateCard と同じ構造） ---
      final updatedCards = Map<String, Map<String, dynamic>>.from(state.cards);
      final updatedCard = Map<String, dynamic>.from(card);

      updatedCard['rotationAngle'] = 0;
      for (int i = 1; i <= 6; i++) {
        updatedCard['attr$i'] = 0;
        updatedCard['numeric$i'] = 0;
        updatedCard['date$i'] = 0;
      }

      updatedCards[cardKey] = updatedCard;
      state = state.copyWith(cards: updatedCards);

      appLog('🧼 clearCard: $cardSeriesId #$number を初期化しました');
    } catch (e, st) {
      appLog('❌ clearCard error: $e\n$st');
    }
  }

  // ============================================================
  // ✅ モード切り替え（アプリ全体共通）
  // ============================================================
  void tapRotateButton() {
    final prefs = ref.read(sharedpreferencesProvider);
    final prefsNotifier = ref.read(sharedpreferencesProvider.notifier);
    final mode = prefs.currentMode;

    if (mode != 'rotate') {
      prefsNotifier.setCurrentMode('rotate');
      appLog('Mode: 他モード→回転モードへ');
      return;
    }

    final currentDir = prefs.currentRotateDirection;
    final newDir = currentDir == 'right' ? 'left' : 'right';

    prefsNotifier.setCurrentRotateDirection(newDir);
    appLog('Mode: 回転方向切替 $currentDir → $newDir');
  }

  void tapClearButton() {
    final prefsNotifier = ref.read(sharedpreferencesProvider.notifier);

    prefsNotifier.setCurrentMode('clear');
    appLog('Mode: クリアモードへ');
  }

  Future<List<int>> _getEnabledSlotIndexes(String mode) async {
    final List<int> enabled = [];

    for (int i = 1; i <= 6; i++) {
      Map<String, dynamic>? slot;

      if (mode == 'text') {
        slot = await lzPresetDao.getTextSlot(i);
      } else if (mode == 'numeric') {
        slot = await lzPresetDao.getNumericSlot(i);
      } else if (mode == 'date') {
        slot = await lzPresetDao.getDateSlot(i);
      }

      if (slot != null && slot['enabled'] == 1) {
        enabled.add(i);
      }
    }

    return enabled;
  }

  Future<void> tapRemarkButton() async {
    final prefs = ref.read(sharedpreferencesProvider);
    final notifier = ref.read(sharedpreferencesProvider.notifier);
    final mode = prefs.currentMode;

    final enabledSlots = await _getEnabledSlotIndexes('text');

    if (enabledSlots.isEmpty) {
      appLog('⚠️ 備考モード: 有効なスロットがありません');
      throw Exception('No enabled slots');
    }

    if (mode != 'remark') {
      notifier.setCurrentMode('remark');

      // ✅ 修正: 前回のスロット番号が有効ならそれを使う
      final lastSlot = prefs.currentAttrSlotIndex;
      final nextSlot =
          enabledSlots.contains(lastSlot) ? lastSlot : enabledSlots.first;

      notifier.setCurrentAttrSlotIndex(nextSlot);
      appLog('Mode: 他モード→備考モード（スロット$nextSlot）');
      return;
    }

    final current = prefs.currentAttrSlotIndex;
    final currentIdx = enabledSlots.indexOf(current);
    final nextIdx = (currentIdx + 1) % enabledSlots.length;
    final next = enabledSlots[nextIdx];

    notifier.setCurrentAttrSlotIndex(next);
    appLog('Remark Slot: $current → $next');
  }

  Future<void> tapNumberButton() async {
    final prefs = ref.read(sharedpreferencesProvider);
    final notifier = ref.read(sharedpreferencesProvider.notifier);
    final mode = prefs.currentMode;

    final enabledSlots = await _getEnabledSlotIndexes('numeric');

    if (enabledSlots.isEmpty) {
      appLog('⚠️ 数字モード: 有効なスロットがありません');
      throw Exception('No enabled slots');
    }

    if (mode != 'number') {
      notifier.setCurrentMode('number');

      // ✅ 修正: 前回のスロット番号が有効ならそれを使う
      final lastSlot = prefs.currentNumericSlotIndex;
      final nextSlot =
          enabledSlots.contains(lastSlot) ? lastSlot : enabledSlots.first;

      notifier.setCurrentNumericSlotIndex(nextSlot);
      appLog('Mode: 他モード→数字モード（スロット$nextSlot）');
      return;
    }

    final current = prefs.currentNumericSlotIndex;
    final currentIdx = enabledSlots.indexOf(current);
    final nextIdx = (currentIdx + 1) % enabledSlots.length;
    final next = enabledSlots[nextIdx];

    notifier.setCurrentNumericSlotIndex(next);
    appLog('Number Slot: $current → $next');
  }

  Future<void> tapDateButton() async {
    final prefs = ref.read(sharedpreferencesProvider);
    final notifier = ref.read(sharedpreferencesProvider.notifier);
    final mode = prefs.currentMode;

    final enabledSlots = await _getEnabledSlotIndexes('date');

    if (enabledSlots.isEmpty) {
      appLog('⚠️ 日付モード: 有効なスロットがありません');
      throw Exception('No enabled slots');
    }

    if (mode != 'date') {
      notifier.setCurrentMode('date');

      // ✅ 修正: 前回のスロット番号が有効ならそれを使う
      final lastSlot = prefs.currentDateSlotIndex;
      final nextSlot =
          enabledSlots.contains(lastSlot) ? lastSlot : enabledSlots.first;

      notifier.setCurrentDateSlotIndex(nextSlot);
      appLog('Mode: 他モード→日付モード（スロット$nextSlot）');
      return;
    }

    final current = prefs.currentDateSlotIndex;
    final currentIdx = enabledSlots.indexOf(current);
    final nextIdx = (currentIdx + 1) % enabledSlots.length;
    final next = enabledSlots[nextIdx];

    notifier.setCurrentDateSlotIndex(next);
    appLog('Date Slot: $current → $next');
  }

  Future<Map<String, Map<int, String>>> validateCurrentMode() async {
    final prefs = ref.read(sharedpreferencesProvider);
    final notifier = ref.read(sharedpreferencesProvider.notifier);
    final mode = prefs.currentMode;

    final Map<String, Map<int, String>> allSlotNames = {
      'text': {},
      'numeric': {},
      'date': {},
    };

    final textSlots = await _getEnabledSlotIndexes('text');
    for (final slotIndex in textSlots) {
      final slot = await lzPresetDao.getTextSlot(slotIndex);
      allSlotNames['text']![slotIndex] = slot?['name'] ?? 'カスタマイズ';
    }

    final numericSlots = await _getEnabledSlotIndexes('numeric');
    for (final slotIndex in numericSlots) {
      final slot = await lzPresetDao.getNumericSlot(slotIndex);
      allSlotNames['numeric']![slotIndex] = slot?['name'] ?? 'カスタマイズ';
    }

    final dateSlots = await _getEnabledSlotIndexes('date');
    for (final slotIndex in dateSlots) {
      final slot = await lzPresetDao.getDateSlot(slotIndex);
      allSlotNames['date']![slotIndex] = slot?['name'] ?? 'カスタマイズ';
    }

    if (mode != 'rotate') {
      String modeType;
      int currentIndex;

      switch (mode) {
        case 'remark':
          modeType = 'text';
          currentIndex = prefs.currentAttrSlotIndex;
          break;
        case 'number':
          modeType = 'numeric';
          currentIndex = prefs.currentNumericSlotIndex;
          break;
        case 'date':
          modeType = 'date';
          currentIndex = prefs.currentDateSlotIndex;
          break;
        default:
          return allSlotNames;
      }

      final enabledSlots = await _getEnabledSlotIndexes(modeType);

      if (enabledSlots.isEmpty) {
        notifier.setCurrentMode('rotate');
        appLog('⚠️ モード検証: $mode モードに有効スロットなし → 回転モードに変更');
        return allSlotNames;
      }

      if (!enabledSlots.contains(currentIndex)) {
        final first = enabledSlots.first;

        if (mode == 'remark') {
          notifier.setCurrentAttrSlotIndex(first);
        } else if (mode == 'number') {
          notifier.setCurrentNumericSlotIndex(first);
        } else if (mode == 'date') {
          notifier.setCurrentDateSlotIndex(first);
        }

        appLog('⚠️ モード検証: スロット$currentIndex が無効 → スロット$first に変更');
      }
    }

    return allSlotNames;
  }

  /// ============================================================
  /// ✅ ALL専用：個別シリーズの更新をALLに反映
  /// ============================================================
  Future<void> syncToAll(String cardSeriesId, int number) async {
    try {
      // ✅ 個別シリーズのstateから最新カードを取得
      final seriesState = ref.read(cardsProvider(cardSeriesId));
      final updatedCard = seriesState.cards[number.toString()];

      if (updatedCard == null) {
        appLog('⚠️ syncToAll: カードが見つかりません $cardSeriesId#$number');
        return;
      }

      // ✅ ALLのキー形式で更新
      final key = '${cardSeriesId}_$number';
      final updated = Map<String, Map<String, dynamic>>.from(state.cards);
      updated[key] = Map<String, dynamic>.from(updatedCard);

      state = state.copyWith(cards: updated);

      appLog('🔄 syncToAll: $cardSeriesId#$number → ALL反映');
    } catch (e, st) {
      appLog('❌ syncToAll error: $e\n$st');
    }
  }

  /// ============================================================
  /// ✅ ALLの更新を個別シリーズに反映
  /// ============================================================
  Future<void> syncFromAll(String cardSeriesId, int number) async {
    try {
      // ALLのstateから最新カードを取得
      final allState = ref.read(cardsProvider("ALL"));
      final allKey = '${cardSeriesId}_$number';
      final updatedCard = allState.cards[allKey];

      if (updatedCard == null) {
        appLog('⚠️ syncFromAll: カードが見つかりません $allKey');
        return;
      }

      // 個別シリーズのキー形式で更新
      final key = number.toString();
      final updated = Map<String, Map<String, dynamic>>.from(state.cards);
      updated[key] = Map<String, dynamic>.from(updatedCard);

      state = state.copyWith(cards: updated);

      appLog('🔄 syncFromAll: ALL → $cardSeriesId#$number 反映');
    } catch (e, st) {
      appLog('❌ syncFromAll error: $e\n$st');
    }
  }
}

/// ============================================================
/// Provider（Family）
/// ============================================================
final cardsProvider =
    NotifierProvider.family<CardsNotifier, CardsState, String>(
  CardsNotifier.new,
);

/// ============================================================
/// ✅ キャッシュ全削除（グローバル操作なので別 Provider）
/// ============================================================
final cacheManagerProvider = Provider((ref) => CacheManager(ref));

class CacheManager {
  final Ref ref;
  CacheManager(this.ref);

  Future<void> deleteAllCachedImages() async {
    final lock = LockManager.instance;

    if (!lock.canGlobal()) {
      throw Exception("CacheDelete locked");
    }

    lock.startGlobal();
    try {
      appLog('CacheManager: キャッシュ全削除開始');

      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory cacheDir = Directory('${dir.path}/images/cache');

      // フォルダが存在する場合、中身だけ削除
      if (await cacheDir.exists()) {
        final entries = cacheDir.listSync();
        for (final entry in entries) {
          if (entry is File) {
            await entry.delete();
          }
        }
        appLog('CacheManager: キャッシュファイル削除完了');
      } else {
        // フォルダが無ければ作成
        await cacheDir.create(recursive: true);
      }

      // DB の imagePath を NULL にする
      await CardsDao.instance.resetAllImagePaths();
      appLog('CacheManager: 全カード imagePath を NULL に更新');

      // Riverpod の Family を無効化（必要なら seriesId ごとに invalidate）
      ref.invalidate(cardsProvider);
      appLog('CacheManager: 全 cardsProvider インスタンスを無効化');
    } finally {
      lock.endGlobal();
    }
  }

  void removeSeriesCards(String seriesId) {
    // ✅ 特定シリーズの Provider を無効化
    ref.invalidate(cardsProvider(seriesId));
    appLog('CacheManager: シリーズ $seriesId のインスタンスを無効化');
  }
}
