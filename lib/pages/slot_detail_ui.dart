import '../providers/cards_provider.dart';
import '../providers/layer_cache_provider.dart';
import '../providers/sharedpreferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DB/DAO/preset_dao.dart';
import '../../utils/logger.dart';

class SlotDetailUi extends ConsumerStatefulWidget {
  final int slotIndex;
  final String mode;

  const SlotDetailUi({
    super.key,
    required this.slotIndex,
    required this.mode,
  });

  @override
  ConsumerState<SlotDetailUi> createState() => _SlotDetailUiState();
}

class _SlotDetailUiState extends ConsumerState<SlotDetailUi> {
  final TextEditingController frontLabelController = TextEditingController();
  final TextEditingController afterLabelController = TextEditingController();
  late String selectedFont;
  late int fontSize;
  late Color color;
  late Color backgroundColor;
  late bool isVertical;
  late double posX;
  late double posY;
  String slotName = '';
  late bool useThousandsSeparator;
  late String displayFormat; // ✅ 変更: Controller から String に

  // ✅ 追加: 日付フォーマット選択肢
  static const List<String> _dateFormatOptions = [
    'yyyy/MM/dd', // 2025/12/25
    'yyyy-MM-dd', // 2025-12-25
    'yy/MM/dd', // 25/12/25
    'MM/dd/yyyy', // 12/25/2025
    'dd/MM/yyyy', // 25/12/2025
    'yyyy年MM月dd日', // 2025年12月25日
    'MM月dd日', // 12月25日
    'yyyyMMdd', // 20251225
  ];

  String _getTitle() {
    if (slotName.isNotEmpty) {
      return '詳細編集 / Detail Edit\n$slotName';
    }
    return 'スロット${widget.slotIndex} 詳細 / Slot ${widget.slotIndex} Settings';
  }

  @override
  void initState() {
    super.initState();

    // ✅ 初期値を設定
    selectedFont = 'Arial';
    fontSize = 12;
    color = Colors.black;
    backgroundColor = Colors.transparent;
    isVertical = false;
    posX = 0.5;
    posY = 0.5;
    useThousandsSeparator = false;
    displayFormat = 'yyyy/MM/dd'; // ✅ 追加

    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final presetDao = PresetDao.instance;
      final data = await presetDao.getSlotDetail(
        widget.slotIndex,
        widget.mode,
      );

      setState(() {
        slotName = data['name'] ?? '';

        frontLabelController.text = data['frontlabel'] ?? '';
        afterLabelController.text = data['afterlabel'] ?? '';

        selectedFont = data['font'] ?? 'Arial';
        fontSize = data['fontSize'] ?? 12;

        color = _parseColor(data['color'] ?? '#FF000000');
        backgroundColor = _parseColor(data['backgroundColor'] ?? '#00000000');

        isVertical = (data['isVertical'] ?? 0) == 1;

        posX = (data['posX'] as num?)?.toDouble() ?? 0.5;
        posY = (data['posY'] as num?)?.toDouble() ?? 0.5;

        // ✅ numeric用
        if (widget.mode == 'numeric') {
          useThousandsSeparator = (data['useThousandsSeparator'] ?? 0) == 1;
        }

        // ✅ date用
        if (widget.mode == 'date') {
          displayFormat = data['displayFormat'] ?? 'yyyy/MM/dd';
        }
      });

      appLog('📥 Loaded detail for slot ${widget.slotIndex}');
    } catch (e, st) {
      appLog('❌ _loadDetail error: $e\n$st');
    }
  }

  @override
  void dispose() {
    frontLabelController.dispose();
    afterLabelController.dispose();
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
      final updateData = {fieldName: value};
      final presetDao = PresetDao.instance;
      await presetDao.updateSlotDetail(
        widget.slotIndex,
        updateData,
        widget.mode,
      );

      await ref
          .read(sharedpreferencesProvider.notifier)
          .setLayerWidgetValid(false);
      ref.invalidate(cardsProvider);
      ref.invalidate(layerCacheProvider); // ✅ 追加
      appLog('🔄 cardsProvider 無効化（キャッシュ再作成のため）');

      await _loadDetail();
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
    final frontText = frontLabelController.text;
    final afterText = afterLabelController.text;
    final displayText = () {
      if (widget.mode == 'numeric') {
        final sampleNum = 123456;
        final formatted = useThousandsSeparator
            ? _formatNumberWithCommas(sampleNum)
            : sampleNum.toString();
        return '$frontText$formatted$afterText';
      } else if (widget.mode == 'date') {
        final now = DateTime.now();
        final formatted = _formatDate(now, displayFormat);
        return '$frontText$formatted$afterText';
      } else {
        return '$frontText$afterText';
      }
    }();

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

                // テキスト表示
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

                // 位置インジケーター
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: text.split('').map((char) {
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
      );
    } else {
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
                          '${frontLabelController.text}Sample${afterLabelController.text}',
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
                          '${frontLabelController.text}Sample${afterLabelController.text}',
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          _getTitle(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
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
            controller: frontLabelController,
            decoration: const InputDecoration(
              labelText: '前ラベル / Front Label',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              _saveField('frontlabel', val);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: afterLabelController,
            decoration: const InputDecoration(
              labelText: '後ラベル / After Label',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              _saveField('afterlabel', val);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          // ✅ 修正: 日付フォーマット（Dropdown）
          if (widget.mode == 'date') ...[
            DropdownButtonFormField<String>(
              key: ValueKey(displayFormat), // ✅ 追加: 値が変わったら再構築
              initialValue: _dateFormatOptions.contains(displayFormat)
                  ? displayFormat
                  : _dateFormatOptions.first,
              decoration: const InputDecoration(
                labelText: '表示フォーマット / Display Format',
                border: OutlineInputBorder(),
                helperText: 'yyyy: 4桁年, yy: 2桁年, MM: 月, dd: 日',
              ),
              items: _dateFormatOptions.map((format) {
                final sample = _formatDate(DateTime(2025, 12, 25), format);
                return DropdownMenuItem(
                  value: format,
                  child: Text('$format  (例: $sample)'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => displayFormat = val);
                  _saveField('displayFormat', val);
                }
              },
            ),
            const SizedBox(height: 16),
          ],

          // ✅ 3桁カンマ区切り（numeric モードのみ）
          if (widget.mode == 'numeric') ...[
            SwitchListTile(
              title: const Text('3桁カンマ区切り / Thousands Separator'),
              subtitle: Text(useThousandsSeparator
                  ? '123,456 形式 / With commas'
                  : '123456 形式 / Without commas'),
              value: useThousandsSeparator,
              onChanged: (val) {
                setState(() => useThousandsSeparator = val);
                _saveField('useThousandsSeparator', val ? 1 : 0);
              },
            ),
            const SizedBox(height: 16),
          ],

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

  String _formatDate(DateTime date, String format) {
    final y = date.year.toString();

    return format
        .replaceAll('yyyy', y)
        .replaceAll('yy', y.substring(2)) // ✅ 2桁年対応
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('dd', date.day.toString().padLeft(2, '0'));
  }
}
