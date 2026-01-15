// lib/pages/filter_settings_ui.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../providers/sharedpreferences_provider.dart';
import '../DB/DAO/preset_dao.dart';
import '../providers/series_provider.dart';
import '../utils/logger.dart';

class FilterSettingsUi extends HookConsumerWidget {
  final String seriesId;

  const FilterSettingsUi({
    super.key,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(sharedpreferencesProvider);
    final presetDao = PresetDao.instance;

    // ============================================================
    // ✅ 一時的な編集用 state
    // ============================================================
    final useAndCondition = useState<bool>(true);
    final textFilters = useState<Map<int, Set<int>>>({});
    final numeric1From = useTextEditingController();
    final numeric1To = useTextEditingController();
    final numeric2From = useTextEditingController();
    final numeric2To = useTextEditingController();
    final numeric3From = useTextEditingController();
    final numeric3To = useTextEditingController();
    final numeric4From = useTextEditingController();
    final numeric4To = useTextEditingController();
    final numeric5From = useTextEditingController();
    final numeric5To = useTextEditingController();
    final numeric6From = useTextEditingController();
    final numeric6To = useTextEditingController();

    final date1From = useState<int?>(null);
    final date1To = useState<int?>(null);
    final date2From = useState<int?>(null);
    final date2To = useState<int?>(null);
    final date3From = useState<int?>(null);
    final date3To = useState<int?>(null);
    final date4From = useState<int?>(null);
    final date4To = useState<int?>(null);
    final date5From = useState<int?>(null);
    final date5To = useState<int?>(null);
    final date6From = useState<int?>(null);
    final date6To = useState<int?>(null);

    final selectedSeriesIds = useState<List<String>>([]);

    // ============================================================
    // ✅ スロット・アイテム情報
    // ============================================================
    final textSlots = useState<List<Map<String, dynamic>>>([]);
    final textItems = useState<Map<int, List<Map<String, dynamic>>>>({});
    final numericSlots = useState<List<Map<String, dynamic>>>([]);
    final dateSlots = useState<List<Map<String, dynamic>>>([]);
    final seriesList = useState<List<Map<String, dynamic>>>([]);

    final expandedTextSlots = useState<Set<int>>({});
    // ============================================================
    // ✅ 定数
    // ============================================================
    // const int maxInt = 9223372036854775807; // SQLite INTEGER上限 (2^63 - 1)
    const int maxInt = 9007199254740991; // JS safe integer
    // ============================================================
    // ✅ バリデーション関数（修正版）
    // ============================================================
    String? validateNumericRange(
      TextEditingController fromController,
      TextEditingController toController,
      int slotIndex,
      String slotName, // ✅ 追加
    ) {
      final fromText = fromController.text.trim();
      final toText = toController.text.trim();

      if (fromText.isEmpty && toText.isEmpty) {
        return null; // 両方空なら OK
      }

      int? from;
      int? to;

      // from のバリデーション
      if (fromText.isNotEmpty) {
        from = int.tryParse(fromText);
        if (from == null) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): From は数値で入力してください / must be a number';
        }
        if (from < 0) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): From は0以上で入力してください / must be 0 or greater';
        }
        if (from > maxInt) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): From が大きすぎます / too large';
        }
      }

      // to のバリデーション
      if (toText.isNotEmpty) {
        to = int.tryParse(toText);
        if (to == null) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): To は数値で入力してください / must be a number';
        }
        if (to < 0) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): To は0以上で入力してください / must be 0 or greater';
        }
        if (to > maxInt) {
          return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): To が大きすぎます / too large';
        }
      }

      // ✅ 修正: 両方入力されている場合のみ大小チェック
      if (from != null && to != null && from > to) {
        return '数値フィルター / Numeric Filter\nスロット$slotIndex ($slotName): From は To 以下にしてください / From must be ≤ To';
      }

      return null;
    }

    String? validateDateRange(
      int? from,
      int? to,
      int slotIndex,
      String slotName, // ✅ 追加
    ) {
      if (from == null && to == null) {
        return null; // 両方空なら OK
      }

      // ✅ 修正: 両方入力されている場合のみ大小チェック
      if (from != null && to != null && from > to) {
        return '日付フィルター / Date Filter\nスロット$slotIndex ($slotName): From は To 以下にしてください / From must be ≤ To';
      }

      return null;
    }

    // ============================================================
    // ✅ 全体バリデーション（修正版）
    // ============================================================
    Map<String, String> validateAll() {
      final errors = <String, String>{};

      // 数値フィルターのバリデーション
      final numericControllers = [
        (numeric1From, numeric1To, 1),
        (numeric2From, numeric2To, 2),
        (numeric3From, numeric3To, 3),
        (numeric4From, numeric4To, 4),
        (numeric5From, numeric5To, 5),
        (numeric6From, numeric6To, 6),
      ];

      for (final (from, to, slotIndex) in numericControllers) {
        // ✅ スロット名を取得
        final slot = numericSlots.value.firstWhere(
          (s) => s['slotIndex'] == slotIndex,
          orElse: () => {'name': 'カスタマイズ'},
        );
        final slotName = slot['name'] as String? ?? 'カスタマイズ';

        final error = validateNumericRange(from, to, slotIndex, slotName);
        if (error != null) {
          errors['numeric$slotIndex'] = error;
        }
      }

      // 日付フィルターのバリデーション
      final dateStates = [
        (date1From.value, date1To.value, 1),
        (date2From.value, date2To.value, 2),
        (date3From.value, date3To.value, 3),
        (date4From.value, date4To.value, 4),
        (date5From.value, date5To.value, 5),
        (date6From.value, date6To.value, 6),
      ];

      for (final (from, to, slotIndex) in dateStates) {
        // ✅ スロット名を取得
        final slot = dateSlots.value.firstWhere(
          (s) => s['slotIndex'] == slotIndex,
          orElse: () => {'name': 'カスタマイズ'},
        );
        final slotName = slot['name'] as String? ?? 'カスタマイズ';

        final error = validateDateRange(from, to, slotIndex, slotName);
        if (error != null) {
          errors['date$slotIndex'] = error;
        }
      }

      return errors;
    }

    // ============================================================
    // ✅ 初期化
    // ============================================================
    useEffect(() {
      Future.microtask(() async {
        // 現在のフィルター設定を読み込み
        final currentFilter = prefs.filterSettings;
        useAndCondition.value = currentFilter.useAndCondition;
        textFilters.value = Map.from(currentFilter.textFilters);
        selectedSeriesIds.value = List.from(currentFilter.selectedSeriesIds);

        // numeric範囲の初期値
        numeric1From.text = currentFilter.numeric1Range?.from?.toString() ?? '';
        numeric1To.text = currentFilter.numeric1Range?.to?.toString() ?? '';
        numeric2From.text = currentFilter.numeric2Range?.from?.toString() ?? '';
        numeric2To.text = currentFilter.numeric2Range?.to?.toString() ?? '';
        numeric3From.text = currentFilter.numeric3Range?.from?.toString() ?? '';
        numeric3To.text = currentFilter.numeric3Range?.to?.toString() ?? '';
        numeric4From.text = currentFilter.numeric4Range?.from?.toString() ?? '';
        numeric4To.text = currentFilter.numeric4Range?.to?.toString() ?? '';
        numeric5From.text = currentFilter.numeric5Range?.from?.toString() ?? '';
        numeric5To.text = currentFilter.numeric5Range?.to?.toString() ?? '';
        numeric6From.text = currentFilter.numeric6Range?.from?.toString() ?? '';
        numeric6To.text = currentFilter.numeric6Range?.to?.toString() ?? '';

        // date範囲の初期値
        date1From.value = currentFilter.date1Range?.from;
        date1To.value = currentFilter.date1Range?.to;
        date2From.value = currentFilter.date2Range?.from;
        date2To.value = currentFilter.date2Range?.to;
        date3From.value = currentFilter.date3Range?.from;
        date3To.value = currentFilter.date3Range?.to;
        date4From.value = currentFilter.date4Range?.from;
        date4To.value = currentFilter.date4Range?.to;
        date5From.value = currentFilter.date5Range?.from;
        date5To.value = currentFilter.date5Range?.to;
        date6From.value = currentFilter.date6Range?.from;
        date6To.value = currentFilter.date6Range?.to;

        // スロット・アイテム情報を取得(有効なもののみ)
        final textSlotList = <Map<String, dynamic>>[];
        final textItemMap = <int, List<Map<String, dynamic>>>{};
        for (int i = 1; i <= 6; i++) {
          final slot = await presetDao.getTextSlot(i);
          if (slot != null && slot['enabled'] == 1) {
            textSlotList.add(slot);

            final items = await presetDao.getTextItems(i);
            textItemMap[i] =
                items.where((item) => item['enabled'] == 1).toList();
          }
        }
        textSlots.value = textSlotList;
        textItems.value = textItemMap;

        final numericSlotList = <Map<String, dynamic>>[];
        for (int i = 1; i <= 6; i++) {
          final slot = await presetDao.getNumericSlot(i);
          if (slot != null && slot['enabled'] == 1) {
            numericSlotList.add(slot);
          }
        }
        numericSlots.value = numericSlotList;

        final dateSlotList = <Map<String, dynamic>>[];
        for (int i = 1; i <= 6; i++) {
          final slot = await presetDao.getDateSlot(i);
          if (slot != null && slot['enabled'] == 1) {
            dateSlotList.add(slot);
          }
        }
        dateSlots.value = dateSlotList;

        // シリーズ一覧取得(ALL画面の場合のみ)
        if (seriesId == "ALL") {
          final series = ref.read(seriesProvider).seriesList;
          seriesList.value = series;
        }
      });

      return null;
    }, const []);

    // ============================================================
    // ✅ リセット処理
    // ============================================================
    void resetFilter() {
      useAndCondition.value = true;
      textFilters.value = {};
      expandedTextSlots.value = {};

      numeric1From.clear();
      numeric1To.clear();
      numeric2From.clear();
      numeric2To.clear();
      numeric3From.clear();
      numeric3To.clear();
      numeric4From.clear();
      numeric4To.clear();
      numeric5From.clear();
      numeric5To.clear();
      numeric6From.clear();
      numeric6To.clear();

      date1From.value = null;
      date1To.value = null;
      date2From.value = null;
      date2To.value = null;
      date3From.value = null;
      date3To.value = null;
      date4From.value = null;
      date4To.value = null;
      date5From.value = null;
      date5To.value = null;
      date6From.value = null;
      date6To.value = null;

      selectedSeriesIds.value = [];

      appLog('フィルター設定リセット');
    }

    // ============================================================
    // ✅ 保存処理(バリデーション追加版)
    // ============================================================
    Future<void> saveFilter() async {
      // ✅ バリデーション実行（保存時のみ）
      final errors = validateAll();

      if (errors.isNotEmpty) {
        appLog('バリデーションエラー: $errors');

        // 最初のエラーメッセージを表示
        final firstError = errors.values.first;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firstError),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      try {
        // ✅ ヘルパー関数: 空文字列の場合は null を返す
        int? parseNullableInt(String text) {
          if (text.isEmpty) return null;
          return int.tryParse(text);
        }

        final newFilter = FilterSettings(
          useAndCondition: useAndCondition.value,
          selectedSeriesIds: selectedSeriesIds.value,
          textFilters: textFilters.value,
          numeric1Range:
              numeric1From.text.isNotEmpty || numeric1To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric1From.text),
                      to: parseNullableInt(numeric1To.text),
                    )
                  : null,
          numeric2Range:
              numeric2From.text.isNotEmpty || numeric2To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric2From.text),
                      to: parseNullableInt(numeric2To.text),
                    )
                  : null,
          numeric3Range:
              numeric3From.text.isNotEmpty || numeric3To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric3From.text),
                      to: parseNullableInt(numeric3To.text),
                    )
                  : null,
          numeric4Range:
              numeric4From.text.isNotEmpty || numeric4To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric4From.text),
                      to: parseNullableInt(numeric4To.text),
                    )
                  : null,
          numeric5Range:
              numeric5From.text.isNotEmpty || numeric5To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric5From.text),
                      to: parseNullableInt(numeric5To.text),
                    )
                  : null,
          numeric6Range:
              numeric6From.text.isNotEmpty || numeric6To.text.isNotEmpty
                  ? NumericRange(
                      from: parseNullableInt(numeric6From.text),
                      to: parseNullableInt(numeric6To.text),
                    )
                  : null,
          date1Range: date1From.value != null || date1To.value != null
              ? DateRange(from: date1From.value, to: date1To.value)
              : null,
          date2Range: date2From.value != null || date2To.value != null
              ? DateRange(from: date2From.value, to: date2To.value)
              : null,
          date3Range: date3From.value != null || date3To.value != null
              ? DateRange(from: date3From.value, to: date3To.value)
              : null,
          date4Range: date4From.value != null || date4To.value != null
              ? DateRange(from: date4From.value, to: date4To.value)
              : null,
          date5Range: date5From.value != null || date5To.value != null
              ? DateRange(from: date5From.value, to: date5To.value)
              : null,
          date6Range: date6From.value != null || date6To.value != null
              ? DateRange(from: date6From.value, to: date6To.value)
              : null,
        );

        await ref
            .read(sharedpreferencesProvider.notifier)
            .setFilterSettings(newFilter);

        appLog('フィルター設定保存完了');

        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e, st) {
        appLog('フィルター設定保存エラー: $e\n$st');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存エラー / Save Error: $e')),
          );
        }
      }
    }

    // ============================================================
    // ✅ UI
    // ============================================================
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'フィルター設定\nFilter Settings',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ========================================
                  // ✅ AND/OR 切り替え
                  // ========================================
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'フィルター条件 / Filter Condition',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('AND条件\n(すべて満たす)'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('OR条件\n(いずれか満たす)'),
                              ),
                            ],
                            selected: {useAndCondition.value},
                            onSelectionChanged: (Set<bool> newSelection) {
                              useAndCondition.value = newSelection.first;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ========================================
                  // ✅ テキスト属性フィルター
                  // ========================================
                  if (textSlots.value.isNotEmpty) ...[
                    const Text(
                      'スタンプフィルター / Stamp Filter',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...textSlots.value.map((slot) {
                      final slotIndex = slot['slotIndex'] as int;
                      final slotName = slot['name'] as String? ?? 'カスタマイズ';
                      final items = textItems.value[slotIndex] ?? [];
                      final isExpanded =
                          expandedTextSlots.value.contains(slotIndex);

                      final selectedItems = textFilters.value[slotIndex] ?? {};
                      final allItemIndexes =
                          items.map((item) => item['itemIndex'] as int).toSet();
                      final isAllSelected = allItemIndexes.isNotEmpty &&
                          allItemIndexes
                              .every((idx) => selectedItems.contains(idx));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Checkbox(
                                value: isAllSelected,
                                tristate: true,
                                onChanged: (value) {
                                  final updated = Map<int, Set<int>>.from(
                                      textFilters.value);
                                  if (value == true) {
                                    updated[slotIndex] = allItemIndexes;
                                  } else {
                                    updated[slotIndex] = {};
                                  }
                                  textFilters.value = updated;
                                },
                              ),
                              title: Text('スロット$slotIndex: $slotName'),
                              trailing: IconButton(
                                icon: Icon(isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more),
                                onPressed: () {
                                  final updated =
                                      Set<int>.from(expandedTextSlots.value);
                                  if (isExpanded) {
                                    updated.remove(slotIndex);
                                  } else {
                                    updated.add(slotIndex);
                                  }
                                  expandedTextSlots.value = updated;
                                },
                              ),
                            ),
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    // ✅ スタンプ無しを追加
                                    CheckboxListTile(
                                      dense: true,
                                      title: const Text('0: スタンプ無し / No Stamp'),
                                      value: selectedItems.contains(0),
                                      onChanged: (value) {
                                        final updated = Map<int, Set<int>>.from(
                                            textFilters.value);
                                        final current = Set<int>.from(
                                            updated[slotIndex] ?? {});

                                        if (value == true) {
                                          current.add(0);
                                        } else {
                                          current.remove(0);
                                        }

                                        updated[slotIndex] = current;
                                        textFilters.value = updated;
                                      },
                                    ),
                                    // ✅ 既存のアイテム
                                    ...items.map((item) {
                                      final itemIndex =
                                          item['itemIndex'] as int;
                                      final itemName =
                                          item['name'] as String? ?? 'カスタマイズ';
                                      final isSelected =
                                          selectedItems.contains(itemIndex);

                                      return CheckboxListTile(
                                        dense: true,
                                        title: Text('$itemIndex: $itemName'),
                                        value: isSelected,
                                        onChanged: (value) {
                                          final updated =
                                              Map<int, Set<int>>.from(
                                                  textFilters.value);
                                          final current = Set<int>.from(
                                              updated[slotIndex] ?? {});

                                          if (value == true) {
                                            current.add(itemIndex);
                                          } else {
                                            current.remove(itemIndex);
                                          }

                                          updated[slotIndex] = current;
                                          textFilters.value = updated;
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ========================================
                  // ✅ 数値属性フィルター
                  // ========================================
                  if (numericSlots.value.isNotEmpty) ...[
                    const Text(
                      '数値フィルター / Numeric Filter',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...numericSlots.value.map((slot) {
                      final slotIndex = slot['slotIndex'] as int;
                      final slotName = slot['name'] as String? ?? 'カスタマイズ';

                      final fromController = [
                        numeric1From,
                        numeric2From,
                        numeric3From,
                        numeric4From,
                        numeric5From,
                        numeric6From
                      ][slotIndex - 1];

                      final toController = [
                        numeric1To,
                        numeric2To,
                        numeric3To,
                        numeric4To,
                        numeric5To,
                        numeric6To
                      ][slotIndex - 1];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'スロット$slotIndex / Slot $slotIndex: $slotName', // ✅ 修正
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: fromController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'From',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: toController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'To',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ========================================
                  // ✅ 日付属性フィルター
                  // ========================================
                  if (dateSlots.value.isNotEmpty) ...[
                    const Text(
                      '日付フィルター / Date Filter',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...dateSlots.value.map((slot) {
                      final slotIndex = slot['slotIndex'] as int;
                      final slotName = slot['name'] as String? ?? 'カスタマイズ';

                      final fromStates = [
                        date1From,
                        date2From,
                        date3From,
                        date4From,
                        date5From,
                        date6From
                      ];
                      final toStates = [
                        date1To,
                        date2To,
                        date3To,
                        date4To,
                        date5To,
                        date6To
                      ];

                      final fromState = fromStates[slotIndex - 1];
                      final toState = toStates[slotIndex - 1];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'スロット$slotIndex / Slot $slotIndex: $slotName', // ✅ 修正
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final date = await _selectDate(
                                            context, fromState.value);
                                        if (date != null) {
                                          fromState.value = date;
                                        }
                                      },
                                      child: Text(
                                        fromState.value != null
                                            ? _formatDate(fromState.value!)
                                            : 'From',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final date = await _selectDate(
                                            context, toState.value);
                                        if (date != null) {
                                          toState.value = date;
                                        }
                                      },
                                      child: Text(
                                        toState.value != null
                                            ? _formatDate(toState.value!)
                                            : 'To',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ========================================
                  // ✅ シリーズ選択(ALL画面のみ)
                  // ========================================
                  if (seriesId == "ALL" && seriesList.value.isNotEmpty) ...[
                    const Text(
                      'シリーズ選択 / Series Selection',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: seriesList.value.map((series) {
                          final id = series['id'] as String;
                          final name = series['name'] as String? ?? '名称未設定';
                          final isSelected =
                              selectedSeriesIds.value.contains(id);

                          return CheckboxListTile(
                            title: Text(name),
                            value: isSelected,
                            onChanged: (value) {
                              final updated =
                                  List<String>.from(selectedSeriesIds.value);
                              if (value == true) {
                                updated.add(id);
                              } else {
                                updated.remove(id);
                              }
                              selectedSeriesIds.value = updated;
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ========================================
            // ✅ 下部ボタン
            // ========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: resetFilter,
                      child: const Text('リセット / Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル / Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saveFilter,
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ 日付選択ヘルパー
  // ============================================================
  Future<int?> _selectDate(BuildContext context, int? currentValue) async {
    DateTime initialDate = DateTime.now();
    if (currentValue != null) {
      final str = currentValue.toString().padLeft(8, '0');
      if (str.length == 8) {
        final y = int.tryParse(str.substring(0, 4)) ?? DateTime.now().year;
        final m = int.tryParse(str.substring(4, 6)) ?? 1;
        final d = int.tryParse(str.substring(6, 8)) ?? 1;
        initialDate = DateTime(y, m, d);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      return int.parse(
        '${picked.year.toString().padLeft(4, '0')}'
        '${picked.month.toString().padLeft(2, '0')}'
        '${picked.day.toString().padLeft(2, '0')}',
      );
    }

    return null;
  }

  String _formatDate(int yyyymmdd) {
    final str = yyyymmdd.toString().padLeft(8, '0');
    return '${str.substring(0, 4)}/${str.substring(4, 6)}/${str.substring(6, 8)}';
  }
}
