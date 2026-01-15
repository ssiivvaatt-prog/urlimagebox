// lib/utils/app_lock.dart

/// ============================================================
/// LockManager - 排他制御管理
/// ============================================================
///
/// 3段階のロック粒度:
/// - Global: アプリ全体のロック（キャッシュ全削除など）
/// - Series: シリーズ単位のロック（シリーズ編集・削除など）
/// - Card: カード単位のロック（カード個別操作）
///
/// ============================================================
class LockManager {
  LockManager._internal();
  static final LockManager instance = LockManager._internal();

  bool globalLock = false; // アプリ全体ロック
  final Set<String> seriesLock = {}; // シリーズ単位ロック
  final Set<String> cardLock = {}; // カード単位ロック ("seriesId:number")

  // ==========================================================
  // ① グローバルロックのみチェック
  // 用途: 新規作成など、他のシリーズと競合しない操作
  // ==========================================================
  bool canGlobalOnly() {
    return !globalLock;
  }

  // ==========================================================
  // ② 全てのロックが解放されているかチェック
  // 用途: キャッシュ全削除など、全シリーズが空である必要がある操作
  // ==========================================================
  bool canGlobal() {
    if (globalLock) return false;
    if (seriesLock.isNotEmpty) return false;
    if (cardLock.isNotEmpty) return false;
    return true;
  }

  // ==========================================================
  // ③ 指定シリーズが操作可能かチェック
  // 用途: シリーズ編集・削除・カード生成など
  // ==========================================================
  bool canSeries(String seriesId) {
    if (globalLock) return false;
    if (seriesLock.contains(seriesId)) return false;
    return true;
  }

  // ==========================================================
  // ④ 全シリーズが操作可能かチェック（カードロックは無視）
  // 用途: シリーズ並び替えなど
  // ==========================================================
  bool canAllSeriesFree() {
    if (globalLock) return false;
    if (seriesLock.isNotEmpty) return false;
    return true;
  }

  // ==========================================================
  // ⑤ 指定カードが操作可能かチェック（シリーズロックは無視）
  // 用途: カード個別操作（回転・スタンプなど）
  // ==========================================================
  bool canCard(String seriesId, int number) {
    if (globalLock) return false;

    final key = "$seriesId:$number";
    if (cardLock.contains(key)) return false;

    return true;
  }

  // ==========================================================
  // ⑥ 指定シリーズと指定カードが操作可能かチェック
  // 用途: カード操作（シリーズロックも考慮する必要がある場合）
  // ==========================================================
  bool canSeriesCard(String seriesId, int number) {
    if (globalLock) return false;

    if (seriesLock.contains(seriesId)) return false;

    final key = "$seriesId:$number";
    if (cardLock.contains(key)) return false;

    return true;
  }

  // ==========================================================
  // ロック開始
  // ==========================================================
  void startGlobal() => globalLock = true;

  void startSeries(String seriesId) => seriesLock.add(seriesId);

  void startCard(String seriesId, int number) =>
      cardLock.add("$seriesId:$number");

  // ==========================================================
  // ロック解除
  // ==========================================================
  void endGlobal() => globalLock = false;

  void endSeries(String seriesId) => seriesLock.remove(seriesId);

  void endCard(String seriesId, int number) =>
      cardLock.remove("$seriesId:$number");

  // ==========================================================
  // 全解除（デバッグ・アプリ起動時用）
  // ==========================================================
  void resetAll() {
    globalLock = false;
    seriesLock.clear();
    cardLock.clear();
  }

  // ==========================================================
  // デバッグ情報取得
  // ==========================================================
  Map<String, dynamic> debugStatus() {
    return {
      "globalLock": globalLock,
      "seriesLock": seriesLock.toList(),
      "cardLock": cardLock.toList(),
    };
  }
}
