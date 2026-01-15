import 'dart:io';
import 'package:flutter/material.dart';

/// GridView 用のカード画像ウィジェット
/// v4.8.2: 背景と余白を白で統一、BoxFit.contain、枠線なし
/// 状態別表示（attr1〜5）は Phase 4 で反映予定
class CardGridItemWidget extends StatelessWidget {
  final Map<String, dynamic> card;

  const CardGridItemWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final imagePath = card['imagePath'] as String?;

    return Container(
      color: Colors.white, // 背景と余白を白で統一
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6), // 軽い角丸
        child: imagePath != null && File(imagePath).existsSync()
            ? Image.file(
                File(imagePath),
                fit: BoxFit.contain, // 縦横比を維持してセル内に収める
              )
            : Image.asset(
                'assets/placeholder.png',
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
