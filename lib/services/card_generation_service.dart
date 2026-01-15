import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import 'image_service.dart';

/// 画像キャッシュ生成専用サービス
/// - URL → md5ファイル名 → キャッシュ生成
/// - DB や card の情報は見ない
class CardGenerationService {
  final _imageService = ImageService();

  /// URL の画像をキャッシュフォルダに生成して、そのファイルパスを返す
  ///
  /// - キャッシュ存在 → そのままパス返す
  /// - キャッシュ無し → ダウンロード＆保存してパス返す
  /// - 失敗時 → null（placeholder は UI/provider が判断）
  Future<String?> generateCacheFromUrl(String url) async {
    try {
      final cacheDir = await _getCacheDir();
      final filename = md5.convert(utf8.encode(url)).toString();
      final filePath = '$cacheDir/$filename.jpg';
      final file = File(filePath);

      // ① キャッシュが既にある
      if (await file.exists()) {
        appLog('🟢 Cache exists → return: $filePath');
        return filePath;
      }

      // ② 無いので作る
      appLog('🧩 Cache missing → generate: $url');

      final savedPath = await _imageService.downloadAndCacheImage(
        imageUrl: url,
        filePath: filePath,
      );

      if (savedPath == null) {
        appLog('❌ Cache generate failed');
        return null;
      }

      appLog('📝 Cache created: $savedPath');
      return savedPath;
    } catch (e, st) {
      appLog('CardGenerationService.generateCacheFromUrl error: $e\n$st');
      return null;
    }
  }

  Future<String> _getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/images/cache';
    await Directory(path).create(recursive: true);
    return path;
  }
}
