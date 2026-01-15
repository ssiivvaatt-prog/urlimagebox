import 'dart:convert';
import 'package:flutter/material.dart';

/// シリーズ一覧用の1行表示ウィジェット（v4.8.2対応）
/// - シリーズ名、カード範囲、フィルターON数を表示
/// - 背景白固定
class SeriesTileWidget extends StatelessWidget {
  final Map<String, dynamic> series;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SeriesTileWidget({
    super.key,
    required this.series,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = series['name'] ?? '名称未設定 / No name';
    final from = series['fromNum'] ?? 1;
    final to = series['toNum'] ?? 100;

    // 複数フィルター対応（filterAttr1〜5）
    final filters = <String>[];
    for (int i = 1; i <= 5; i++) {
      final jsonStr = series['filterAttr$i'];
      if (jsonStr is String && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr);
        final activeCount = (map as Map).values.where((v) => v == true).length;
        if (activeCount > 0) filters.add('F$i:$activeCount');
      }
    }
    final filterLabel = filters.isNotEmpty ? filters.join(' ') : 'すべて / All';

    final updated = series['updatedAt'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('範囲 / Range: $from〜$to　フィルター / Filter: $filterLabel\n更新日 / Updated: $updated'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: '編集 / Edit',
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: '削除 / Delete',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
