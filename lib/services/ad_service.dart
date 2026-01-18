// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import '../utils/logger.dart';
// import '../secrets.dart';

// class AdService {
//   static final AdService _instance = AdService._internal();
//   factory AdService() => _instance;
//   AdService._internal();

//   InterstitialAd? _interstitialAd;
//   bool _isAdLoaded = false;
//   int _numLoadAttempts = 0;
//   static const int _maxFailedLoadAttempts = 3;

//   /// 広告SDK初期化
//   static Future<void> initialize() async {
//     // 🟥 広告が動くのは Android / iOS のみ
//     if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       appLog('[AdService] このプラットフォームでは広告SDKを初期化しません');
//       return;
//     }

//     await MobileAds.instance.initialize();
//     appLog('[AdService] MobileAds.initialize 完了');
//   }

//   /// インタースティシャル広告を読み込む
//   Future<void> loadInterstitialAd() async {
//     if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       appLog('[AdService] このプラットフォームでは広告読み込みをスキップ');
//       return;
//     }

//     if (_isAdLoaded && _interstitialAd != null) {
//       appLog('[AdService] 広告は既に読み込み済み');
//       return;
//     }

//     final String adUnitId = Platform.isAndroid
//         ? AdMobIds.androidInterstitial
//         : AdMobIds.iosInterstitial;

//     await InterstitialAd.load(
//       adUnitId: adUnitId,
//       request: const AdRequest(),
//       adLoadCallback: InterstitialAdLoadCallback(
//         onAdLoaded: (ad) {
//           _interstitialAd = ad;
//           _isAdLoaded = true;
//           _numLoadAttempts = 0;
//           _interstitialAd!.setImmersiveMode(true);
//           appLog('[AdService] ✅ インタースティシャル広告読み込み完了');
//         },
//         onAdFailedToLoad: (error) {
//           _isAdLoaded = false;
//           _numLoadAttempts += 1;
//           appLog('[AdService] ❌ 広告読み込み失敗: $error');

//           if (_numLoadAttempts < _maxFailedLoadAttempts) {
//             Future.delayed(
//               Duration(seconds: _numLoadAttempts),
//               () => loadInterstitialAd(),
//             );
//           }
//         },
//       ),
//     );
//   }

//   /// 広告を表示し、閉じられたらコールバック実行
//   Future<void> showAdAndExecute(Function onAdClosed) async {
//     if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       appLog('[AdService] このプラットフォームでは広告表示をスキップ');
//       await onAdClosed();
//       return;
//     }

//     if (!_isAdLoaded || _interstitialAd == null) {
//       appLog('[AdService] 広告未読み込み、処理を即座に実行');
//       await onAdClosed();
//       loadInterstitialAd();
//       return;
//     }

//     final completer = Completer<void>();

//     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
//       onAdShowedFullScreenContent: (ad) {
//         appLog('[AdService] 📺 広告表示開始');
//       },
//       onAdDismissedFullScreenContent: (ad) async {
//         appLog('[AdService] ✅ 広告が閉じられました');
//         ad.dispose();
//         _interstitialAd = null;
//         _isAdLoaded = false;

//         await onAdClosed();
//         loadInterstitialAd();
//         completer.complete();
//       },
//       onAdFailedToShowFullScreenContent: (ad, error) async {
//         appLog('[AdService] ❌ 広告表示失敗: $error');
//         ad.dispose();
//         _interstitialAd = null;
//         _isAdLoaded = false;

//         await onAdClosed();
//         loadInterstitialAd();
//         completer.complete();
//       },
//     );

//     await _interstitialAd!.show();
//     await completer.future;
//   }

//   void dispose() {
//     _interstitialAd?.dispose();
//     _interstitialAd = null;
//     _isAdLoaded = false;
//     _numLoadAttempts = 0;
//   }
// }
