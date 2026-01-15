// lib/widgets/card_grid_item_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/layer_cache_provider.dart';
import '../providers/sharedpreferences_provider.dart';

class CardGridItemWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic> card;
  final Map<String, dynamic> series;

  const CardGridItemWidget({
    super.key,
    required this.card,
    required this.series,
  });

  @override
  ConsumerState<CardGridItemWidget> createState() => _CardGridItemWidgetState();
}

class _CardGridItemWidgetState extends ConsumerState<CardGridItemWidget> {
  double _lastAngle = 0.0;

  List<Widget>? _cachedLayers;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _lastAngle = (widget.card['rotationAngle'] ?? 0).toDouble();
  }

  @override
  void didUpdateWidget(covariant CardGridItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newAngle = (widget.card['rotationAngle'] ?? 0).toDouble();
    if (newAngle != _lastAngle) {
      _lastAngle = newAngle;
    }

    final newKey = _buildCacheKey();
    if (_cacheKey != newKey) {
      _cachedLayers = null;
      _cacheKey = newKey;
    }
  }

  String _buildCacheKey() {
    final c = widget.card;
    return '${c['seriesId']}_${c['number']}_'
        '${c['attr1']}_${c['attr2']}_${c['attr3']}_${c['attr4']}_${c['attr5']}_${c['attr6']}_'
        '${c['numeric1']}_${c['numeric2']}_${c['numeric3']}_${c['numeric4']}_${c['numeric5']}_${c['numeric6']}_'
        '${c['date1']}_${c['date2']}_${c['date3']}_${c['date4']}_${c['date5']}_${c['date6']}';
  }

  List<Widget> _buildLayersSync() {
    if (_cachedLayers != null) return _cachedLayers!;

    final cache = ref.read(layerCacheProvider);
    final card = widget.card;

    final layers = <Widget>[];

    // text
    for (int i = 1; i <= 6; i++) {
      final v = card['attr$i'] ?? 0;
      if (v != 0) {
        final w = cache.textWidgets['${i}_$v'];
        if (w != null) layers.add(w);
      }
    }

    // numeric
    for (int i = 1; i <= 6; i++) {
      final v = card['numeric$i'] ?? 0;
      if (v != 0) {
        final w = cache.numericWidgets['${i}_$v'];
        if (w != null) {
          layers.add(w);
        } else {
          layers.add(
            ref.read(layerCacheProvider.notifier).getNumericWidget(i, v),
          );
        }
      }
    }

    // date
    for (int i = 1; i <= 6; i++) {
      final v = card['date$i'] ?? 0;
      if (v != 0) {
        final w = cache.dateWidgets['${i}_$v'];
        if (w != null) {
          layers.add(w);
        } else {
          layers.add(
            ref.read(layerCacheProvider.notifier).getDateWidget(i, v),
          );
        }
      }
    }

    _cachedLayers = layers;
    return layers;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedpreferencesProvider);
    final cache = ref.watch(layerCacheProvider);

    // ✅ ローディング中 or 未初期化
    if (!prefs.layerWidgetValid || cache.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!prefs.layerWidgetValid) {
          await ref.read(layerCacheProvider.notifier).loadAll(baseSize: 256.0);
          await ref
              .read(sharedpreferencesProvider.notifier)
              .setLayerWidgetValid(true);
        }
      });

      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final imagePath = widget.card['imagePath'] as String?;
    final imageWidget = imagePath != null && File(imagePath).existsSync()
        ? Image.file(File(imagePath), fit: BoxFit.contain)
        : Image.asset('assets/placeholder.png', fit: BoxFit.contain);

    final currentAngle = (widget.card['rotationAngle'] ?? 0).toDouble();
    final targetTurns = currentAngle / 360.0;
    final animate = (currentAngle != _lastAngle);

    return Container(
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final displaySize = constraints.maxWidth;
            final baseSize = 256.0;
            final scale = displaySize / baseSize;

            final layers = _buildLayersSync();

            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: targetTurns,
                  duration: animate
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  child: imageWidget,
                ),
                Transform.scale(
                  scale: scale,
                  alignment:
                      scale >= 1.0 ? Alignment.center : Alignment.topLeft,
                  child: SizedBox(
                    width: baseSize,
                    height: baseSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: layers,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
