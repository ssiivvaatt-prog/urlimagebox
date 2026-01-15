// lib/pages/image_viewer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ImageViewerScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const ImageViewerScreen({
    super.key,
    required this.imageBytes,
  });

  // -------------------------------
  // 一時ファイル作成（共有用）
  // -------------------------------
  Future<File> _writeTempImage() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/cards_image.jpg');
    await file.writeAsBytes(imageBytes);
    return file;
  }

  // -------------------------------
  // 共有
  // -------------------------------
  Future<void> _shareImage() async {
    final file = await _writeTempImage();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'カード画像',
      ),
    );
  }

  // -------------------------------
  // 画像保存（保存先を選択）
  // -------------------------------
  Future<void> _saveImage() async {
    // Windows / macOS / Linux → パスだけ返す
    // Android / iOS → bytes が必須
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '画像を保存',
      fileName: 'card_image.png',
      bytes: imageBytes, // ← Android / iOS では必須
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg'],
    );

    // Windows / macOS / Linux の場合は path が返るので自分で書き込む
    if (path != null && !Platform.isAndroid && !Platform.isIOS) {
      final file = File(path);
      await file.writeAsBytes(imageBytes);
    }
  }

  // -------------------------------
  // 本物の画像コピー（Windows）
  // -------------------------------
  Future<void> _copyImageToClipboard(BuildContext context) async {
    try {
      final clipboard = SystemClipboard.instance!; // ← null ではないと明示
      final item = DataWriterItem();
      item.add(Formats.png(imageBytes));
      await clipboard.write([item]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像をクリップボードにコピーしました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コピーに失敗しました: $e')),
        );
      }
    }
  }

  // -------------------------------
  // ボトムメニュー
  // -------------------------------
  void _showImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('画像をコピー / Copy Image'),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyImageToClipboard(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('画像を保存 / Save Image'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('画像を共有 / Share'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('画像プレビュー / Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareImage(),
          ),
        ],
      ),
      body: GestureDetector(
        onLongPress: () =>
            _showImageOptions(context), // Android / iOS / Windows
        onSecondaryTap: () => _showImageOptions(context), // Windows 右クリック
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
