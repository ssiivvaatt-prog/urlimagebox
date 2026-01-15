import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ✅ レイヤー編集画面の UI 状態
class LayerState {
  final int slotIndex;
  final int itemIndex;
  final bool isEditing;

  const LayerState({
    this.slotIndex = 1,
    this.itemIndex = 1,
    this.isEditing = false,
  });

  LayerState copyWith({
    int? slotIndex,
    int? itemIndex,
    bool? isEditing,
  }) {
    return LayerState(
      slotIndex: slotIndex ?? this.slotIndex,
      itemIndex: itemIndex ?? this.itemIndex,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

/// ✅ Notifier
class LayerNotifier extends Notifier<LayerState> {
  @override
  LayerState build() {
    return const LayerState();
  }

  void setSlotIndex(int index) {
    state = state.copyWith(slotIndex: index);
  }

  void setItemIndex(int index) {
    state = state.copyWith(itemIndex: index);
  }

  void setEditing(bool value) {
    state = state.copyWith(isEditing: value);
  }
}

/// ✅ Provider
final layerProvider = NotifierProvider<LayerNotifier, LayerState>(
  LayerNotifier.new,
);
