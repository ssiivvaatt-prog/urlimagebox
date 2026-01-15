import 'package:flutter/material.dart';

class AppConstants {
  // アプリ情報
  static const String appName = 'URLimageBox';

  // デザイン（const Color にする！）
  static const Color primaryColor = Color(0xFF2196F3);

  // デバッグ
  static const bool isDebug =
      false; //右上に出る “DEBUG” リボン（バナー）を消すかどうか isDebug = false なら出る

  // DB
  static const String databaseName = 'card_collection.db';
}
