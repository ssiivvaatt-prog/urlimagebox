// lib/pages/text_item_list_ui.dart

import '../../DB/CORE/local_db_service.dart';
import '../../utils/logger.dart';
import 'text_item_detail_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sharedpreferences_provider.dart';

class TextItemListUi extends ConsumerStatefulWidget {
  final int slotIndex;

  const TextItemListUi({
    super.key,
    required this.slotIndex,
  });

  @override
  ConsumerState<TextItemListUi> createState() => _TextItemListUiState();
}

class _TextItemListUiState extends ConsumerState<TextItemListUi> {
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String slotName = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final db = await LocalDBService.instance.database;

      // スロット名取得
      final slotResult = await db.query(
        'text_slot_list',
        where: 'slotIndex = ?',
        whereArgs: [widget.slotIndex],
      );

      if (slotResult.isNotEmpty) {
        setState(() {
          slotName = slotResult.first['name'] as String? ?? '';
        });
      }

      // ✅ text_item_list と text_item_detail を JOIN して取得
      final rows = await db.rawQuery('''
        SELECT 
          list.slotIndex,
          list.itemIndex,
          list.enabled,
          detail.label
        FROM text_item_list as list
        LEFT JOIN text_item_detail as detail
          ON list.slotIndex = detail.slotIndex
          AND list.itemIndex = detail.itemIndex
        WHERE list.slotIndex = ?
        ORDER BY list.itemIndex ASC
      ''', [widget.slotIndex]);

      setState(() {
        items = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        isLoading = false;
      });

      appLog('✅ Loaded ${items.length} text_item_list with labels');
    } catch (e, st) {
      appLog('❌ _loadItems error: $e\n$st');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleEnabled(int index) async {
    try {
      final item = items[index];
      final currentEnabled = (item['enabled'] as int?) ?? 0;
      final newEnabled = currentEnabled == 1 ? 0 : 1;

      final db = await LocalDBService.instance.database;
      await db.update(
        'text_item_list',
        {'enabled': newEnabled},
        where: 'slotIndex = ? AND itemIndex = ?',
        whereArgs: [widget.slotIndex, item['itemIndex']],
      );

      setState(() {
        items[index]['enabled'] = newEnabled;
      });

      await ref
          .read(sharedpreferencesProvider.notifier)
          .setLayerWidgetValid(false);

      appLog('✏️ Toggled item ${item['itemIndex']}: $newEnabled');
    } catch (e, st) {
      appLog('❌ _toggleEnabled error: $e\n$st');
    }
  }

  // ✅ 詳細編集画面から戻ったら再読み込み
  Future<void> _openDetailEdit(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextItemDetailUi(
          slotIndex: widget.slotIndex,
          itemIndex: items[index]['itemIndex'] as int,
        ),
      ),
    );

    // ✅ 戻ってきたら再読み込み
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '項目一覧\nItem List',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = slotName.isEmpty
        ? 'スロット${widget.slotIndex} 項目一覧 / Slot ${widget.slotIndex} Items'
        : '項目編集 / Item Edit\n$slotName';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: items.length != 20
          ? Center(child: Text('データ異常: 項目数=${items.length} (20個必要)'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 20,
              itemBuilder: (context, index) {
                final item = items[index];
                final itemIndex = item['itemIndex'] as int;
                final label = item['label'] as String? ?? ''; // ✅ label を使用
                final enabled = (item['enabled'] as int?) == 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '項目 $itemIndex / Item $itemIndex',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Text(
                              enabled ? '有効 / Enabled' : '無効 / Disabled',
                              style: TextStyle(
                                color: enabled ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: enabled,
                              onChanged: (_) => _toggleEnabled(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label.isEmpty
                                    ? '(未設定 / Not Set)'
                                    : label, // ✅ label 表示
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: label.isEmpty
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                            ),
                            // ✅ 名前編集ボタン削除
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () => _openDetailEdit(index),
                              tooltip: '詳細設定 / Settings',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
