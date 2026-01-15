import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:image/image.dart' as img;

import 'logger.dart';

/// 画像生成ユーティリティ
class ImageGenerator {
  /// Widget を画像に変換（RepaintBoundary使用）
  static Future<Uint8List?> captureFromKey(
    GlobalKey key,
  ) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary not found');
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e, st) {
      appLog('❌ Widget画像化エラー: $e\n$st');
      return null;
    }
  }

  /// PNG を JPEG に変換（品質85%）
  static Uint8List convertToJpeg(Uint8List pngBytes, {int quality = 85}) {
    try {
      final image = img.decodeImage(pngBytes);
      if (image == null) {
        appLog('⚠️ PNG デコード失敗、元データを返す');
        return pngBytes;
      }

      // ✅ エンコード
      final jpegBytes = img.encodeJpg(image, quality: quality);

      // ✅ ログ出力（デバッグ用）
      final sizeBefore = (pngBytes.length / 1024).toStringAsFixed(1);
      final sizeAfter = (jpegBytes.length / 1024).toStringAsFixed(1);
      final reduction =
          ((1 - jpegBytes.length / pngBytes.length) * 100).toStringAsFixed(1);
      appLog('✅ JPEG変換: ${sizeBefore}KB → ${sizeAfter}KB ($reduction% 削減)');

      return Uint8List.fromList(jpegBytes);
    } catch (e, st) {
      appLog('❌ JPEG変換エラー: $e\n$st');
      return pngBytes; // エラー時は元データ
    }
  }

  /// 容量チェック（サンプルカード1枚で推定）
  static Future<bool> checkImageCapacity({
    required BuildContext context,
    required List<Map<String, dynamic>> cards,
    required Map<String, dynamic>? series,
    required double cardSize,
    required int columns,
  }) async {
    if (cards.isEmpty) return false;

    try {
      // サンプルとして推定サイズを計算
      // 1枚あたり約20KB（JPEG）と仮定
      const estimatedSizePerCard = 20 * 1024; // 20KB
      final estimatedSize = estimatedSizePerCard * cards.length;
      final estimatedMB = estimatedSize / (1024 * 1024);

      appLog(
          '📊 画像容量推定: ${estimatedMB.toStringAsFixed(1)}MB (${cards.length}枚)');

      // 上限チェック（50MB）
      const maxMB = 50.0;

      if (estimatedMB > maxMB) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('画像生成エラー'),
              content: Text(
                '画像サイズが大きすぎます。\n\n'
                '推定サイズ: ${estimatedMB.toStringAsFixed(1)}MB\n'
                '上限: ${maxMB.toStringAsFixed(0)}MB\n\n'
                'カード枚数を減らしてください。\n'
                '（フィルター機能を使うと減らせます）',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e, st) {
      appLog('❌ 容量チェックエラー: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('容量チェックエラー: $e')),
        );
      }
      return false;
    }
  }

  /// カード一覧を1枚の画像に生成（画面上に表示してキャプチャ）
  static Future<Uint8List?> generateCardsImage({
    required GlobalKey repaintKey,
  }) async {
    try {
      appLog('🖼️ 画像生成開始');

      // RepaintBoundary から画像化
      final pngBytes = await captureFromKey(repaintKey);

      if (pngBytes == null) {
        throw Exception('画像生成に失敗しました');
      }

      // JPEG変換
      final jpegBytes = convertToJpeg(pngBytes, quality: 85);

      appLog(
          '✅ 画像生成完了: ${(jpegBytes.length / 1024 / 1024).toStringAsFixed(1)}MB');

      return jpegBytes;
    } catch (e, st) {
      appLog('❌ 画像生成エラー: $e\n$st');
      return null;
    }
  }
}
