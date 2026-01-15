// void appLog(String message) {
//   // ignore: avoid_print
//   print('[CardApp] $message');
// }

// ----------------------------------------------------
// CardApp Logging （既存 appLog を拡張）
// enabled を true/false にするだけで一括ログ制御
// ----------------------------------------------------
bool appLogEnabled = true; // ← ここだけホットリロードで変更する

void appLog(String message) {
  if (!appLogEnabled) return;
  // ignore: avoid_print
  print('[CardApp] $message');
}
