import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

///　移動予定
///
///　    currentMode TEXT DEFAULT 'rotate',
///      currentRotateDirection TEXT DEFAULT 'right',
///      currentAttrSlotIndex INTEGER DEFAULT 1,
///      currentNumericSlotIndex INTEGER DEFAULT 1,
///      currentdateSlotIndex INTEGER DEFAULT 1,
///    　layerWidgetValid INTEGER NOT NULL DEFAULT 0,  -- 0=layerWidget無効, 1=キlayerWidget有効  元cacheValid
///
///

// ============================================================
// ✅ フィルター・ソート用のデータクラス
// ============================================================

/// 数値範囲フィルター(片方だけでもOK)
class NumericRange {
  final int? from;
  final int? to;

  const NumericRange({this.from, this.to});

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
      };

  factory NumericRange.fromJson(Map<String, dynamic> json) {
    return NumericRange(
      from: json['from'] as int?,
      to: json['to'] as int?,
    );
  }
}

/// 日付範囲フィルター(片方だけでもOK)
class DateRange {
  final int? from;
  final int? to;

  const DateRange({this.from, this.to});

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
      };

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      from: json['from'] as int?,
      to: json['to'] as int?,
    );
  }
}

/// フィルター設定
class FilterSettings {
  final List<String> selectedSeriesIds;
  final Map<int, Set<int>> textFilters; // {1: {0,3,5}, 2: {1,2}}
  final NumericRange? numeric1Range;
  final NumericRange? numeric2Range;
  final NumericRange? numeric3Range;
  final NumericRange? numeric4Range;
  final NumericRange? numeric5Range;
  final NumericRange? numeric6Range;
  final DateRange? date1Range;
  final DateRange? date2Range;
  final DateRange? date3Range;
  final DateRange? date4Range;
  final DateRange? date5Range;
  final DateRange? date6Range;
  final bool useAndCondition; // ✅ 追加: true=AND条件, false=OR条件

  const FilterSettings({
    this.selectedSeriesIds = const [],
    this.textFilters = const {},
    this.numeric1Range,
    this.numeric2Range,
    this.numeric3Range,
    this.numeric4Range,
    this.numeric5Range,
    this.numeric6Range,
    this.date1Range,
    this.date2Range,
    this.date3Range,
    this.date4Range,
    this.date5Range,
    this.date6Range,
    this.useAndCondition = true, // ✅ デフォルトはAND条件
  });

  Map<String, dynamic> toJson() {
    return {
      'selectedSeriesIds': selectedSeriesIds,
      'textFilters': textFilters.map(
        (k, v) => MapEntry(k.toString(), v.toList()),
      ),
      'numeric1Range': numeric1Range?.toJson(),
      'numeric2Range': numeric2Range?.toJson(),
      'numeric3Range': numeric3Range?.toJson(),
      'numeric4Range': numeric4Range?.toJson(),
      'numeric5Range': numeric5Range?.toJson(),
      'numeric6Range': numeric6Range?.toJson(),
      'date1Range': date1Range?.toJson(),
      'date2Range': date2Range?.toJson(),
      'date3Range': date3Range?.toJson(),
      'date4Range': date4Range?.toJson(),
      'date5Range': date5Range?.toJson(),
      'date6Range': date6Range?.toJson(),
      'useAndCondition': useAndCondition, // ✅ 追加
    };
  }

  factory FilterSettings.fromJson(Map<String, dynamic> json) {
    return FilterSettings(
      selectedSeriesIds: (json['selectedSeriesIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      textFilters: (json['textFilters'] as Map?)?.map(
            (k, v) => MapEntry(
              int.parse(k),
              (v as List).map((e) => e as int).toSet(),
            ),
          ) ??
          {},
      numeric1Range: json['numeric1Range'] != null
          ? NumericRange.fromJson(json['numeric1Range'])
          : null,
      numeric2Range: json['numeric2Range'] != null
          ? NumericRange.fromJson(json['numeric2Range'])
          : null,
      numeric3Range: json['numeric3Range'] != null
          ? NumericRange.fromJson(json['numeric3Range'])
          : null,
      numeric4Range: json['numeric4Range'] != null
          ? NumericRange.fromJson(json['numeric4Range'])
          : null,
      numeric5Range: json['numeric5Range'] != null
          ? NumericRange.fromJson(json['numeric5Range'])
          : null,
      numeric6Range: json['numeric6Range'] != null
          ? NumericRange.fromJson(json['numeric6Range'])
          : null,
      date1Range: json['date1Range'] != null
          ? DateRange.fromJson(json['date1Range'])
          : null,
      date2Range: json['date2Range'] != null
          ? DateRange.fromJson(json['date2Range'])
          : null,
      date3Range: json['date3Range'] != null
          ? DateRange.fromJson(json['date3Range'])
          : null,
      date4Range: json['date4Range'] != null
          ? DateRange.fromJson(json['date4Range'])
          : null,
      date5Range: json['date5Range'] != null
          ? DateRange.fromJson(json['date5Range'])
          : null,
      date6Range: json['date6Range'] != null
          ? DateRange.fromJson(json['date6Range'])
          : null,
      useAndCondition: json['useAndCondition'] as bool? ?? true, // ✅ 追加
    );
  }

  FilterSettings copyWith({
    List<String>? selectedSeriesIds,
    Map<int, Set<int>>? textFilters,
    NumericRange? numeric1Range,
    NumericRange? numeric2Range,
    NumericRange? numeric3Range,
    NumericRange? numeric4Range,
    NumericRange? numeric5Range,
    NumericRange? numeric6Range,
    DateRange? date1Range,
    DateRange? date2Range,
    DateRange? date3Range,
    DateRange? date4Range,
    DateRange? date5Range,
    DateRange? date6Range,
    bool? useAndCondition, // ✅ 追加
  }) {
    return FilterSettings(
      selectedSeriesIds: selectedSeriesIds ?? this.selectedSeriesIds,
      textFilters: textFilters ?? this.textFilters,
      numeric1Range: numeric1Range ?? this.numeric1Range,
      numeric2Range: numeric2Range ?? this.numeric2Range,
      numeric3Range: numeric3Range ?? this.numeric3Range,
      numeric4Range: numeric4Range ?? this.numeric4Range,
      numeric5Range: numeric5Range ?? this.numeric5Range,
      numeric6Range: numeric6Range ?? this.numeric6Range,
      date1Range: date1Range ?? this.date1Range,
      date2Range: date2Range ?? this.date2Range,
      date3Range: date3Range ?? this.date3Range,
      date4Range: date4Range ?? this.date4Range,
      date5Range: date5Range ?? this.date5Range,
      date6Range: date6Range ?? this.date6Range,
      useAndCondition: useAndCondition ?? this.useAndCondition, // ✅ 追加
    );
  }
}

/// ソートフィールド
enum SortField {
  sortIndex,
  name,
  cardNumber,
  numeric1,
  numeric2,
  numeric3,
  numeric4,
  numeric5,
  numeric6,
  date1,
  date2,
  date3,
  date4,
  date5,
  date6,
}

/// ソート条件
class SortCondition {
  final SortField field;
  final bool ascending; // true=昇順, false=降順

  const SortCondition({
    required this.field,
    this.ascending = false, // ✅ 変更: true → false（降順がデフォルト）
  });

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'ascending': ascending,
      };

  factory SortCondition.fromJson(Map<String, dynamic> json) {
    return SortCondition(
      field: SortField.values.firstWhere((e) => e.name == json['field']),
      ascending: json['ascending'] as bool? ?? false, // ✅ デフォルト降順
    );
  }
}

// ============================================================
// ✅ アプリ全体の永続設定（SharedPreferences）を保持する State
// ============================================================
class SharedPreferencesState {
  final int allCardsColumnCount;

  final String currentMode;
  final String currentRotateDirection;

  final int currentAttrSlotIndex;
  final int currentNumericSlotIndex;
  final int currentDateSlotIndex;

  final bool layerWidgetValid;

  // ✅ フィルター・ソート
  final FilterSettings filterSettings;
  final List<SortCondition> sortConditions;

  const SharedPreferencesState({
    this.allCardsColumnCount = 3,
    this.currentMode = 'rotate',
    this.currentRotateDirection = 'right',
    this.currentAttrSlotIndex = 1,
    this.currentNumericSlotIndex = 1,
    this.currentDateSlotIndex = 1,
    this.layerWidgetValid = false,
    this.filterSettings = const FilterSettings(),
    this.sortConditions = const [],
  });

  SharedPreferencesState copyWith({
    int? allCardsColumnCount,
    String? currentMode,
    String? currentRotateDirection,
    int? currentAttrSlotIndex,
    int? currentNumericSlotIndex,
    int? currentDateSlotIndex,
    bool? layerWidgetValid,
    FilterSettings? filterSettings,
    List<SortCondition>? sortConditions,
  }) {
    return SharedPreferencesState(
      allCardsColumnCount: allCardsColumnCount ?? this.allCardsColumnCount,
      currentMode: currentMode ?? this.currentMode,
      currentRotateDirection:
          currentRotateDirection ?? this.currentRotateDirection,
      currentAttrSlotIndex: currentAttrSlotIndex ?? this.currentAttrSlotIndex,
      currentNumericSlotIndex:
          currentNumericSlotIndex ?? this.currentNumericSlotIndex,
      currentDateSlotIndex: currentDateSlotIndex ?? this.currentDateSlotIndex,
      layerWidgetValid: layerWidgetValid ?? this.layerWidgetValid,
      filterSettings: filterSettings ?? this.filterSettings,
      sortConditions: sortConditions ?? this.sortConditions,
    );
  }
}

/// ✅ Notifier（SharedPreferences の読み書きを担当）
class SharedPreferencesNotifier extends Notifier<SharedPreferencesState> {
  @override
  SharedPreferencesState build() {
    final initial = const SharedPreferencesState();
    _load(); // 非同期読み込み
    return initial;
  }

  /// ✅ SharedPreferences から設定を読み込む
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // フィルター設定の読み込み
    FilterSettings filterSettings = const FilterSettings();
    final filterJson = prefs.getString('filterSettings');
    if (filterJson != null) {
      try {
        filterSettings = FilterSettings.fromJson(jsonDecode(filterJson));
      } catch (e) {
        // パースエラー時はデフォルト値を使用
      }
    }

    // ソート条件の読み込み
    List<SortCondition> sortConditions = [];
    final sortJson = prefs.getString('sortConditions');
    if (sortJson != null) {
      try {
        final list = jsonDecode(sortJson) as List;
        sortConditions = list.map((e) => SortCondition.fromJson(e)).toList();
      } catch (e) {
        // パースエラー時はデフォルト値を使用
      }
    }

    state = state.copyWith(
      allCardsColumnCount: prefs.getInt('allCardsColumnCount') ?? 3,
      currentMode: prefs.getString('currentMode') ?? 'rotate',
      currentRotateDirection:
          prefs.getString('currentRotateDirection') ?? 'right',
      currentAttrSlotIndex: prefs.getInt('currentAttrSlotIndex') ?? 1,
      currentNumericSlotIndex: prefs.getInt('currentNumericSlotIndex') ?? 1,
      currentDateSlotIndex: prefs.getInt('currentDateSlotIndex') ?? 1,
      layerWidgetValid: prefs.getBool('layerWidgetValid') ?? false,
      filterSettings: filterSettings,
      sortConditions: sortConditions,
    );
  }

  /// ✅ setter 群（永続化も行う）

  Future<void> setAllCardsColumnCount(int value) async {
    state = state.copyWith(allCardsColumnCount: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('allCardsColumnCount', value);
  }

  Future<void> setCurrentMode(String value) async {
    state = state.copyWith(currentMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentMode', value);
  }

  Future<void> setCurrentRotateDirection(String value) async {
    state = state.copyWith(currentRotateDirection: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentRotateDirection', value);
  }

  Future<void> setCurrentAttrSlotIndex(int value) async {
    state = state.copyWith(currentAttrSlotIndex: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentAttrSlotIndex', value);
  }

  Future<void> setCurrentNumericSlotIndex(int value) async {
    state = state.copyWith(currentNumericSlotIndex: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentNumericSlotIndex', value);
  }

  Future<void> setCurrentDateSlotIndex(int value) async {
    state = state.copyWith(currentDateSlotIndex: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentDateSlotIndex', value);
  }

  Future<void> setLayerWidgetValid(bool value) async {
    state = state.copyWith(layerWidgetValid: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('layerWidgetValid', value);
  }

  // ============================================================
  // ✅ フィルター・ソート用 setter
  // ============================================================

  Future<void> setFilterSettings(FilterSettings value) async {
    state = state.copyWith(filterSettings: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filterSettings', jsonEncode(value.toJson()));
  }

  Future<void> setSortConditions(List<SortCondition> value) async {
    state = state.copyWith(sortConditions: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'sortConditions',
      jsonEncode(value.map((e) => e.toJson()).toList()),
    );
  }
}

/// ✅ Provider
final sharedpreferencesProvider =
    NotifierProvider<SharedPreferencesNotifier, SharedPreferencesState>(
  SharedPreferencesNotifier.new,
);
