import 'dart:io';
import 'package:image/image.dart' as img;
import '../utils/logger.dart';
import 'network_service.dart';

class ImageService {
  final _network = NetworkService();

  Future<String?> downloadAndCacheImage({
    required String imageUrl,
    required String filePath,
  }) async {
    try {
      final bytes = await _network.fetchImageBytes(imageUrl);
      if (bytes == null) return null;

      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final w = decoded.width;
      final h = decoded.height;

      // ★ 最長辺512にする倍率を自分で計算（これが重要）
      final scale = 512 / (w > h ? w : h);
      final newW = (w * scale).round();
      final newH = (h * scale).round();

      // ★ copyResize は width / height を両方渡すのが安全
      final resized = img.copyResize(
        decoded,
        width: newW,
        height: newH,
        interpolation: img.Interpolation.average,
      );

      // ★ 512×512 白キャンバス
      final canvas = img.Image(width: 512, height: 512);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

      // ★ 中央配置（縦長でも横長でも正しくなる）
      final dx = (512 - newW) ~/ 2;
      final dy = (512 - newH) ~/ 2;

      img.compositeImage(
        canvas,
        resized,
        dstX: dx,
        dstY: dy,
        // blend: img.BlendMode.alpha,
      );

      final encoded = img.encodeJpg(canvas, quality: 90);
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(encoded);

      return filePath;
    } catch (e, st) {
      appLog('ImageService error: $e\n$st');
      return null;
    }
  }
}
