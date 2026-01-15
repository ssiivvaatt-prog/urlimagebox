// lib/pages/home_ui.dart

import '../providers/layer_cache_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../providers/cards_provider.dart';
import '../providers/series_provider.dart';
import '../providers/backup_provider.dart';
import 'series_edit_ui.dart';
import 'card_ui.dart';
import 'slot_list_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../utils/logger.dart';
import '../utils/app_lock.dart';
import '../../providers/sharedpreferences_provider.dart';
// import '../../DB/DAO/preset_dao.dart';

class HomeUi extends HookConsumerWidget {
  const HomeUi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // useEffect で初回ロード
    useEffect(() {
      ref.read(seriesProvider.notifier).loadSeriesList();
      return null;
    }, const []);

    // 監視
    final lzSeriesList = ref.watch(seriesProvider.select((s) => s.seriesList));
    // final prefs = ref.watch(sharedpreferencesProvider);

    void showLockError(BuildContext context) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('他の処理が実行中です / Action is locked.'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'URLimageBOX',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          // ======================================
          // 🚧 開発用: 本番前に削除すること
          // ======================================
//           IconButton(
//             icon: const Icon(Icons.lock_open),
//             onPressed: () {
//               final lock = LockManager.instance;
//               lock.resetAll();
//               appLog("🔓 All locks reset manually!");

//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('All Locks Reset'),
//                   duration: Duration(seconds: 2),
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.lock),
//             onPressed: () {
//               final lock = LockManager.instance;
//               final prefs = ref.read(sharedpreferencesProvider);

//               final msg = '''
// Global Lock: ${lock.globalLock}
// Series Lock: ${lock.seriesLock.isEmpty ? 'なし' : lock.seriesLock.toList()}
// Card Lock: ${lock.cardLock.isEmpty ? 'なし' : lock.cardLock.toList()}
// layerWidgetValid: ${prefs.layerWidgetValid}
//     ''';

//               appLog('🔐 Lock Status:\n$msg');

//               showDialog(
//                 context: context,
//                 builder: (_) => AlertDialog(
//                   title: const Text('Lock Status (Dev Only)'),
//                   content: Text(msg),
//                   actions: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: const Text('OK'),
//                     )
//                   ],
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.bug_report),
//             onPressed: () async {
//               final presetDao = PresetDao.instance;

//               appLog('=== Debug TextItems ===');
//               for (int i = 1; i <= 6; i++) {
//                 await presetDao.debugTextItems(i);
//               }

//               if (context.mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('デバッグログ出力完了 / Debug log printed'),
//                     duration: Duration(seconds: 1),
//                   ),
//                 );
//               }
//             },
//           ),
          // ======================================
          // 🚧 開発用ここまで
          // ======================================
          PopupMenuButton<String>(
            onSelected: (value) async {
              appLog('HomeUi: メニュー選択 → $value');

              // ========================================
              // キャッシュ削除
              // ========================================
              if (value == 'cache_delete') {
                final lock = LockManager.instance;

                if (!lock.canGlobal()) {
                  showLockError(context);
                  return;
                }

                final ok = await showConfirmDialog(
                  context,
                  title: '確認 / Confirm',
                  message: 'キャッシュをすべて削除します。\nよろしいですか?',
                );
                if (!ok) return;

                appLog('HomeUi: キャッシュ削除開始');
                await ref.read(cacheManagerProvider).deleteAllCachedImages();
                appLog('HomeUi: キャッシュ削除完了');
              }

              // ========================================
              // バックアップ
              // ========================================
              if (value == 'backup') {
                final lock = LockManager.instance;

                if (!lock.canGlobal()) {
                  if (context.mounted) showLockError(context);
                  return;
                }

                if (!context.mounted) return;

                // 確認ダイアログ
                final confirm = await showConfirmDialog(
                  context,
                  title: 'バックアップ確認\nBackup Confirmation',
                  message: '広告が表示された後、バックアップを実行します。\n'
                      'よろしいですか?\n\n'
                      'An ad will be shown before backup.\n'
                      'Do you want to continue?',
                );

                if (!confirm) return;

                // プログレスダイアログ表示
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _BackupProgressDialog(),
                );

                // バックアップ実行
                final provider = ref.read(backupProviderInstance);
                final success = await provider.executeBackup();

                // ダイアログを閉じる
                if (context.mounted) {
                  Navigator.pop(context);

                  // 結果表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ バックアップ完了 / Backup completed'
                            : '❌ ${provider.errorMessage ?? 'バックアップ失敗 / Backup failed'}',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }

              // ========================================
              // リストア
              // ========================================
              if (value == 'restore') {
                final lock = LockManager.instance;

                if (!lock.canGlobal()) {
                  if (context.mounted) showLockError(context);
                  return;
                }

                if (!context.mounted) return;

                // 確認ダイアログ
                final confirm = await showConfirmDialog(
                  context,
                  title: 'リストア確認\nRestore Confirmation',
                  message: '既存のデータを上書きします。\n'
                      'よろしいですか?\n\n'
                      'This will overwrite existing data.\n'
                      'Are you sure?',
                );

                if (!confirm) return;

                // プログレスダイアログ表示
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _BackupProgressDialog(),
                );

                // リストア実行
                final provider = ref.read(backupProviderInstance);
                final success = await provider.executeRestore();

                if (success) {
                  // シリーズ一覧を再読み込み
                  await ref.read(seriesProvider.notifier).loadSeriesList();

                  // ALL モードだけ invalidate
                  ref.invalidate(cardsProvider("ALL"));
                }

                // ダイアログを閉じる
                if (context.mounted) {
                  Navigator.pop(context);

                  // 結果表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ リストア完了 / Restore completed'
                            : '❌ ${provider.errorMessage ?? 'リストア失敗 / Restore failed'}',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'backup',
                child: Text('📤 バックアップ\nBackup'),
              ),
              PopupMenuItem(
                value: 'restore',
                child: Text('📥 リストア\nRestore'),
              ),
              PopupMenuItem(
                value: 'cache_delete',
                child: Text('キャッシュ削除\nClear Cache'),
              ),
            ],
          )
        ],
      ),
      body: lzSeriesList.isEmpty
          ? const Center(child: Text('シリーズがありません\nno series available'))
          : ReorderableListView.builder(
              itemCount: lzSeriesList.length,
              onReorder: (oldIndex, newIndex) {
                final lock = LockManager.instance;
                if (!lock.canAllSeriesFree()) {
                  showLockError(context);
                  return;
                }
                appLog('HomeUi: 並べ替え発生 - 旧: $oldIndex → 新: $newIndex');
                ref
                    .read(seriesProvider.notifier)
                    .reorderSeries(oldIndex, newIndex);
                // ★★★ 追加：ALL モードのキャッシュを無効化
                ref.invalidate(cardsProvider("ALL"));
              },
              itemBuilder: (context, lzindex) {
                final lzs = lzSeriesList[lzindex];
                final cardsState = ref.watch(cardsProvider(lzs['id']));

                return // home_ui.dart の該当部分（ListTile の onTap）

                    ListTile(
                  key: ValueKey(lzs['id']),
                  leading: ReorderableDragStartListener(
                    index: lzindex,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lzs['name']),
                      if (cardsState.isLoading)
                        Text(
                          '準備中 / Preparing… ${(cardsState.progress * 100).toInt()}%',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else if (cardsState.isReady)
                        const Text(
                          '✅ 準備完了 / Ready',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                    ],
                  ),
                  onTap: () async {
                    final lock = LockManager.instance;
                    final seriesId = lzs['id'];

                    if (!lock.canSeries(seriesId)) {
                      showLockError(context);
                      return;
                    }

                    final prefs = ref.read(sharedpreferencesProvider);
                    final prefsNotifier =
                        ref.read(sharedpreferencesProvider.notifier);
                    final layerNotifier = ref.read(layerCacheProvider.notifier);
                    final cardsNotifier =
                        ref.read(cardsProvider(seriesId).notifier);

                    // ✅ キャッシュ未準備なら先に作成して待つ
                    if (!prefs.layerWidgetValid) {
                      appLog('HomeUi: レイヤーキャッシュ準備開始');
                      await prefsNotifier.setLayerWidgetValid(true);
                      await layerNotifier.loadAll(baseSize: 256.0);

                      // ✅ 追加: 完全ロード完了まで待つ
                      while (ref.read(layerCacheProvider).isLoading) {
                        await Future.delayed(const Duration(milliseconds: 50));
                      }

                      appLog('HomeUi: レイヤーキャッシュ準備完了');
                    }

                    // ✅ カード未準備なら準備して待つ
                    if (!cardsState.isReady) {
                      appLog(
                          'HomeUi: シリーズタップ → prepareCards() 開始 (ID: $seriesId)');
                      await cardsNotifier.prepareCards();
                      return; // ✅ ここで一旦終了（画面遷移しない）
                    }

                    // ✅ 両方準備完了したら画面遷移
                    appLog('HomeUi: シリーズタップ → CardUiへ遷移 (ID: $seriesId)');
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardUi(seriesId: seriesId),
                        ),
                      );
                    }
                  },
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      final lock = LockManager.instance;
                      if (!lock.canSeries(lzs['id'])) {
                        showLockError(context);
                        return;
                      }

                      switch (value) {
                        case 'edit':
                          appLog('HomeUi: 編集選択 (ID: ${lzs['id']})');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SeriesEditUi(
                                mode: 'edit',
                                seriesId: lzs['id'],
                              ),
                            ),
                          );
                          break;

                        case 'duplicate':
                          appLog('HomeUi: 複製選択 (ID: ${lzs['id']})');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SeriesEditUi(
                                mode: 'duplicate',
                                seriesId: lzs['id'],
                              ),
                            ),
                          );
                          break;

                        case 'delete':
                          appLog('HomeUi: 削除選択 (ID: ${lzs['id']})');
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('削除確認'),
                              content: Text('「${lzs['name']}」を削除しますか?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('削除'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref
                                .read(seriesProvider.notifier)
                                .deleteSeries(lzs['id']);
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('編集\nEdit'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('複製\nDuplicate'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('削除\nDelete'),
                      ),
                    ],
                  ),
                );
              },
            ),
      // ========================================
      // ✅ タイルレイアウト
      // ========================================
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ========================================
              // 1段目: 列数変更 + 全シリーズ表示 + 新規作成
              // ========================================
              Row(
                children: [
                  // ✅ 列数変更
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () => _showColumnCountDialog(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // const Icon(Icons.view_column, size: 8),
                              const SizedBox(height: 4),
                              Text(
                                // '全シリーズ\n列数\nAll Cards\nColumns\n${prefs.allCardsColumnCount}列',
                                '全シリーズモード列数\nAll Cards Mode Column Count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 全シリーズ表示ボタン
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final allCardsState = ref.watch(cardsProvider("ALL"));

                        return Card(
                          child: InkWell(
                            onTap: () async {
                              final prefs = ref.read(sharedpreferencesProvider);
                              final prefsNotifier =
                                  ref.read(sharedpreferencesProvider.notifier);
                              final layerNotifier =
                                  ref.read(layerCacheProvider.notifier);
                              final allCardsNotifier =
                                  ref.read(cardsProvider("ALL").notifier);

                              // ✅ キャッシュ未準備なら先に作成して待つ
                              if (!prefs.layerWidgetValid) {
                                appLog('HomeUi: レイヤーキャッシュ準備開始（ALL）');
                                await prefsNotifier.setLayerWidgetValid(true);
                                await layerNotifier.loadAll(baseSize: 256.0);

                                // ✅ 追加: 完全ロード完了まで待つ
                                while (ref.read(layerCacheProvider).isLoading) {
                                  await Future.delayed(
                                      const Duration(milliseconds: 50));
                                }
                                appLog('HomeUi: レイヤーキャッシュ準備完了（ALL）');
                              }

                              // ✅ カード未準備なら準備して待つ
                              if (!allCardsState.isReady) {
                                appLog(
                                    'HomeUi: 全シリーズ表示タップ → prepareCards("ALL") 開始');
                                await allCardsNotifier.prepareCards();
                                return; // ✅ ここで一旦終了（画面遷移しない）
                              }

                              // ✅ 両方準備完了したら画面遷移
                              appLog('HomeUi: 全シリーズ表示タップ → AllCardsUiへ遷移');
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CardUi(seriesId: "ALL"),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 4),
                                  const Text(
                                    '全シリーズ\nAll Cards Mode',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  if (allCardsState.isLoading)
                                    Text(
                                      '準備中 / Preparing… ${(allCardsState.progress * 100).toInt()}%',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    )
                                  else if (allCardsState.isReady)
                                    const Text(
                                      '✅ 完了/Ready',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.green),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 新規作成
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          final lock = LockManager.instance;
                          if (!lock.canGlobalOnly()) {
                            showLockError(context);
                            return;
                          }
                          appLog(
                              'HomeUi: 新規作成ボタン押下 → SeriesEditUiへ遷移 (create)');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SeriesEditUi(
                                mode: 'create',
                                seriesId: null,
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 20),
                              SizedBox(height: 4),
                              Text(
                                '新規作成\nCreate',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ========================================
              // 2段目: スタンプ + 数字 + 日付
              // ========================================
              Row(
                children: [
                  // スタンプ編集
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          appLog('HomeUi: スタンプ編集 → SlotListUiへ遷移');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SlotListUi(
                                title: 'スタンプ編集\nEdit Stamps',
                                mode: 'text',
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_emotions, size: 20),
                              SizedBox(height: 4),
                              Text(
                                'スタンプ編集\nEdit Stamps',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 数字編集
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          appLog('HomeUi: 数字編集 → SlotListUiへ遷移');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SlotListUi(
                                title: '数字編集\nEdit Numbers',
                                mode: 'numeric',
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pin, size: 20),
                              SizedBox(height: 4),
                              Text(
                                '数字編集\nEdit Numbers',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 日付編集
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          appLog('HomeUi: 日付編集 → SlotListUiへ遷移');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SlotListUi(
                                title: '日付編集\nEdit Dates',
                                mode: 'date',
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today, size: 20),
                              SizedBox(height: 4),
                              Text(
                                '日付編集\nEdit Dates',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // showConfirmDialog を以下のように修正（title と message を引数で受け取る）
  Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル / Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ============================================================
  // ✅ 列数変更ダイアログ
  // ============================================================
  Future<void> _showColumnCountDialog(
      BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(sharedpreferencesProvider);
    final controller = TextEditingController(
      text: prefs.allCardsColumnCount.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('列数変更 / Change Columns'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+$')),
            ],
            decoration: const InputDecoration(
              labelText: '列数 / Columns',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル / Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();

                // ✅ バリデーション（series_edit_ui.dart と同じロジック）
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('列数を入力してください / Required')),
                  );
                  return;
                }

                if (!RegExp(r'^\d+$').hasMatch(text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数値を入力してください / Enter number')),
                  );
                  return;
                }

                final value = int.tryParse(text);
                if (value == null || value < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('1以上の数値を入力してください / Enter 1 or more')),
                  );
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    // ✅ コントローラーの破棄
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (result != null) {
      await ref
          .read(sharedpreferencesProvider.notifier)
          .setAllCardsColumnCount(result);

      appLog('HomeUi: 列数変更 → $result列');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('列数を$result列に変更しました / Changed to $result columns'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
}

// ========================================
// プログレスダイアログ（ファイルの最後に追加）
// ========================================
class _BackupProgressDialog extends ConsumerWidget {
  const _BackupProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(backupProviderInstance);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '処理中... ${(provider.progress * 100).toInt()}%',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ========================================
// Provider定義（ファイルの最後に追加）
// ========================================
final backupProviderInstance = ChangeNotifierProvider((ref) {
  return BackupProvider();
});
