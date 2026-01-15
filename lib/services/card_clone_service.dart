import '../utils/logger.dart';
import '../DB/DAO/cards_dao.dart';

/// カード複製専用サービス
/// 指定されたシリーズ間で、単一カードをコピーする。
class CardCloneService {
  final _cardsDao = CardsDao.instance;

  /// 単一カードを旧シリーズ→新シリーズへコピー
  Future<void> cloneOne({
    required String fromSeriesId,
    required String toSeriesId,
    required int number,
  }) async {
    try {
      // 🔹 元カード取得
      final oldCard =
          await _cardsDao.getCardBySeriesAndNumber(fromSeriesId, number);
      if (oldCard == null) {
        appLog('⚠️ カードが見つかりません: $fromSeriesId#$number');
        return;
      }

      // 🔹 新しいカードデータ作成
      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> newCard = Map<String, dynamic>.from(oldCard);

      // 複製先用にフィールドを置換
      newCard['seriesId'] = toSeriesId;
      newCard['number'] = number;
      newCard['updatedAt'] = now;

      // 主キーが (seriesId, number) の複合キーなので、上書き or 追加
      await _cardsDao.insertOrReplace(newCard);

      appLog(
          '📋 Card cloned: $fromSeriesId#$number → $toSeriesId#$number (updatedAt=$now)');
    } catch (e, st) {
      appLog('💥 Card clone failed ($fromSeriesId#$number): $e\n$st');
    }
  }
}
