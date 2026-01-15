// lib/pages/card_ui.dart

import 'dart:async';
import 'dart:typed_data';

import '../pages/filter_settings_ui.dart';
import '../pages/sort_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../DB/Repository/series_repository.dart';
import '../providers/cards_provider.dart';
import '../providers/sharedpreferences_provider.dart';
import '../utils/app_lock.dart';
import '../utils/logger.dart';
import '../widgets/card_grid_item_widget.dart';
import '../utils/image_generator.dart';
import 'image_viewer_screen.dart';

class CardUi extends HookConsumerWidget {
  final String seriesId;

  const CardUi({
    super.key,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSwitching = useState(false);
    final isTapping = useState(false);
    final isSnackBarVisible = useState(false);
    final prefs = ref.watch(sharedpreferencesProvider);

    final slotNames = useState<Map<String, Map<int, String>>>({});

    final cardsState = ref.watch(cardsProvider(seriesId));

    // ----------------------------------------------------
    // 初期処理: カード準備 + モード検証
    // ----------------------------------------------------
    useEffect(() {
      appLog('CardUi: useEffect発火 → prepareCards呼び出し (seriesId: $seriesId)');

      ref.read(cardsProvider(seriesId).notifier).prepareCards();

      Future.microtask(() async {
        final names = await ref
            .read(cardsProvider(seriesId).notifier)
            .validateCurrentMode();
        slotNames.value = names;
      });
      return null;
    }, const []);

    // ----------------------------------------------------
    // Series 情報読み込み
    // ----------------------------------------------------
    final seriesFuture = useMemoized(() {
      if (seriesId == "ALL") return Future.value(null);
      return SeriesRepository.instance.loadSeries(seriesId);
    }, [seriesId]);
    final seriesSnapshot = useFuture(seriesFuture);
    final series = seriesSnapshot.data?['list'] as Map<String, dynamic>?;
    final config = seriesSnapshot.data?['config'] as Map<String, dynamic>?;

    if (seriesId != "ALL" && (series == null || config == null)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ シリーズ名（修正）
    final seriesName =
        seriesId == "ALL" ? '全カード表示 / All Cards' : (series?['name'] ?? '名称未設定');

    // ----------------------------------------------------
    // モードラベル
    // ----------------------------------------------------
    String getModeLabel() {
      final mode = prefs.currentMode;
      switch (mode) {
        case 'rotate':
          final d = prefs.currentRotateDirection;
          return d == 'right'
              ? '右回転モード / Rotate Right'
              : '左回転モード / Rotate Left';

        case 'remark':
          final idx = prefs.currentAttrSlotIndex;
          final name = slotNames.value['text']?[idx] ?? '';
          return name.isEmpty ? 'スタンプモード / Stamp Mode' : name;

        case 'number':
          final idx = prefs.currentNumericSlotIndex;
          final name = slotNames.value['numeric']?[idx] ?? '';
          return name.isEmpty ? '数字モード / Number Mode' : name;

        case 'date':
          final idx = prefs.currentDateSlotIndex;
          final name = slotNames.value['date']?[idx] ?? '';
          return name.isEmpty ? '日付モード / Date Mode' : name;

        case 'clear':
          return 'クリアモード / Clear Mode';

        default:
          return '不明モード / Unknown';
      }
    }

    // ----------------------------------------------------
    // ボトムボタン共通
    // ----------------------------------------------------
    Widget bottomButton({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            if (isSwitching.value) {
              appLog('CardUi: ボタン処理中 → 破棄 ($label)');
              return;
            }

            isSwitching.value = true;
            appLog('CardUi: ボタン押下 → $label');

            try {
              onTap();
              await Future.delayed(const Duration(milliseconds: 150));
            } finally {
              if (context.mounted) {
                isSwitching.value = false;
                appLog('CardUi: ボタンロック解除');
              }
            }
          },
          child: Opacity(
            opacity: isSwitching.value ? 0.5 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ----------------------------------------------------
    // ✅ フィルター・ソート適用
    // ----------------------------------------------------
    final filteredAndSortedEntries = useMemoized(
      () {
        final filterSettings = prefs.filterSettings;
        final sortConditions = prefs.sortConditions;

        var entries = cardsState.cards.entries.toList();

        // ========================================
        // ✅ フィルター適用（AND/OR対応）
        // ========================================
        if (filterSettings.useAndCondition) {
          // ========================================
          // AND条件：すべて満たす
          // ========================================
          entries = entries.where((entry) {
            final card = entry.value;

            // シリーズフィルター
            if (filterSettings.selectedSeriesIds.isNotEmpty) {
              if (!filterSettings.selectedSeriesIds
                  .contains(card['seriesId'])) {
                return false;
              }
            }

            // textフィルター (attr1〜6)
            for (int i = 1; i <= 6; i++) {
              final selectedItems = filterSettings.textFilters[i];
              if (selectedItems != null && selectedItems.isNotEmpty) {
                final cardValue = card['attr$i'] ?? 0;
                if (!selectedItems.contains(cardValue)) {
                  return false;
                }
              }
            }

            // ✅ 修正: numericフィルター (numeric1〜6)
            final numericRanges = [
              filterSettings.numeric1Range,
              filterSettings.numeric2Range,
              filterSettings.numeric3Range,
              filterSettings.numeric4Range,
              filterSettings.numeric5Range,
              filterSettings.numeric6Range,
            ];
            for (int i = 0; i < 6; i++) {
              final range = numericRanges[i];
              if (range != null) {
                final cardValue = (card['numeric${i + 1}'] as int?) ?? 0;

                final from = range.from;
                final to = range.to;

                // ✅ null チェックを追加
                if (from != null && to != null) {
                  // 両方指定: from <= cardValue <= to
                  if (cardValue < from || cardValue > to) return false;
                } else if (from != null) {
                  // fromのみ指定: cardValue >= from
                  if (cardValue < from) return false;
                } else if (to != null) {
                  // toのみ指定: cardValue <= to
                  if (cardValue > to) return false;
                }
              }
            }

            // ✅ 修正: dateフィルター (date1〜6)
            final dateRanges = [
              filterSettings.date1Range,
              filterSettings.date2Range,
              filterSettings.date3Range,
              filterSettings.date4Range,
              filterSettings.date5Range,
              filterSettings.date6Range,
            ];
            for (int i = 0; i < 6; i++) {
              final range = dateRanges[i];
              if (range != null) {
                final cardValue = (card['date${i + 1}'] as int?) ?? 0;

                final from = range.from;
                final to = range.to;

                // ✅ null チェックを追加
                if (from != null && to != null) {
                  // 両方指定: from <= cardValue <= to
                  if (cardValue < from || cardValue > to) return false;
                } else if (from != null) {
                  // fromのみ指定: cardValue >= from
                  if (cardValue < from) return false;
                } else if (to != null) {
                  // toのみ指定: cardValue <= to
                  if (cardValue > to) return false;
                }
              }
            }

            return true;
          }).toList();
        } else {
          // ========================================
          // OR条件：いずれか満たす
          // ========================================
          entries = entries.where((entry) {
            final card = entry.value;
            bool matchesAny = false;

            // シリーズフィルター
            if (filterSettings.selectedSeriesIds.isNotEmpty) {
              if (filterSettings.selectedSeriesIds.contains(card['seriesId'])) {
                matchesAny = true;
              }
            }

            // textフィルター (attr1〜6)
            for (int i = 1; i <= 6; i++) {
              final selectedItems = filterSettings.textFilters[i];
              if (selectedItems != null && selectedItems.isNotEmpty) {
                final cardValue = card['attr$i'] ?? 0;
                if (selectedItems.contains(cardValue)) {
                  matchesAny = true;
                }
              }
            }

            // ✅ 修正: numericフィルター (numeric1〜6)
            final numericRanges = [
              filterSettings.numeric1Range,
              filterSettings.numeric2Range,
              filterSettings.numeric3Range,
              filterSettings.numeric4Range,
              filterSettings.numeric5Range,
              filterSettings.numeric6Range,
            ];
            for (int i = 0; i < 6; i++) {
              final range = numericRanges[i];
              if (range != null) {
                final cardValue = (card['numeric${i + 1}'] as int?) ?? 0;

                final from = range.from;
                final to = range.to;

                bool inRange = false;
                if (from != null && to != null) {
                  // 両方指定: from <= cardValue <= to
                  inRange = cardValue >= from && cardValue <= to;
                } else if (from != null) {
                  // fromのみ指定: cardValue >= from
                  inRange = cardValue >= from;
                } else if (to != null) {
                  // toのみ指定: cardValue <= to
                  inRange = cardValue <= to;
                }

                if (inRange) {
                  matchesAny = true;
                }
              }
            }

            // ✅ 修正: dateフィルター (date1〜6)
            final dateRanges = [
              filterSettings.date1Range,
              filterSettings.date2Range,
              filterSettings.date3Range,
              filterSettings.date4Range,
              filterSettings.date5Range,
              filterSettings.date6Range,
            ];
            for (int i = 0; i < 6; i++) {
              final range = dateRanges[i];
              if (range != null) {
                final cardValue = (card['date${i + 1}'] as int?) ?? 0;

                final from = range.from;
                final to = range.to;

                bool inRange = false;
                if (from != null && to != null) {
                  // 両方指定: from <= cardValue <= to
                  inRange = cardValue >= from && cardValue <= to;
                } else if (from != null) {
                  // fromのみ指定: cardValue >= from
                  inRange = cardValue >= from;
                } else if (to != null) {
                  // toのみ指定: cardValue <= to
                  inRange = cardValue <= to;
                }

                if (inRange) {
                  matchesAny = true;
                }
              }
            }

            // ✅ フィルター条件が何も設定されていない場合は全件表示
            final hasAnyFilter = filterSettings.selectedSeriesIds.isNotEmpty ||
                filterSettings.textFilters.values.any((s) => s.isNotEmpty) ||
                numericRanges.any((r) => r != null) ||
                dateRanges.any((r) => r != null);

            return hasAnyFilter ? matchesAny : true;
          }).toList();
        }

        // ========================================
        // ✅ ソート適用（変更なし）
        // ========================================
        if (sortConditions.isNotEmpty) {
          entries.sort((a, b) {
            for (final condition in sortConditions) {
              int compareResult = 0;

              switch (condition.field) {
                case SortField.sortIndex:
                  final aSeries = a.value['seriesId'] ?? '';
                  final bSeries = b.value['seriesId'] ?? '';

                  final aSort = cardsState.sortIndexMap[aSeries] ?? 0;
                  final bSort = cardsState.sortIndexMap[bSeries] ?? 0;

                  compareResult = aSort.compareTo(bSort);
                  break;

                case SortField.name:
                  final aSeries = a.value['seriesId'] ?? '';
                  final bSeries = b.value['seriesId'] ?? '';

                  final aName = cardsState.seriesNameMap[aSeries] ?? '';
                  final bName = cardsState.seriesNameMap[bSeries] ?? '';

                  compareResult = aName.compareTo(bName);
                  break;

                case SortField.cardNumber:
                  final aNum = a.value['number'] ?? 0;
                  final bNum = b.value['number'] ?? 0;
                  compareResult = aNum.compareTo(bNum);
                  break;

                case SortField.numeric1:
                case SortField.numeric2:
                case SortField.numeric3:
                case SortField.numeric4:
                case SortField.numeric5:
                case SortField.numeric6:
                  final slotIndex =
                      int.parse(condition.field.name.replaceAll('numeric', ''));
                  final aVal = a.value['numeric$slotIndex'] ?? 0;
                  final bVal = b.value['numeric$slotIndex'] ?? 0;
                  compareResult = aVal.compareTo(bVal);
                  break;

                case SortField.date1:
                case SortField.date2:
                case SortField.date3:
                case SortField.date4:
                case SortField.date5:
                case SortField.date6:
                  final slotIndex =
                      int.parse(condition.field.name.replaceAll('date', ''));
                  final aVal = a.value['date$slotIndex'] ?? 0;
                  final bVal = b.value['date$slotIndex'] ?? 0;
                  compareResult = aVal.compareTo(bVal);
                  break;
              }

              if (compareResult != 0) {
                return condition.ascending ? compareResult : -compareResult;
              }
            }
            return 0;
          });
        } else {
          // デフォルトソート
          if (seriesId == "ALL") {
            final sortIndexMap = cardsState.sortIndexMap;

            entries.sort((a, b) {
              final aSeries = a.value['seriesId'] ?? '';
              final bSeries = b.value['seriesId'] ?? '';

              final aSort = sortIndexMap[aSeries] ?? 0;
              final bSort = sortIndexMap[bSeries] ?? 0;

              // ① sortIndex で比較
              final seriesCompare = aSort.compareTo(bSort);
              if (seriesCompare != 0) return seriesCompare;

              // ② 同じシリーズ内は number で比較
              final aNum = a.value['number'] ?? 0;
              final bNum = b.value['number'] ?? 0;
              return aNum.compareTo(bNum);
            });
          } else {
            // 単体シリーズは key が "1", "2", "3" なのでそのまま数値ソート
            entries.sort((a, b) {
              final aNum = int.tryParse(a.key) ?? 0;
              final bNum = int.tryParse(b.key) ?? 0;
              return aNum.compareTo(bNum);
            });
          }
        }

        return entries;
      },
      [cardsState.cards, prefs.filterSettings, prefs.sortConditions],
    );

    // ----------------------------------------------------
    // カードタップ共通処理
    // ----------------------------------------------------
    Future<void> handleCardTap(Map<String, dynamic> card) async {
      if (isTapping.value) {
        appLog('CardUi: タップ処理中 → 破棄 (#${card['number']})');
        return;
      }

      isTapping.value = true;
      appLog('CardUi: タップ受付 → ロック開始 (#${card['number']})');

      try {
        final lock = LockManager.instance;
        final number = card['number'] as int;
        final cardSeriesId = card['seriesId'] as String;

        if (!lock.canSeriesCard(cardSeriesId, number)) {
          if (!isSnackBarVisible.value) {
            isSnackBarVisible.value = true;
            ScaffoldMessenger.of(context)
                .showSnackBar(
                  const SnackBar(
                    content: Text(
                      '現在このカードは操作できません。\n'
                      'This card is currently locked.',
                    ),
                    duration: Duration(seconds: 1),
                  ),
                )
                .closed
                .then((_) {
              isSnackBarVisible.value = false;
            });
          }
          return;
        }

        final currentMode = prefs.currentMode;
        appLog('CardUi: カードタップ - #${card['number']} (モード: $currentMode)');

        switch (currentMode) {
          case 'number':
            await _showNumberInputDialog(context, ref, card,
                series ?? <String, dynamic>{'name': '全カード'}, seriesId);
            break;

          case 'date':
            await _showDatePickerDialog(context, ref, card,
                series ?? <String, dynamic>{'name': '全カード'}, seriesId);
            break;

          case 'rotate':
            await ref.read(cardsProvider(seriesId).notifier).rotateCard(
                  cardSeriesId,
                  number,
                  prefs.currentRotateDirection,
                );

            // ✅ 抜けた後に同期処理
            if (seriesId == "ALL") {
              // ALLで更新 → 個別シリーズへ同期
              final targetSeriesState = ref.read(cardsProvider(cardSeriesId));
              if (targetSeriesState.isReady) {
                await ref
                    .read(cardsProvider(cardSeriesId).notifier)
                    .syncFromAll(
                      cardSeriesId,
                      number,
                    );
              }
            } else {
              // 個別シリーズで更新 → ALLへ同期
              final allState = ref.read(cardsProvider("ALL"));
              if (allState.isReady) {
                await ref.read(cardsProvider("ALL").notifier).syncToAll(
                      cardSeriesId,
                      number,
                    );
              }
            }
            break;

          case 'remark':
            await ref.read(cardsProvider(seriesId).notifier).stampCard(
                  cardSeriesId,
                  number,
                  prefs.currentAttrSlotIndex,
                );

            // ✅ 抜けた後に同期処理
            if (seriesId == "ALL") {
              // ALLで更新 → 個別シリーズへ同期
              final targetSeriesState = ref.read(cardsProvider(cardSeriesId));
              if (targetSeriesState.isReady) {
                await ref
                    .read(cardsProvider(cardSeriesId).notifier)
                    .syncFromAll(
                      cardSeriesId,
                      number,
                    );
              }
            } else {
              // 個別シリーズで更新 → ALLへ同期
              final allState = ref.read(cardsProvider("ALL"));
              if (allState.isReady) {
                await ref.read(cardsProvider("ALL").notifier).syncToAll(
                      cardSeriesId,
                      number,
                    );
              }
            }
            break;
          case 'clear':
            await ref.read(cardsProvider(seriesId).notifier).clearCard(
                  cardSeriesId,
                  number,
                );

            // ALL と個別シリーズの同期も rotate/stamp と同じように行う
            if (seriesId == "ALL") {
              final targetSeriesState = ref.read(cardsProvider(cardSeriesId));
              if (targetSeriesState.isReady) {
                await ref
                    .read(cardsProvider(cardSeriesId).notifier)
                    .syncFromAll(cardSeriesId, number);
              }
            } else {
              final allState = ref.read(cardsProvider("ALL"));
              if (allState.isReady) {
                await ref
                    .read(cardsProvider("ALL").notifier)
                    .syncToAll(cardSeriesId, number);
              }
            }
            break;
        }

        await Future.delayed(const Duration(milliseconds: 120));
      } finally {
        if (context.mounted) {
          isTapping.value = false;
          appLog('CardUi: ロック解除');
        }
      }
    }

    // ----------------------------------------------------
    // UI
    // ----------------------------------------------------
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            seriesName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // カード一覧
            Expanded(
              child: () {
                if (filteredAndSortedEntries.isEmpty) {
                  return const Center(
                    child: Text(
                      'カードがありませんでした\nNo cards found',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final columnCount = seriesId == "ALL"
                    ? prefs.allCardsColumnCount
                    : (config?['columns'] as int? ?? 3);

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: filteredAndSortedEntries.length,
                  itemBuilder: (context, index) {
                    final card = filteredAndSortedEntries[index].value;

                    return GestureDetector(
                      onTap: () => handleCardTap(card),
                      child: CardGridItemWidget(
                        card: card,
                        series: series ?? {'name': '全カード'},
                      ),
                    );
                  },
                );
              }(),
            ),

            // ✅ モードバー（タップで循環機能追加）
            GestureDetector(
              onTap: () {
                // 現在のモードに応じた循環処理
                final currentMode = prefs.currentMode;

                switch (currentMode) {
                  case 'rotate':
                    ref
                        .read(cardsProvider(seriesId).notifier)
                        .tapRotateButton();
                    break;
                  case 'remark':
                    ref
                        .read(cardsProvider(seriesId).notifier)
                        .tapRemarkButton();
                    break;
                  case 'number':
                    ref
                        .read(cardsProvider(seriesId).notifier)
                        .tapNumberButton();
                    break;
                  case 'date':
                    ref.read(cardsProvider(seriesId).notifier).tapDateButton();
                    break;
                  case 'clear':
                    ref.read(cardsProvider(seriesId).notifier).tapClearButton();
                    break;
                }
              },
              child: Container(
                width: double.infinity,
                color: const Color(0xFF1A2A6C),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      getModeLabel(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ タップ可能アイコン（右側）
                    Icon(
                      Icons.touch_app,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // 操作バー
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  bottomButton(
                    icon: Icons.share,
                    label: '画像共有\nShare Image',
                    onTap: () async {
                      // ✅ 4つ目の引数を追加
                      await generateAndShowImage(
                        context,
                        ref,
                        seriesId,
                        filteredAndSortedEntries,
                      );
                    },
                  ),
                  bottomButton(
                    icon: Icons.sort,
                    label: 'ソート\nSort',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SortSettingsUi(seriesId: seriesId),
                        ),
                      );
                    },
                  ),
                  bottomButton(
                    icon: Icons.filter_list,
                    label: 'フィルター\nFilter',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FilterSettingsUi(seriesId: seriesId),
                        ),
                      );
                    },
                  ),
                  bottomButton(
                    icon: Icons.rotate_right,
                    label: '回転\nRotate',
                    onTap: () {
                      ref
                          .read(cardsProvider(seriesId).notifier)
                          .tapRotateButton();
                    },
                  ),
                  bottomButton(
                    icon: Icons.emoji_emotions,
                    label: 'スタンプ\nStamp',
                    onTap: () {
                      try {
                        ref
                            .read(cardsProvider(seriesId).notifier)
                            .tapRemarkButton();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('有効なスロットがありません\nNo enabled slots'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  bottomButton(
                    icon: Icons.pin,
                    label: '数字\nNumber',
                    onTap: () {
                      try {
                        ref
                            .read(cardsProvider(seriesId).notifier)
                            .tapNumberButton();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('有効なスロットがありません\nNo enabled slots'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  bottomButton(
                    icon: Icons.calendar_today,
                    label: '日付\nDate',
                    onTap: () {
                      try {
                        ref
                            .read(cardsProvider(seriesId).notifier)
                            .tapDateButton();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('有効なスロットがありません\nNo enabled slots'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  bottomButton(
                    icon: Icons.clear,
                    label: 'クリア\nClear',
                    onTap: () {
                      ref
                          .read(cardsProvider(seriesId).notifier)
                          .tapClearButton();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 数字入力ダイアログ
// ============================================================
Future<void> _showNumberInputDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> card,
  Map<String, dynamic> series,
  String seriesId,
) async {
  final prefs = ref.read(sharedpreferencesProvider);
  final currentSlotIndex = prefs.currentNumericSlotIndex;
  final currentValue = card['numeric$currentSlotIndex'] ?? 0;

  final controller = TextEditingController(
    text: currentValue == 0 ? '' : currentValue.toString(),
  );

  final result = await showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('数字を入力 / Enter Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '数字を入力してください',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル / Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('削除 / Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 0;
              Navigator.pop(context, value);
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });

  if (result != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(cardsProvider(seriesId).notifier).updateCardNumeric(
            card['seriesId'],
            card['number'],
            currentSlotIndex,
            result,
          );

      // ✅ 抜けた後に同期処理
      if (seriesId == "ALL") {
        // ALLで更新 → 個別シリーズへ同期
        final targetSeriesState = ref.read(cardsProvider(card['seriesId']));
        if (targetSeriesState.isReady) {
          await ref.read(cardsProvider(card['seriesId']).notifier).syncFromAll(
                card['seriesId'],
                card['number'],
              );
        }
      } else {
        // 個別シリーズで更新 → ALLへ同期
        final allState = ref.read(cardsProvider("ALL"));
        if (allState.isReady) {
          await ref.read(cardsProvider("ALL").notifier).syncToAll(
                card['seriesId'],
                card['number'],
              );
        }
      }

      appLog('💾 数字保存: numeric$currentSlotIndex = $result');
    });
  }
}

// ============================================================
// 日付選択ダイアログ
// ============================================================
Future<void> _showDatePickerDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> card,
  Map<String, dynamic> series,
  String seriesId,
) async {
  final prefs = ref.read(sharedpreferencesProvider);
  final currentSlotIndex = prefs.currentDateSlotIndex;
  final currentValue = card['date$currentSlotIndex'] ?? 0;

  DateTime initialDate = DateTime.now();
  if (currentValue != 0) {
    final str = currentValue.toString();
    if (str.length == 8) {
      final y = int.tryParse(str.substring(0, 4)) ?? DateTime.now().year;
      final m = int.tryParse(str.substring(4, 6)) ?? 1;
      final d = int.tryParse(str.substring(6, 8)) ?? 1;
      initialDate = DateTime(y, m, d);
    }
  }

  final pickedValue = await _showDatePickerWithClear(context, initialDate);

  if (pickedValue != null) {
    await ref.read(cardsProvider(seriesId).notifier).updateCardDate(
          card['seriesId'],
          card['number'],
          currentSlotIndex,
          pickedValue,
        );

    // ✅ 抜けた後に同期処理
    if (seriesId == "ALL") {
      // ALLで更新 → 個別シリーズへ同期
      final targetSeriesState = ref.read(cardsProvider(card['seriesId']));
      if (targetSeriesState.isReady) {
        await ref.read(cardsProvider(card['seriesId']).notifier).syncFromAll(
              card['seriesId'],
              card['number'],
            );
      }
    } else {
      // 個別シリーズで更新 → ALLへ同期
      final allState = ref.read(cardsProvider("ALL"));
      if (allState.isReady) {
        await ref.read(cardsProvider("ALL").notifier).syncToAll(
              card['seriesId'],
              card['number'],
            );
      }
    }

    appLog('💾 日付保存: date$currentSlotIndex = $pickedValue');
  }
}

Future<int?> _showDatePickerWithClear(
  BuildContext context,
  DateTime initialDate,
) async {
  return showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('日付を選択 / Select Date'),
        content: SizedBox(
          width: 300,
          height: 350,
          child: CalendarDatePicker(
            initialDate: initialDate,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
            onDateChanged: (date) {
              Navigator.pop(
                context,
                int.parse(
                  '${date.year.toString().padLeft(4, '0')}'
                  '${date.month.toString().padLeft(2, '0')}'
                  '${date.day.toString().padLeft(2, '0')}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル / Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('削除 / Clear'),
          ),
        ],
      );
    },
  );
}

// ============================================================
// 画像生成＆表示
// ============================================================
Future<void> generateAndShowImage(
  BuildContext context,
  WidgetRef ref,
  String seriesId,
  List<MapEntry<String, Map<String, dynamic>>> filteredAndSortedEntries,
) async {
  // 表示中のカード一覧を使用（フィルター・ソート済み）
  var cards = filteredAndSortedEntries.map((e) => e.value).toList();

  if (cards.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('表示するカードがありません')),
    );
    return;
  }

  // シリーズ情報取得
  Map<String, dynamic>? series;
  int columns = 5;

  final prefs = ref.read(sharedpreferencesProvider);

  if (seriesId != "ALL") {
    final seriesData = await SeriesRepository.instance.loadSeries(seriesId);
    if (!context.mounted) return;

    series = seriesData?['list'] as Map<String, dynamic>?;
    final config = seriesData?['config'] as Map<String, dynamic>?;
    columns = config?['columns'] as int? ?? 5;
  } else {
    columns = prefs.allCardsColumnCount;
  }

  // ✅ カードサイズを256px固定
  const cardSize = 256.0;

  if (!context.mounted) return;

  // 容量チェック
  final canGenerate = await ImageGenerator.checkImageCapacity(
    context: context,
    cards: cards,
    series: series ?? {'name': '全カード'},
    cardSize: cardSize,
    columns: columns,
  );

  if (!canGenerate) return;

  // 画像生成用の一時画面を表示
  if (!context.mounted) return;

  final result = await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      builder: (_) => _ImageGeneratorScreen(
        cards: cards,
        series: series ?? {'name': '全カード'},
        columns: columns,
        cardSize: cardSize, // ✅ 固定サイズを渡す
      ),
    ),
  );

  if (result == null) return;

  // 画像ビューアで表示
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ImageViewerScreen(imageBytes: result),
    ),
  );
}

// ============================================================
// 画像生成用の一時画面
// ============================================================
class _ImageGeneratorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final Map<String, dynamic> series;
  final int columns;
  final double cardSize; // ✅ 追加

  const _ImageGeneratorScreen({
    required this.cards,
    required this.series,
    required this.columns,
    required this.cardSize, // ✅ 追加
  });

  @override
  State<_ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<_ImageGeneratorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  // bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // 画面表示後に画像生成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateImage();
    });
  }

  Future<void> _generateImage() async {
    // setState(() {
    //   _isGenerating = true;
    // });

    await Future.delayed(const Duration(milliseconds: 500));

    final imageBytes = await ImageGenerator.generateCardsImage(
      repaintKey: _repaintKey,
    );

    if (mounted) {
      Navigator.pop(context, imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = widget.cards.length;
    final rows = (cardCount / widget.columns).ceil();

    // 最終画像サイズを事前計算（バッファなし）
    final imageWidth = widget.columns * widget.cardSize;
    final imageHeight = rows * widget.cardSize;

    appLog(
        '🖼️ 画像サイズ: ${imageWidth.toInt()} x ${imageHeight.toInt()} (${widget.columns}列 x $rows行)');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ローディング表示（中央）
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  '画像生成中...\n'
                  'Generating...\n\n'
                  '画像容量が多い場合、縦や横に長すぎる場合は画像が崩れます。\n'
                  '環境で崩れる幅は違うので、適宜フィルター等で調整してください。\n\n'
                  'If the image is too large or too tall/wide, the output may become distorted.\n'
                  'The degree of distortion varies by device, so please adjust with filters as needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // 画面外に配置
          Positioned(
            left: -imageWidth - 1000,
            top: -imageHeight - 1000,
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white,
                width: imageWidth,
                height: imageHeight,
                child: Wrap(
                  // ✅ GridView → Wrap
                  spacing: 0,
                  runSpacing: 0,
                  children: widget.cards.map((card) {
                    return SizedBox(
                      width: widget.cardSize,
                      height: widget.cardSize,
                      child: CardGridItemWidget(
                        card: card,
                        series: widget.series,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
