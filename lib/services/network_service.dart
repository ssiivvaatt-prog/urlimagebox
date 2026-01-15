import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// ネットワーク通信を担当するサービス
/// 外部アクセスはこのクラス経由のみ行う
class NetworkService {
  /// 指定URLの存在確認（HEAD）
  Future<bool> checkImageExists(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      appLog('HEAD failed: $url => $e');
      return false;
    }
  }

  /// 画像バイトを取得（GET）
  Future<Uint8List?> fetchImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      appLog('GET failed: $url [${response.statusCode}]');
      return null;
    } catch (e) {
      appLog('GET exception: $url => $e');
      return null;
    }
  }
}
