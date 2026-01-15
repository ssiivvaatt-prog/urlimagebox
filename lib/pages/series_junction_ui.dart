import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../providers/app_provider.dart';
import 'series_edit_ui.dart';
import '../utils/logger.dart';
import '../utils/app_lock.dart';

import '../providers/series_provider.dart';

class SeriesJunctionUi extends ConsumerWidget {
  final Map<String, dynamic> pzseries;

  const SeriesJunctionUi({super.key, required this.pzseries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lzs = pzseries;
    final lock = LockManager.instance;

    void showLockError() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("他の処理が実行中です / Action is locked"),
          duration: Duration(seconds: 1),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          title: Text(
            'シリーズ メニュー\nSeries Menu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800, // ドット感のある太字
              letterSpacing: 1.5, // NES風の間隔
            ),
          )),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(
              lzs['name'],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'No. ${lzs['fromNum']} ～ ${lzs['toNum']}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${lzs['baseUrlBefore']}${lzs['fromNum']}${lzs['baseUrlAfter']}',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            // 編集
            _menuButton(
              icon: Icons.edit,
              label: '編集\nEdit',
              onTap: () {
                if (!lock.canSeries(lzs['id'])) {
                  showLockError();
                  return;
                }
                appLog('SeriesJunctionUi: 編集ボタン押下');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesEditUi(
                      mode: 'edit',
                      seriesId: lzs['id'],
                    ),
                  ),
                );
              },
            ),

            // 複製
            _menuButton(
              icon: Icons.copy,
              label: '複製\nDuplicate',
              onTap: () {
                if (!lock.canSeries(
                  lzs['id'],
                )) {
                  showLockError();
                  return;
                }
                appLog('SeriesJunctionUi: 複製ボタン押下');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesEditUi(
                      mode: 'duplicate',
                      seriesId: lzs['id'],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 削除
            _menuButton(
              icon: Icons.delete,
              label: '削除\nDelete',
              color: Colors.red,
              onTap: () async {
                if (!lock.canSeries(lzs['id'])) {
                  showLockError();
                  return;
                }

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('削除確認'),
                    content: Text('「${lzs['name']}」を削除しますか?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }
}
