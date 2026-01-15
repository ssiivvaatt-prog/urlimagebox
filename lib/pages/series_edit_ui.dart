// lib/pages/edit_ui.dart

import '../providers/cards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';
import '../providers/series_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../DB/Repository/series_repository.dart';

class SeriesEditUi extends HookConsumerWidget {
  final String mode; // create / edit / duplicate
  final String? seriesId;

  const SeriesEditUi({
    super.key,
    required this.mode,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();

    appLog('SeriesEditUi: 画面表示開始 - mode=$mode, seriesId=$seriesId');

    // ---------------------------------------------
    // 保存処理中フラグ (二重押し防止用)
    // ---------------------------------------------
    final isSaving = useState<bool>(false);

    // ---------------------------------------------
    // 初期データ（edit/duplicate のときのみ）
    // ---------------------------------------------
    final initialFuture = useMemoized(() {
      if (seriesId == null) return Future.value(null);
      return SeriesRepository.instance.loadSeries(seriesId!);
    }, [seriesId]);

    // ✅ 修正版
    final initialSnapshot = useFuture(initialFuture);

// create モードは即座に表示、edit/duplicate は読込完了を待つ
    if (mode != 'create' && !initialSnapshot.hasData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final initial = initialSnapshot.data;
    // ✅ ここで一度だけ取り出す
    final initialList = initial?['list'] as Map<String, dynamic>?;
    final initialConfig = initial?['config'] as Map<String, dynamic>?;
    // final initialFilter = initial?['filter'] as Map<String, dynamic>?;

    // ★★★ 追加：複製モードのときは名前に - を付けた初期値を作る
    final initialName = useMemoized(() {
      if (initial == null) return "";
      final list = initial['list'] as Map<String, dynamic>;
      final baseName = (list['name'] ?? "") as String;

      if (mode == 'duplicate') {
        return '$baseName-';
      }

      // create / edit のときは元の名前そのまま
      return baseName;
    }, [seriesId, mode]);

// ---------------------------------------------
// Controllers
// ---------------------------------------------
    final nameController = useTextEditingController(text: initialName);

// ✅ before / after
    // final beforeController =
    //     useTextEditingController(text: initialConfig?['baseUrlBefore'] ?? "");
    final beforeController = useTextEditingController(
        text: initialConfig?['baseUrlBefore'] ??
            // "https://bandainamco-am.co.jp/am/vg/idolmaster-tours/images/cardlist/cards/");
            // "https://cardfolio.idolmaster-official.jp/images/cardlist/img_wld_01_");
            "https://raw.githubusercontent.com/ssiivvaatt-prog/urlimagebox-samples/refs/heads/main/images/default");

    // final afterController =
    // useTextEditingController(text: initialConfig?['baseUrlAfter'] ?? "");
    final afterController = useTextEditingController(
        text: initialConfig?['baseUrlAfter'] ?? ".png");

// ✅ 数値系
    final digitCountController = useTextEditingController(
        text: initialConfig?['digitCount']?.toString() ?? "3");
    // text: initialConfig?['digitCount']?.toString() ?? "4");
    final fromController = useTextEditingController(
        text: initialConfig?['fromNum']?.toString() ?? "1");

    final toController = useTextEditingController(
        text: initialConfig?['toNum']?.toString() ?? "40");

    final columnsController = useTextEditingController(
        text: initialConfig?['columns']?.toString() ?? "3");

// ✅ bool
    final zeroPadEnabled =
        useState<bool>((initialConfig?['zeroPadEnabled'] ?? 1) == 1);

// ✅ フィルタ
    final onlyDigits = [FilteringTextInputFormatter.allow(RegExp(r'^\d+$'))];

    // ---------------------------------------------
    // 保存処理（二重押し防止 + 即時画面遷移 + SnackBar通知版）
    // ---------------------------------------------
    Future<void> save() async {
      if (isSaving.value) {
        appLog('SeriesEditUi: 保存処理中のため無視');
        return;
      }

      appLog('SeriesEditUi: 保存ボタン押下 → バリデーション開始');

      if (!formKey.currentState!.validate()) {
        appLog('SeriesEditUi: フォームバリデーション失敗');
        return;
      }

      int? strictInt(String v) =>
          RegExp(r'^\d+$').hasMatch(v) ? int.tryParse(v) : null;

      final fromNum = strictInt(fromController.text) ?? -1;
      final toNum = strictInt(toController.text) ?? -1;
      final digitCount = strictInt(digitCountController.text) ?? -1;
      final columns = strictInt(columnsController.text) ?? -1;

      if (fromNum < 0 || toNum < 0 || digitCount < 0 || columns < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("数値項目を正しく入力してください。")),
        );
        return;
      }
      if (toNum < fromNum) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("終了番号は開始番号以上にしてください。")),
        );
        return;
      }
      if (digitCount < 1 || digitCount > 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("桁数は1～18の範囲で入力してください。")),
        );
        return;
      }
      if (columns < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("表示カラム数は1以上にしてください。")),
        );
        return;
      }

      final maxAllowed = int.parse("9" * digitCount);
      if (fromNum > maxAllowed || toNum > maxAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("番号は $digitCount 桁以内(最大 $maxAllowed)にしてください。"),
          ),
        );
        return;
      }

      appLog('SeriesEditUi: バリデーション通過 → データ構築開始');
      isSaving.value = true;

      final isEdit = (mode == 'edit');
      final originalSeriesId = (mode == 'create') ? null : seriesId;
      final list = initialList;

      final listData = <String, dynamic>{
        'id': isEdit ? list!['id'] : const Uuid().v4(),
        'name': nameController.text.trim(),
      };

      final configData = <String, dynamic>{
        'id': listData['id'],
        'baseUrlBefore': beforeController.text.trim(),
        'baseUrlAfter': afterController.text.trim(),
        'digitCount': digitCount,
        'fromNum': fromNum,
        'toNum': toNum,
        'columns': columns,
        'zeroPadEnabled': zeroPadEnabled.value ? 1 : 0,
      };

      appLog("📌 listData:");
      listData.forEach((k, v) => appLog("  $k: $v"));
      appLog("📌 configData:");
      configData.forEach((k, v) => appLog("  $k: $v"));

      // ✅ ref を使うものはすべて事前に取得・キャプチャ
      final notifier = ref.read(seriesProvider.notifier);
      void invalidateCardsAll() => ref.invalidate(cardsProvider("ALL"));
      void invalidateCardsOriginal(String id) =>
          ref.invalidate(cardsProvider(id));

      // ✅ context が mounted か確認
      if (!context.mounted) {
        appLog('SeriesEditUi: contextが破棄済み → 処理中断');
        return;
      }

      // final popCount = (mode == 'create') ? 1 : 2;
      final popCount = 1;
      final navigatorState = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // ✅ invalidate を画面遷移前に実行
      invalidateCardsAll();
      appLog('SeriesEditUi: cardsProvider("ALL") 無効化');

      if (isEdit && originalSeriesId != null) {
        invalidateCardsOriginal(originalSeriesId);
        appLog('SeriesEditUi: cardsProvider 無効化 (edit) → $originalSeriesId');
      }

      // ✅ 画面を閉じる
      for (var i = 0; i < popCount; i++) {
        navigatorState.pop();
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('保存中... / Saving...'),
          duration: Duration(seconds: 2),
        ),
      );

      try {
        await SeriesRepository.instance.saveSeries(
          mode: mode,
          listData: listData,
          configData: configData,
          originalSeriesId: originalSeriesId,
        );

        appLog('SeriesEditUi: 保存成功');

        notifier.loadSeriesList();

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('保存完了 / Saved'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        appLog('SeriesEditUi: 保存エラー - $e');

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('保存エラー / Error: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // ---------------------------------------------
    // UI
    // ---------------------------------------------
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          mode == 'create'
              ? "シリーズ新規作成\nCreate Series"
              : mode == 'duplicate'
                  ? "シリーズ複製\nDuplicate Series"
                  : "シリーズ編集\nEdit Series",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800, // ドット感のある太字
            letterSpacing: 1.5, // NES風の間隔
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              labelText: "シリーズ名 / Series Name"),
                          validator: (v) => v == null || v.isEmpty
                              ? "入力してください / Required"
                              : null,
                        ),
                        TextFormField(
                          controller: beforeController,
                          decoration: const InputDecoration(
                              labelText: "画像URL(前半) / Image URL (Before)"),
                        ),
                        TextFormField(
                          controller: afterController,
                          decoration: const InputDecoration(
                              labelText: "画像URL(後半) / Image URL (After)"),
                        ),
                        TextFormField(
                          controller: digitCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: onlyDigits,
                          decoration: const InputDecoration(
                              labelText: "桁数 / Digit Count"),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("ゼロ埋め / Zero Padding"),
                            const SizedBox(width: 8),
                            Switch(
                              value: zeroPadEnabled.value,
                              onChanged: (v) => zeroPadEnabled.value = v,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: fromController,
                                keyboardType: TextInputType.number,
                                inputFormatters: onlyDigits,
                                decoration: const InputDecoration(
                                    labelText: "開始番号 / From"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: toController,
                                keyboardType: TextInputType.number,
                                inputFormatters: onlyDigits,
                                decoration: const InputDecoration(
                                    labelText: "終了番号 / To"),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: columnsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: onlyDigits,
                          decoration: const InputDecoration(
                              labelText: "表示カラム数 / Columns"),
                        ),
                        const SizedBox(height: 24),

                        // ★ 保存処理中はボタンを無効化
                        ElevatedButton.icon(
                          onPressed: isSaving.value ? null : save,
                          icon: isSaving.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isSaving.value ? "保存中... / Saving..." : "保存 / Save",
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
