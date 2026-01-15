// lib/pages/text_item_detail_ui.dart

import '../providers/cards_provider.dart';

import '../../DB/CORE/local_db_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/logger.dart';
import '../../DB/DAO/preset_dao.dart';
import '../providers/sharedpreferences_provider.dart';

class TextItemDetailUi extends ConsumerStatefulWidget {
  final int slotIndex;
  final int itemIndex;

  const TextItemDetailUi({
    super.key,
    required this.slotIndex,
    required this.itemIndex,
  });

  @override
  ConsumerState<TextItemDetailUi> createState() => _TextItemDetailUiState();
}

class _TextItemDetailUiState extends ConsumerState<TextItemDetailUi> {
  final TextEditingController labelController = TextEditingController();
  late String selectedFont;
  late int fontSize;
  late Color color;
  late Color backgroundColor;
  late bool isVertical;
  late double posX;
  late double posY;
  final _presetDao = PresetDao.instance;

  @override
  void initState() {
    super.initState();

    selectedFont = 'Arial';
    fontSize = 12;
    color = Colors.black;
    backgroundColor = Colors.transparent;
    isVertical = false;
    posX = 0.5;
    posY = 0.5;

    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final db = await LocalDBService.instance.database;

      final result = await db.query(
        'text_item_detail',
        where: 'slotIndex = ? AND itemIndex = ?',
        whereArgs: [widget.slotIndex, widget.itemIndex],
      );

      if (result.isEmpty) {
        appLog('⚠️ No detail found for item ${widget.itemIndex}');
        return;
      }

      final data = Map<String, dynamic>.from(result.first);

      setState(() {
        labelController.text = data['label'] ?? '';
        selectedFont = data['font'] ?? 'Arial';
        fontSize = data['fontSize'] ?? 12;
        color = _parseColor(data['color'] ?? '#FF000000');
        backgroundColor = _parseColor(data['backgroundColor'] ?? '#00000000');
        isVertical = (data['isVertical'] ?? 0) == 1;
        posX = (data['posX'] as num?)?.toDouble() ?? 0.5;
        posY = (data['posY'] as num?)?.toDouble() ?? 0.5;
      });

      appLog('📥 Loaded detail for item ${widget.itemIndex}');
    } catch (e, st) {
      appLog('❌ _loadDetail error: $e\n$st');
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      String hexColor = hex.replaceFirst('#', '');

      // 8桁（AARRGGBB）
      if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }

      // 6桁（RRGGBB）→ 不透明として扱う
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }

      return Colors.black;
    } catch (_) {
      return Colors.black;
    }
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _saveField(String fieldName, dynamic value) async {
    try {
      await _presetDao.updateTextItemField(
        widget.slotIndex,
        widget.itemIndex,
        fieldName,
        value,
      );

      await ref
          .read(sharedpreferencesProvider.notifier)
          .setLayerWidgetValid(false);
// ✅ 追加：全カードProviderを無効化（準備未完了に戻す）
      ref.invalidate(cardsProvider);
      appLog('🔄 cardsProvider 無効化（キャッシュ再作成のため）');
      appLog('💾 Saved $fieldName: $value');
    } catch (e, st) {
      appLog('❌ _saveField error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー / Save Error: $e')),
        );
      }
    }
  }

  Widget _buildIntegratedPreview() {
    final displayText =
        labelController.text.isEmpty ? 'サンプル' : labelController.text;

    const previewSize = 256.0;

    return Center(
      child: SizedBox(
        width: previewSize,
        height: previewSize,
        child: GestureDetector(
          onTapDown: (details) {
            final localPosition = details.localPosition;

            setState(() {
              posX = (localPosition.dx / previewSize).clamp(0.0, 1.0);
              posY = (localPosition.dy / previewSize).clamp(0.0, 1.0);
            });

            _saveField('posX', posX);
            _saveField('posY', posY);

            appLog('Position updated: X=$posX, Y=$posY');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              border: Border.all(color: Colors.grey[600]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // 背景のグリッド線
                for (int i = 1; i < 4; i++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: previewSize * i / 4,
                    child: Container(height: 1, color: Colors.grey[400]),
                  ),
                for (int i = 1; i < 4; i++)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: previewSize * i / 4,
                    child: Container(width: 1, color: Colors.grey[400]),
                  ),

                // テキスト表示（左上が基準点、実寸フォント）
                Positioned(
                  left: posX * previewSize,
                  top: posY * previewSize,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: _buildTextWidget(displayText),
                  ),
                ),

                // 位置インジケーター（赤い点）- 左上の角
                Positioned(
                  left: posX * previewSize,
                  top: posY * previewSize,
                  child: Transform.translate(
                    offset: const Offset(-4, -4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextWidget(String text) {
    if (isVertical) {
      // 縦書き：右から左に読む（国語の教科書風）
      final lines = text.split('\n');

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.reversed.map((line) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: line.split('').map((char) {
                return Text(
                  char,
                  style: TextStyle(
                    fontFamily: selectedFont,
                    fontSize: fontSize.toDouble(),
                    color: color,
                    height: 1.0,
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      );
    } else {
      // 横書き：通常の表示
      return Text(
        text,
        style: TextStyle(
          fontFamily: selectedFont,
          fontSize: fontSize.toDouble(),
          color: color,
          height: 1.2,
        ),
        textAlign: TextAlign.left,
      );
    }
  }

  Future<void> _showColorPicker() async {
    appLog('=== Color Picker Debug ===');
    appLog('color: ${_colorToHex(color)}');

    final initialArgb = color.toARGB32();
    final initialAlphaInt = (initialArgb >> 24) & 0xFF;
    final initialAlpha = initialAlphaInt / 255.0;

    Color dialogColor = Color(initialArgb);
    double dialogAlpha = initialAlpha;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('文字色を選択 / Select Text Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('透過率 / Opacity'),
                    Slider(
                      value: dialogAlpha,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      label: '${(dialogAlpha * 100).toInt()}%',
                      onChanged: (value) {
                        setDialogState(() {
                          dialogAlpha = value;
                          final argb = dialogColor.toARGB32();
                          final rgb = argb & 0x00FFFFFF;
                          final newAlpha = (value * 255).toInt();
                          dialogColor = Color((newAlpha << 24) | rgb);
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() => color = dialogColor);
                        _saveField('color', _colorToHex(dialogColor));
                      },
                    ),
                    const SizedBox(height: 16),
                    HueRingPicker(
                      pickerColor: dialogColor,
                      onColorChanged: (Color value) {
                        setDialogState(() {
                          final argb = value.toARGB32();
                          final rgb = argb & 0x00FFFFFF;
                          final newAlpha = (dialogAlpha * 255).toInt();
                          dialogColor = Color((newAlpha << 24) | rgb);
                        });

                        setState(() => color = dialogColor);
                        _saveField('color', _colorToHex(dialogColor));
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          labelController.text.isEmpty
                              ? 'Sample'
                              : labelController.text,
                          style: TextStyle(
                            color: dialogColor,
                            fontSize: fontSize.toDouble(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('閉じる / Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBackgroundColorPicker() async {
    appLog('=== Background Color Picker Debug ===');
    appLog('backgroundColor: ${_colorToHex(backgroundColor)}');

    final initialArgb = backgroundColor.toARGB32();
    final initialAlphaInt = (initialArgb >> 24) & 0xFF;
    final initialAlpha = initialAlphaInt / 255.0;

    Color dialogColor = Color(initialArgb);
    double dialogAlpha = initialAlpha;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('背景色を選択 / Select Background Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('透過率 / Opacity'),
                    Slider(
                      value: dialogAlpha,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      label: '${(dialogAlpha * 100).toInt()}%',
                      onChanged: (value) {
                        setDialogState(() {
                          dialogAlpha = value;
                          final argb = dialogColor.toARGB32();
                          final rgb = argb & 0x00FFFFFF;
                          final newAlpha = (value * 255).toInt();
                          dialogColor = Color((newAlpha << 24) | rgb);
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() => backgroundColor = dialogColor);
                        _saveField('backgroundColor', _colorToHex(dialogColor));
                      },
                    ),
                    const SizedBox(height: 16),
                    HueRingPicker(
                      pickerColor: dialogColor,
                      onColorChanged: (Color value) {
                        setDialogState(() {
                          final argb = value.toARGB32();
                          final rgb = argb & 0x00FFFFFF;
                          final newAlpha = (dialogAlpha * 255).toInt();
                          dialogColor = Color((newAlpha << 24) | rgb);
                        });

                        setState(() => backgroundColor = dialogColor);
                        _saveField('backgroundColor', _colorToHex(dialogColor));
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: dialogColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          labelController.text.isEmpty
                              ? 'Sample'
                              : labelController.text,
                          style: TextStyle(
                            color: color,
                            fontSize: fontSize.toDouble(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('閉じる / Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ シンプルなタイトルに変更
    final title =
        '項目${widget.itemIndex} 詳細編集\nItem ${widget.itemIndex} Detail Edit';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 統合プレビュー
          const Text(
            'プレビュー / Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'タップで表示位置を変更できます（左上が基準点）\nTap to change position (Top-left corner is anchor)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildIntegratedPreview(),
          const SizedBox(height: 8),
          Text(
            '位置: X=${posX.toStringAsFixed(2)}, Y=${posY.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'ラベル / Label',
              border: OutlineInputBorder(),
              helperText: '改行も可能です（縦書きでは列が分かれます）\nLine breaks supported',
            ),
            maxLines: 3,
            onChanged: (val) {
              _saveField('label', val);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedFont,
            decoration: const InputDecoration(
              labelText: 'フォント / Font',
              border: OutlineInputBorder(),
            ),
            items: ['Arial', 'Verdana', 'Times New Roman', 'Courier']
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => selectedFont = val);
                _saveField('font', val);
              }
            },
          ),
          const SizedBox(height: 16),
          Text('フォントサイズ / Font Size: $fontSize'),
          Slider(
            value: fontSize.toDouble(),
            min: 8,
            max: 256,
            divisions: 248,
            onChanged: (val) {
              setState(() => fontSize = val.toInt());
            },
            onChangeEnd: (val) => _saveField('fontSize', val.toInt()),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('縦書き / Vertical Writing'),
            subtitle:
                Text(isVertical ? '縦書き表示 / Vertical' : '横書き表示 / Horizontal'),
            value: isVertical,
            onChanged: (val) {
              setState(() => isVertical = val);
              _saveField('isVertical', val ? 1 : 0);
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('文字色 / Text Color'),
            subtitle: const Text('透過率も設定可能 / Transparency adjustable'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: _showColorPicker,
          ),
          ListTile(
            title: const Text('背景色 / Background Color'),
            subtitle: const Text('透過率も設定可能 / Transparency adjustable'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: _showBackgroundColorPicker,
          ),
        ],
      ),
    );
  }
}
