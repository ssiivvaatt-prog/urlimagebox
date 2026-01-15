import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../DB/DAO/preset_dao.dart';
import '../utils/logger.dart';

class LayerCache {
  final double baseSize;
  final bool isLoading;
  final Map<String, Widget> textWidgets;
  final Map<String, Widget> numericWidgets;
  final Map<String, Widget> dateWidgets;
  final Map<int, Map<String, dynamic>> numericSettings;
  final Map<int, Map<String, dynamic>> dateSettings;

  const LayerCache({
    required this.baseSize,
    this.isLoading = false,
    this.textWidgets = const {},
    this.numericWidgets = const {},
    this.dateWidgets = const {},
    this.numericSettings = const {},
    this.dateSettings = const {},
  });

  LayerCache copyWith({
    double? baseSize,
    bool? isLoading,
    Map<String, Widget>? textWidgets,
    Map<String, Widget>? numericWidgets,
    Map<String, Widget>? dateWidgets,
    Map<int, Map<String, dynamic>>? numericSettings,
    Map<int, Map<String, dynamic>>? dateSettings,
  }) {
    return LayerCache(
      baseSize: baseSize ?? this.baseSize,
      isLoading: isLoading ?? this.isLoading,
      textWidgets: textWidgets ?? Map.from(this.textWidgets),
      numericWidgets: numericWidgets ?? Map.from(this.numericWidgets),
      dateWidgets: dateWidgets ?? Map.from(this.dateWidgets),
      numericSettings: numericSettings ?? Map.from(this.numericSettings),
      dateSettings: dateSettings ?? Map.from(this.dateSettings),
    );
  }
}

class LayerCacheNotifier extends Notifier<LayerCache> {
  @override
  LayerCache build() => const LayerCache(baseSize: 256.0);

  final _presetDao = PresetDao.instance;
  late Directory _cacheDir;

  Future<void> _initCacheDir() async {
    final dir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${dir.path}/layer_cache');
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  Future<void> loadAll({required double baseSize}) async {
    if (state.isLoading) {
      appLog('LayerCache: 既にロード中');
      return;
    }

    state = state.copyWith(isLoading: true);
    appLog('LayerCache: 全データ読み込み開始');

    try {
      await _initCacheDir();

      if (_cacheDir.existsSync()) {
        await _cacheDir.delete(recursive: true);
      }
      await _cacheDir.create(recursive: true);

      final textWidgets = <String, Widget>{};
      final numericSettings = <int, Map<String, dynamic>>{};
      final dateSettings = <int, Map<String, dynamic>>{};

      // テキストレイヤーのPNG生成
      for (int slotIndex = 1; slotIndex <= 6; slotIndex++) {
        for (int itemIndex = 1; itemIndex <= 20; itemIndex++) {
          final detail =
              await _presetDao.getTextItemDetail(slotIndex, itemIndex);
          if (detail == null) continue;

          final label = detail['label'] as String? ?? '';
          if (label.isEmpty) continue;

          final file =
              File('${_cacheDir.path}/text_${slotIndex}_$itemIndex.png');
          try {
            final pngBytes = await _renderTextToPng(detail, baseSize);
            if (pngBytes.isEmpty) continue;

            await file.writeAsBytes(pngBytes);
            final bytes = await file.readAsBytes();
            if (bytes.isEmpty) continue;

            textWidgets['${slotIndex}_$itemIndex'] = Positioned(
              left: (detail['posX'] ?? 0.5) * baseSize,
              top: (detail['posY'] ?? 0.5) * baseSize,
              child: Image.memory(bytes),
            );
          } catch (e, st) {
            appLog('テキストレイヤー生成失敗 ${slotIndex}_$itemIndex: $e\n$st');
            continue;
          }
        }
      }

      // 数値スロット設定読み込み
      for (int slotIndex = 1; slotIndex <= 6; slotIndex++) {
        final detail = await _presetDao.getSlotDetail(slotIndex, 'numeric');
        if (detail.isNotEmpty) {
          numericSettings[slotIndex] = Map.from(detail);
        }
      }

      // 日付スロット設定読み込み
      for (int slotIndex = 1; slotIndex <= 6; slotIndex++) {
        final detail = await _presetDao.getSlotDetail(slotIndex, 'date');
        if (detail.isNotEmpty) {
          dateSettings[slotIndex] = Map.from(detail);
        }
      }

      state = LayerCache(
        baseSize: baseSize,
        isLoading: false,
        textWidgets: textWidgets,
        numericWidgets: {},
        dateWidgets: {},
        numericSettings: numericSettings,
        dateSettings: dateSettings,
      );

      appLog('LayerCache: 読み込み完了');
    } catch (e, st) {
      appLog('LayerCache読み込みエラー: $e\n$st');
      state = state.copyWith(isLoading: false);
    }
  }

  Widget getNumericWidget(int slotIndex, int value) {
    final key = '${slotIndex}_$value';

    if (state.numericWidgets.containsKey(key)) {
      return state.numericWidgets[key]!;
    }

    final settings = state.numericSettings[slotIndex];
    if (settings == null) return const SizedBox.shrink();

    final posX = (settings['posX'] as num?)?.toDouble() ?? 0.5;
    final posY = (settings['posY'] as num?)?.toDouble() ?? 0.5;
    final file = File('${_cacheDir.path}/numeric_$key.png');

    if (file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();

        if (bytes.length < 50) {
          file.deleteSync();
        } else {
          final widget = Positioned(
            left: posX * state.baseSize,
            top: posY * state.baseSize,
            child: Image.memory(
              bytes,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!state.numericWidgets.containsKey(key)) {
              final updated = Map<String, Widget>.from(state.numericWidgets);
              updated[key] = widget;
              state = state.copyWith(numericWidgets: updated);
            }
          });

          return widget;
        }
      } catch (e) {
        file.deleteSync();
      }
    }

    return FutureBuilder(
      future: _renderNumericToPngAndCache(settings, value, slotIndex, file),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Positioned(
            left: posX * state.baseSize,
            top: posY * state.baseSize,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return snapshot.data!;
      },
    );
  }

  Widget getDateWidget(int slotIndex, int yyyymmdd) {
    final key = '${slotIndex}_$yyyymmdd';

    if (state.dateWidgets.containsKey(key)) {
      return state.dateWidgets[key]!;
    }

    final settings = state.dateSettings[slotIndex];
    if (settings == null) return const SizedBox.shrink();

    final posX = (settings['posX'] as num?)?.toDouble() ?? 0.5;
    final posY = (settings['posY'] as num?)?.toDouble() ?? 0.5;
    final file = File('${_cacheDir.path}/date_$key.png');

    if (file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();

        if (bytes.length < 50) {
          file.deleteSync();
        } else {
          final widget = Positioned(
            left: posX * state.baseSize,
            top: posY * state.baseSize,
            child: Image.memory(
              bytes,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!state.dateWidgets.containsKey(key)) {
              final updated = Map<String, Widget>.from(state.dateWidgets);
              updated[key] = widget;
              state = state.copyWith(dateWidgets: updated);
            }
          });

          return widget;
        }
      } catch (e) {
        file.deleteSync();
      }
    }

    return FutureBuilder(
      future: _renderDateToPngAndCache(settings, yyyymmdd, slotIndex, file),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Positioned(
            left: posX * state.baseSize,
            top: posY * state.baseSize,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return snapshot.data!;
      },
    );
  }

  Future<Widget> _renderNumericToPngAndCache(
    Map<String, dynamic> settings,
    int value,
    int slotIndex,
    File file,
  ) async {
    final tempFile = File('${file.path}.tmp');
    final bytes =
        await _renderNumericToPng(settings, value, state.baseSize, tempFile);

    final posX = (settings['posX'] as num?)?.toDouble() ?? 0.5;
    final posY = (settings['posY'] as num?)?.toDouble() ?? 0.5;

    final widget = Positioned(
      left: posX * state.baseSize,
      top: posY * state.baseSize,
      child: Image.memory(bytes),
    );

    if (await tempFile.exists()) {
      await tempFile.rename(file.path);
    }

    final key = '${slotIndex}_$value';
    final updated = Map<String, Widget>.from(state.numericWidgets);
    updated[key] = widget;
    state = state.copyWith(numericWidgets: updated);

    return widget;
  }

  Future<Widget> _renderDateToPngAndCache(
    Map<String, dynamic> settings,
    int yyyymmdd,
    int slotIndex,
    File file,
  ) async {
    final tempFile = File('${file.path}.tmp');
    final bytes =
        await _renderDateToPng(settings, yyyymmdd, state.baseSize, tempFile);

    final posX = (settings['posX'] as num?)?.toDouble() ?? 0.5;
    final posY = (settings['posY'] as num?)?.toDouble() ?? 0.5;

    final widget = Positioned(
      left: posX * state.baseSize,
      top: posY * state.baseSize,
      child: Image.memory(bytes),
    );

    if (await tempFile.exists()) {
      await tempFile.rename(file.path);
    }

    final key = '${slotIndex}_$yyyymmdd';
    final updated = Map<String, Widget>.from(state.dateWidgets);
    updated[key] = widget;
    state = state.copyWith(dateWidgets: updated);

    return widget;
  }

  Future<Uint8List> _renderTextToPng(
      Map<String, dynamic> detail, double baseSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final label = detail['label'] ?? '';
    final color = _parseColor(detail['color'] ?? '#FF000000');
    final bgColor = _parseColor(detail['backgroundColor'] ?? '#00000000');
    final fontSize = (detail['fontSize'] ?? 16).toDouble();
    final isVertical = (detail['isVertical'] ?? 0) == 1;

    // -----------------------------
    // 縦書きの場合
    // -----------------------------
    if (isVertical) {
      final lines = label.split('\n');

      double x = 0;
      double maxWidth = 0;
      double maxHeight = 0;

      // まずサイズ計測
      for (final line in lines.reversed) {
        double colHeight = 0;
        double colWidth = 0;

        for (final char in line.split('')) {
          final painter = TextPainter(
            text: TextSpan(
              text: char,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          painter.layout();

          colHeight += painter.height;
          colWidth = max(colWidth, painter.width);
        }

        maxHeight = max(maxHeight, colHeight);
        maxWidth += colWidth + 4; // 余白
      }

      // 背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, maxWidth, maxHeight),
        Paint()..color = bgColor,
      );

      // 実際の描画
      x = 0;
      for (final line in lines.reversed) {
        double y = 0;

        for (final char in line.split('')) {
          final painter = TextPainter(
            text: TextSpan(
              text: char,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          painter.layout();

          painter.paint(canvas, Offset(x, y));
          y += painter.height;
        }

        x += fontSize + 4; // 次の列へ
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(maxWidth.toInt(), maxHeight.toInt());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    }

    // -----------------------------
    // 横書き（従来どおり）
    // -----------------------------
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final width = painter.width + 4;
    final height = painter.height + 4;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = bgColor,
    );

    painter.paint(canvas, const Offset(2, 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);

    return png!.buffer.asUint8List();
  }

  Future<Uint8List> _renderNumericToPng(
    Map<String, dynamic> settings,
    int value,
    double baseSize,
    File file,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final front = settings['frontlabel'] ?? '';
    final after = settings['afterlabel'] ?? '';

    final useCommas = (settings['useThousandsSeparator'] ?? 0) == 1;
    final formattedValue =
        useCommas ? _formatNumberWithCommas(value) : value.toString();

    final display = '$front$formattedValue$after';

    final color = _parseColor(settings['color'] ?? '#FF000000');
    final bgColor = _parseColor(settings['backgroundColor'] ?? '#00000000');
    final fontSize = (settings['fontSize'] ?? 16).toDouble();
    final isVertical = (settings['isVertical'] ?? 0) == 1;

    // -----------------------------
    // 縦書き
    // -----------------------------
    if (isVertical) {
      final chars = display.split('');

      double maxWidth = 0;
      double totalHeight = 0;

      // サイズ計測
      for (final char in chars) {
        final painter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        painter.layout();

        totalHeight += painter.height;
        maxWidth = max(maxWidth, painter.width);
      }

      // 背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, maxWidth + 4, totalHeight + 4),
        Paint()..color = bgColor,
      );

      // 描画
      double y = 2;
      for (final char in chars) {
        final painter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        painter.layout();
        painter.paint(canvas, Offset(2, y));
        y += painter.height;
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (maxWidth + 4).toInt(),
        (totalHeight + 4).toInt(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = png!.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      return bytes;
    }

    // -----------------------------
    // 横書き（従来どおり）
    // -----------------------------
    final painter = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final width = painter.width + 4;
    final height = painter.height + 4;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = bgColor,
    );

    painter.paint(canvas, const Offset(2, 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = png!.buffer.asUint8List();
    await file.writeAsBytes(bytes);

    return bytes;
  }

  Future<Uint8List> _renderDateToPng(
    Map<String, dynamic> settings,
    int yyyymmdd,
    double baseSize,
    File file,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final dateStr = yyyymmdd.toString();
    final displayFormat = settings['displayFormat'] ?? 'yyyy/MM/dd';
    final formatted = _formatDate(dateStr, displayFormat);

    final front = settings['frontlabel'] ?? '';
    final after = settings['afterlabel'] ?? '';
    final display = '$front$formatted$after';

    final color = _parseColor(settings['color'] ?? '#FF000000');
    final bgColor = _parseColor(settings['backgroundColor'] ?? '#00000000');
    final fontSize = (settings['fontSize'] ?? 16).toDouble();
    final isVertical = (settings['isVertical'] ?? 0) == 1;

    // -----------------------------
    // 縦書き
    // -----------------------------
    if (isVertical) {
      final chars = display.split('');

      double maxWidth = 0;
      double totalHeight = 0;

      for (final char in chars) {
        final painter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        painter.layout();

        totalHeight += painter.height;
        maxWidth = max(maxWidth, painter.width);
      }

      canvas.drawRect(
        Rect.fromLTWH(0, 0, maxWidth + 4, totalHeight + 4),
        Paint()..color = bgColor,
      );

      double y = 2;
      for (final char in chars) {
        final painter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        painter.layout();
        painter.paint(canvas, Offset(2, y));
        y += painter.height;
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (maxWidth + 4).toInt(),
        (totalHeight + 4).toInt(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = png!.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      return bytes;
    }

    // -----------------------------
    // 横書き（従来どおり）
    // -----------------------------
    final painter = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final width = painter.width + 4;
    final height = painter.height + 4;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = bgColor,
    );

    painter.paint(canvas, const Offset(2, 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = png!.buffer.asUint8List();
    await file.writeAsBytes(bytes);

    return bytes;
  }

  String _formatDate(String yyyymmdd, String format) {
    final y = yyyymmdd.substring(0, 4);
    final m = yyyymmdd.substring(4, 6);
    final d = yyyymmdd.substring(6, 8);
    return format.replaceAll('yyyy', y).replaceAll('MM', m).replaceAll('dd', d);
  }

  String _formatNumberWithCommas(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    final length = str.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }

  Color _parseColor(String hex) {
    try {
      String hexColor = hex.replaceFirst('#', '');
      if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return Colors.black;
    } catch (_) {
      return Colors.black;
    }
  }
}

final layerCacheProvider = NotifierProvider<LayerCacheNotifier, LayerCache>(
  LayerCacheNotifier.new,
);
