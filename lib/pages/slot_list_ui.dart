import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ 追加
import '../../DB/DAO/preset_dao.dart';
import '../../DB/CORE/local_db_service.dart';
import '../../utils/logger.dart';
import 'slot_detail_ui.dart';
import 'text_item_list_ui.dart';
import '../providers/sharedpreferences_provider.dart';
import '../providers/cards_provider.dart';

class SlotListUi extends ConsumerStatefulWidget {
  // ✅ 変更
  final String title;
  final String mode; // "text", "numeric", "date"

  const SlotListUi({
    super.key,
    required this.title,
    required this.mode,
  });

  @override
  ConsumerState<SlotListUi> createState() => _SlotListUiState(); // ✅ 変更
}

class _SlotListUiState extends ConsumerState<SlotListUi> {
  // ✅ 変更
  List<Map<String, dynamic>> slots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  String get _tableName {
    return switch (widget.mode) {
      'text' => 'text_slot_list',
      'numeric' => 'numeric_slot_list',
      'date' => 'date_slot_list',
      _ => 'text_slot_list',
    };
  }

  Future<void> _loadSlots() async {
    try {
      final db = await LocalDBService.instance.database;
      final rows = await db.query(
        _tableName,
        orderBy: 'slotIndex ASC',
      );

      setState(() {
        slots = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        isLoading = false;
      });

      appLog('✅ Loaded ${slots.length} slots from $_tableName');
    } catch (e, st) {
      appLog('❌ _loadSlots error: $e\n$st');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateSlotName(int index, String newName) async {
    try {
      final slot = slots[index];
      final slotIndex = slot['slotIndex'] as int;

      final presetDao = PresetDao.instance;
      await presetDao.updateSlotList(
        slotIndex,
        {'name': newName},
        widget.mode,
      );

      setState(() {
        slots[index]['name'] = newName;
      });
      await ref
          .read(sharedpreferencesProvider.notifier)
          .setLayerWidgetValid(false);
      appLog('✏️ Updated slot $slotIndex name: $newName');
    } catch (e, st) {
      appLog('❌ _updateSlotName error: $e\n$st');
    }
  }

  Future<void> _toggleEnabled(int index) async {
    try {
      final slot = slots[index];
      final slotIndex = slot['slotIndex'] as int;
      final currentEnabled = (slot['enabled'] as int?) ?? 0;
      final newEnabled = currentEnabled == 1 ? 0 : 1;

      final presetDao = PresetDao.instance;
      await presetDao.updateSlotList(
        slotIndex,
        {'enabled': newEnabled},
        widget.mode,
      );

      setState(() {
        slots[index]['enabled'] = newEnabled;
      });
      await ref
          .read(sharedpreferencesProvider.notifier)
          .setLayerWidgetValid(false);
      // ✅ 追加：全カードProviderを無効化（準備未完了に戻す）
      ref.invalidate(cardsProvider);
      appLog('🔄 cardsProvider 無効化（キャッシュ再作成のため）');
      appLog('✏️ Toggled slot $slotIndex: $newEnabled');
    } catch (e, st) {
      appLog('❌ _toggleEnabled error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _showNameEditDialog(int index) async {
    final slot = slots[index];
    final controller = TextEditingController(text: slot['name'] as String);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スロット名変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '名前',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // ✅ フレーム描画後に dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (result != null && result.isNotEmpty) {
      await _updateSlotName(index, result);
    }
  }

  void _openDetailEdit(int index) {
    final slot = slots[index];
    final slotIndex = slot['slotIndex'] as int;

    // ✅ text モードの場合は直接 TextItemListUi へ
    if (widget.mode == 'text') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextItemListUi(
            slotIndex: slotIndex,
          ),
        ),
      );
      return;
    }

    // ✅ numeric / date モードは SlotDetailUi へ
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SlotDetailUi(
          slotIndex: slotIndex,
          mode: widget.mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: Text(
              widget.title,
            )),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (slots.length != 6) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Text('データ異常: スロット数=${slots.length}（6個必要）'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800, // ドット感のある太字
            letterSpacing: 1.5, // NES風の間隔
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          final slot = slots[index];
          final slotIndex = slot['slotIndex'] as int;
          final name = slot['name'] as String? ?? 'カスタマイズ';
          final enabled = (slot['enabled'] as int?) == 1;

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
                          'スロット $slotIndex',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Text(
                        enabled ? '有効' : '無効',
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
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        onPressed: () => _showNameEditDialog(index),
                        tooltip: '名前変更',
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _openDetailEdit(index),
                        tooltip: '詳細編集',
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
