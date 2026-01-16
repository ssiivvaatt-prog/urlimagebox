import 'dart:io';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:url_launcher/url_launcher.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../services/ad_service.dart';
import '../DB/DAO/series_list_dao.dart';
import '../DB/DAO/cards_dao.dart';
import '../DB/DAO/preset_dao.dart';
import '../utils/logger.dart';
import '../secrets.dart';

/// Google Drive API 用の HTTP クライアント
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

/// バックアップ・リストア管理Provider（Google Drive 版）
class BackupProvider extends ChangeNotifier {
  bool _initialized = false;

  // v6.x は instance を使わず、自前で作る
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _googleAccount;
  auth.AuthClient? _desktopAuthClient;
  static const int dataVersion = 1;

  bool isLoading = false;
  String? errorMessage;
  double progress = 0.0;

  // ================================
  // 初期化（v6.x は initialize 不要）
  // ================================
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      // v6.x は initialize() も attemptLightweightAuthentication() も不要
      _initialized = true;
    }
  }

  // ================================
  // サインイン（v6.x は signIn()）
  // ================================
  Future<bool> _signIn() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _signInMobile();
    } else if (Platform.isWindows || Platform.isMacOS) {
      return _signInDesktop();
    } else {
      errorMessage = "このプラットフォームはサポートされていません";
      return false;
    }
  }

  Future<bool> _signInMobile() async {
    try {
      await _googleSignIn.signOut(); // 前回の残りを消す

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        appLog('[Auth] ❌ キャンセルされました');
        return false;
      }

      _googleAccount = googleUser;

      appLog('[Auth] ✅ Google サインイン成功: ${googleUser.email}');
      return true;
    } catch (e, st) {
      appLog('[Auth] ❌ Google サインイン失敗: $e\n$st');
      return false;
    }
  }

  Future<bool> _signInDesktop() async {
    try {
      final clientId = auth.ClientId(
        googleClientId,
        googleClientSecret,
      );

      final scopes = [
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ];

      final authClient = await auth.clientViaUserConsent(
        clientId,
        scopes,
        (url) async {
          await launchUrl(Uri.parse(url));
        },
      );

      _desktopAuthClient = authClient;
      appLog("[Auth Desktop] ✅ サインイン成功");
      return true;
    } catch (e, st) {
      appLog("[Auth Desktop] ❌ サインイン失敗: $e\n$st");
      return false;
    }
  }

  Future<String> _getAccessToken() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final authData = await _googleAccount!.authentication;
      return authData.accessToken!;
    } else if (Platform.isWindows || Platform.isMacOS) {
      return _desktopAuthClient!.credentials.accessToken.data;
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  Future<void> _signOut() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _googleSignIn.disconnect();
        appLog('[Auth] Google サインアウト完了');
      }
    } catch (e) {
      appLog('[Auth] ❌ サインアウト失敗: $e');
    }
  }

  // ================================
  // バックアップ実行
  // ================================
  Future<bool> executeBackup() async {
    isLoading = true;
    errorMessage = null;
    progress = 0.0;
    notifyListeners();

    try {
      await _ensureInitialized();

      appLog('[Backup] Google サインイン開始...');
      final ok = await _signIn();
      if (!ok) {
        errorMessage = 'サインインがキャンセルされました';
        return false;
      }

      await AdService().showAdAndExecute(() async {
        await _uploadToDrive();
      });

      appLog('[Backup] ✅ バックアップ完了');
      return true;
    } catch (e, st) {
      errorMessage = 'バックアップに失敗しました: $e';
      appLog('[Backup] ❌ バックアップ失敗: $e\n$st');
      return false;
    } finally {
      await _signOut();
      isLoading = false;
      progress = 0.0;
      notifyListeners();
    }
  }

  // ================================
  // リストア実行
  // ================================
  Future<bool> executeRestore() async {
    isLoading = true;
    errorMessage = null;
    progress = 0.0;
    notifyListeners();

    try {
      await _ensureInitialized();

      appLog('[Restore] Google サインイン開始...');
      final ok = await _signIn();
      if (!ok) {
        errorMessage = 'サインインがキャンセルされました';
        return false;
      }

      await _downloadFromDrive();

      appLog('[Restore] ✅ リストア完了');
      return true;
    } catch (e, st) {
      errorMessage = 'リストアに失敗しました: $e';
      appLog('[Restore] ❌ リストア失敗: $e\n$st');
      return false;
    } finally {
      await _signOut();
      isLoading = false;
      progress = 0.0;
      notifyListeners();
    }
  }

  // ================================
  // Google Drive アップロード
  // ================================
  Future<void> _uploadToDrive() async {
    final presetDao = PresetDao.instance;

    final seriesList = await SeriesListDao.instance.getAll();
    progress = 0.1;
    notifyListeners();

    final seriesConfig = await SeriesListDao.instance.getAllConfigs();
    progress = 0.2;
    notifyListeners();

    final cards = await CardsDao.instance.getAll();
    progress = 0.3;
    notifyListeners();

    final textSlotList = await presetDao.getAllFromTable('text_slot_list');
    progress = 0.4;
    notifyListeners();

    final textItemList = await presetDao.getAllFromTable('text_item_list');
    progress = 0.5;
    notifyListeners();

    final textItemDetail = await presetDao.getAllFromTable('text_item_detail');
    progress = 0.6;
    notifyListeners();

    final numericSlotList =
        await presetDao.getAllFromTable('numeric_slot_list');
    progress = 0.7;
    notifyListeners();

    final numericSlotDetail =
        await presetDao.getAllFromTable('numeric_slot_detail');
    progress = 0.8;
    notifyListeners();

    final dateSlotList = await presetDao.getAllFromTable('date_slot_list');
    progress = 0.85;
    notifyListeners();

    final dateSlotDetail = await presetDao.getAllFromTable('date_slot_detail');
    progress = 0.9;
    notifyListeners();

    final backupData = {
      'data_version': dataVersion,
      'series_list': seriesList,
      'series_config': seriesConfig,
      'cards': cards,
      'text_slot_list': textSlotList,
      'text_item_list': textItemList,
      'text_item_detail': textItemDetail,
      'numeric_slot_list': numericSlotList,
      'numeric_slot_detail': numericSlotDetail,
      'date_slot_list': dateSlotList,
      'date_slot_detail': dateSlotDetail,
    };

    final jsonString = jsonEncode(backupData);
    final bytes = utf8.encode(jsonString);

    await _uploadToGoogleDrive(bytes);

    progress = 1.0;
    notifyListeners();
  }

  // ================================
  // Drive へアップロード（v6.x）
  // ================================
  Future<void> _uploadToGoogleDrive(List<int> bytes) async {
    final accessToken = await _getAccessToken();

    final authHeaders = {
      'Authorization': 'Bearer $accessToken',
    };

    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final appFolderId = await _getOrCreateFolder(driveApi, "URLimageBox");
    final backupFolderId =
        await _getOrCreateSubFolder(driveApi, appFolderId, "Backup");

    // 既存の backup.json を探す
    final existing = await driveApi.files.list(
      q: "'$backupFolderId' in parents and name = 'backup.json' and trashed = false",
      spaces: 'drive',
    );

    final media = drive.Media(Stream.value(bytes), bytes.length);

    if (existing.files != null && existing.files!.isNotEmpty) {
      // ★ 上書き（parents を書かない）
      final fileId = existing.files!.first.id!;
      await driveApi.files.update(
        drive.File()..name = 'backup.json',
        fileId,
        uploadMedia: media,
      );
    } else {
      // ★ 新規作成
      final file = drive.File()
        ..name = 'backup.json'
        ..parents = [backupFolderId];

      await driveApi.files.create(file, uploadMedia: media);
    }
  }

  // ================================
  // Google Drive ダウンロード（v6.x）
  // ================================
  Future<void> _downloadFromDrive() async {
    // ★ Android / iOS / Windows / macOS 共通のアクセストークン取得
    final accessToken = await _getAccessToken();

    final authHeaders = {
      'Authorization': 'Bearer $accessToken',
    };

    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final appFolderId = await _getFolderId(driveApi, "URLimageBox");
    final backupFolderId =
        await _getFolderId(driveApi, "Backup", parent: appFolderId);
    final fileId = await _getFileId(driveApi, backupFolderId, "backup.json");

    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.fold<List<int>>(
      [],
      (previous, element) => previous..addAll(element),
    );

    final jsonString = utf8.decode(bytes);
    final data = jsonDecode(jsonString);

    final backupVersion = data['data_version'] as int?;
    if (backupVersion != dataVersion) {
      throw Exception("データフォーマットのバージョンが異なります");
    }

    final presetDao = PresetDao.instance;

    await SeriesListDao.instance.restoreAll(
      List<Map<String, dynamic>>.from(data['series_list'] ?? []),
    );
    progress = 0.1;
    notifyListeners();

    await SeriesListDao.instance.restoreAllConfigs(
      List<Map<String, dynamic>>.from(data['series_config'] ?? []),
    );
    progress = 0.2;
    notifyListeners();

    await CardsDao.instance.restoreAll(
      List<Map<String, dynamic>>.from(data['cards'] ?? []),
    );
    progress = 0.3;
    notifyListeners();

// ★ ここで imagePath をクリアする（重要）
    await CardsDao.instance.resetAllImagePaths();
    appLog('Restore: 全カード imagePath を NULL に更新');

    await presetDao.restoreTable(
      'text_slot_list',
      List<Map<String, dynamic>>.from(data['text_slot_list'] ?? []),
    );
    progress = 0.4;
    notifyListeners();

    await presetDao.restoreTable(
      'text_item_list',
      List<Map<String, dynamic>>.from(data['text_item_list'] ?? []),
    );
    progress = 0.5;
    notifyListeners();

    await presetDao.restoreTable(
      'text_item_detail',
      List<Map<String, dynamic>>.from(data['text_item_detail'] ?? []),
    );
    progress = 0.6;
    notifyListeners();

    await presetDao.restoreTable(
      'numeric_slot_list',
      List<Map<String, dynamic>>.from(data['numeric_slot_list'] ?? []),
    );
    progress = 0.7;
    notifyListeners();

    await presetDao.restoreTable(
      'numeric_slot_detail',
      List<Map<String, dynamic>>.from(data['numeric_slot_detail'] ?? []),
    );
    progress = 0.8;
    notifyListeners();

    await presetDao.restoreTable(
      'date_slot_list',
      List<Map<String, dynamic>>.from(data['date_slot_list'] ?? []),
    );
    progress = 0.9;
    notifyListeners();

    await presetDao.restoreTable(
      'date_slot_detail',
      List<Map<String, dynamic>>.from(data['date_slot_detail'] ?? []),
    );
    progress = 1.0;
    notifyListeners();
  }

  // ================================
  // Drive フォルダユーティリティ
  // ================================
  Future<String> _getOrCreateFolder(drive.DriveApi api, String name) async {
    final response = await api.files.list(
      q: "name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
    );

    if (response.files?.isNotEmpty ?? false) {
      return response.files!.first.id!;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<String> _getOrCreateSubFolder(
    drive.DriveApi api,
    String parentId,
    String name,
  ) async {
    final response = await api.files.list(
      q: "'$parentId' in parents and name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
    );

    if (response.files?.isNotEmpty ?? false) {
      return response.files!.first.id!;
    }

    final folder = drive.File()
      ..name = name
      ..parents = [parentId]
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<String> _getFolderId(
    drive.DriveApi api,
    String name, {
    String? parent,
  }) async {
    final q = parent == null
        ? "name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        : "'$parent' in parents and name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final response = await api.files.list(q: q, spaces: 'drive');

    if (response.files?.isEmpty ?? true) {
      throw Exception("フォルダ '$name' が見つかりません");
    }

    return response.files!.first.id!;
  }

  Future<String> _getFileId(
    drive.DriveApi api,
    String parentId,
    String name,
  ) async {
    final response = await api.files.list(
      q: "'$parentId' in parents and name = '$name' and trashed = false",
      spaces: 'drive',
    );

    if (response.files?.isEmpty ?? true) {
      throw Exception("バックアップファイルが見つかりません");
    }

    return response.files!.first.id!;
  }
}
