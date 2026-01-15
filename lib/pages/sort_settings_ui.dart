// lib/pages/sort_settings_ui.dart

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../providers/sharedpreferences_provider.dart';
import '../DB/DAO/preset_dao.dart';
import '../utils/logger.dart';

class SortSettingsUi extends HookConsumerWidget {
  final String seriesId;

  const SortSettingsUi({
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
    final sortConditions = useState<List<SortCondition>>([]);

    // ============================================================
    // ✅ スロット情報（フィールド選択肢用）
    // ============================================================
    final numericSlots = useState<List<Map<String, dynamic>>>([]);
    final dateSlots = useState<List<Map<String, dynamic>>>([]);
    final isLoading = useState<bool>(true);
    // ============================================================
    // ✅ 初期化
    // ============================================================
    useEffect(() {
      Future.microtask(() async {
        // 現在のソート設定を読み込み
        sortConditions.value = List.from(prefs.sortConditions);

        // 有効なスロット情報を取得
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
        isLoading.value = false;
      });

      return null;
    }, const []);
// ✅ ローディング中は別の画面を表示
    if (isLoading.value) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // ============================================================
    // ✅ リセット処理
    // ============================================================
    void resetSort() {
      sortConditions.value = [];
      appLog('ソート設定リセット');
    }

    // ============================================================
    // ✅ 保存処理
    // ============================================================
    Future<void> saveSort() async {
      try {
        await ref
            .read(sharedpreferencesProvider.notifier)
            .setSortConditions(sortConditions.value);

        appLog('ソート設定保存完了');

        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e, st) {
        appLog('ソート設定保存エラー: $e\n$st');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存エラー / Save Error: $e')),
          );
        }
      }
    }

    // ============================================================
    // ✅ 条件追加
    // ============================================================
    void addCondition() {
      final updated = List<SortCondition>.from(sortConditions.value);
      updated.add(const SortCondition(field: SortField.cardNumber));
      sortConditions.value = updated;
    }

    // ============================================================
    // ✅ 条件削除
    // ============================================================
    void removeCondition(int index) {
      final updated = List<SortCondition>.from(sortConditions.value);
      updated.removeAt(index);
      sortConditions.value = updated;
    }

    // ============================================================
    // ✅ フィールド変更
    // ============================================================
    void updateField(int index, SortField newField) {
      final updated = List<SortCondition>.from(sortConditions.value);
      updated[index] = SortCondition(
        field: newField,
        ascending: updated[index].ascending,
      );
      sortConditions.value = updated;
    }

    // ============================================================
    // ✅ 昇順/降順切り替え
    // ============================================================
    void toggleAscending(int index) {
      final updated = List<SortCondition>.from(sortConditions.value);
      updated[index] = SortCondition(
        field: updated[index].field,
        ascending: !updated[index].ascending,
      );
      sortConditions.value = updated;
    }

    // ============================================================
    // ✅ フィールド名取得
    // ============================================================
    String getFieldName(SortField field) {
      switch (field) {
        case SortField.sortIndex:
          return 'シリーズ並び順 / Series Order';
        case SortField.name:
          return 'シリーズ名 / Series Name';
        case SortField.cardNumber:
          return 'カード番号 / Number';
        case SortField.numeric1:
        case SortField.numeric2:
        case SortField.numeric3:
        case SortField.numeric4:
        case SortField.numeric5:
        case SortField.numeric6:
          final slotIndex = int.parse(field.name.replaceAll('numeric', ''));
          final slot = numericSlots.value.firstWhere(
            (s) => s['slotIndex'] == slotIndex,
            orElse: () => {'name': 'カスタマイズ'},
          );
          return '数値$slotIndex: ${slot['name']}';
        case SortField.date1:
        case SortField.date2:
        case SortField.date3:
        case SortField.date4:
        case SortField.date5:
        case SortField.date6:
          final slotIndex = int.parse(field.name.replaceAll('date', ''));
          final slot = dateSlots.value.firstWhere(
            (s) => s['slotIndex'] == slotIndex,
            orElse: () => {'name': 'カスタマイズ'},
          );
          return '日付$slotIndex: ${slot['name']}';
      }
    }

    // ============================================================
    // ✅ 選択可能なフィールドリスト生成
    // ============================================================
    List<SortField> getAvailableFields() {
      final fields = <SortField>[
        SortField.sortIndex,
        SortField.name,
        SortField.cardNumber,
      ];

      // 有効な数値スロット
      for (final slot in numericSlots.value) {
        final slotIndex = slot['slotIndex'] as int;
        fields.add(SortField.values.firstWhere(
          (f) => f.name == 'numeric$slotIndex',
        ));
      }

      // 有効な日付スロット
      for (final slot in dateSlots.value) {
        final slotIndex = slot['slotIndex'] as int;
        fields.add(SortField.values.firstWhere(
          (f) => f.name == 'date$slotIndex',
        ));
      }

      return fields;
    }

    // ============================================================
    // ✅ UI
    // ============================================================
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'ソート設定\nSort Settings',
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
              child: sortConditions.value.isEmpty
                  ? const Center(
                      child: Text(
                        'ソート条件がありません\nNo sort conditions',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortConditions.value.length,
                      onReorder: (oldIndex, newIndex) {
                        final updated =
                            List<SortCondition>.from(sortConditions.value);
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = updated.removeAt(oldIndex);
                        updated.insert(newIndex, item);
                        sortConditions.value = updated;
                      },
                      itemBuilder: (context, index) {
                        final condition = sortConditions.value[index];
                        final availableFields = getAvailableFields();

                        // ✅ デバッグログ追加
                        appLog('========== DEBUG ==========');
                        appLog('condition.field: ${condition.field.name}');
                        appLog(
                            'availableFields: ${availableFields.map((f) => f.name).toList()}');
                        appLog(
                            'contains: ${availableFields.contains(condition.field)}');
                        appLog('===========================');

                        return Card(
                          key: ValueKey('sort_$index'),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // ドラッグハンドル
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(
                                        Icons.drag_handle,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 優先順位
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '優先${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // 削除ボタン
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => removeCondition(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // フィールド選択
                                DropdownButtonFormField<SortField>(
                                  initialValue: condition.field,
                                  decoration: const InputDecoration(
                                    labelText: 'フィールド / Field',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableFields.map((field) {
                                    return DropdownMenuItem(
                                      value: field,
                                      child: Text(getFieldName(field)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      updateField(index, value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                // 昇順/降順切り替え
                                Row(
                                  children: [
                                    const Text('並び順 / Order:'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment(
                                            value: true,
                                            label: Text('昇順 / Asc'),
                                            icon: Icon(Icons.arrow_upward),
                                          ),
                                          ButtonSegment(
                                            value: false,
                                            label: Text('降順 / Desc'),
                                            icon: Icon(Icons.arrow_downward),
                                          ),
                                        ],
                                        selected: {condition.ascending},
                                        onSelectionChanged: (Set<bool> value) {
                                          if (value.first !=
                                              condition.ascending) {
                                            toggleAscending(index);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ========================================
            // ✅ 追加ボタン
            // ========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('条件を追加 / Add Condition'),
                  onPressed: addCondition,
                ),
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
                      onPressed: resetSort,
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
                      onPressed: saveSort,
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
}
