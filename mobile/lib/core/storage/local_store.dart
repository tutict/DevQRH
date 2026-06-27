import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/i18n/app_localizations.dart';

class LocalStore {
  static const _favoritesKey = 'favorites';
  static const _recentKey = 'recent';
  static const _recentSearchesKey = 'recent_searches';
  static const _contentManifestKey = 'content_manifest';
  static const _matchingConfigKey = 'matching_config';
  static const _contentChecklistsKey = 'content_checklists';
  static const _contentLastSyncAtKey = 'content_last_sync_at';
  static const _learningManifestKey = 'learning_manifest';
  static const _learningMatchingConfigKey = 'learning_matching_config';
  static const _learningMaterialsKey = 'learning_materials';
  static const _learningDecksKey = 'learning_decks';
  static const _learningCardsKey = 'learning_cards';
  static const _learningReviewStatesKey = 'learning_review_states';
  static const _learningLastSyncAtKey = 'learning_last_sync_at';
  static const _catalogFilterKey = 'catalog_filter';
  static const _catalogSelectedTagKey = 'catalog_selected_tag';
  static const _catalogSelectedTagsKey = 'catalog_selected_tags';
  static const _catalogSortKey = 'catalog_sort';
  static const _catalogRecentTagsKey = 'catalog_recent_tags';
  static const _catalogPresetsKey = 'catalog_presets';
  static const _appLocaleModeKey = 'app_locale_mode';
  static const _appThemeModeKey = 'app_theme_mode';

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? const [];
  }

  Future<List<String>> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  Future<List<String>> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<List<String>> toggleFavorite(String checklistId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_favoritesKey) ?? <String>[];
    final updated = List<String>.from(current);
    if (updated.contains(checklistId)) {
      updated.remove(checklistId);
    } else {
      updated.insert(0, checklistId);
    }
    await prefs.setStringList(_favoritesKey, updated);
    return updated;
  }

  Future<List<String>> pushRecent(String checklistId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentKey) ?? <String>[];
    final updated = <String>[
      checklistId,
      ...current.where((item) => item != checklistId),
    ];
    final trimmed = updated.take(8).toList();
    await prefs.setStringList(_recentKey, trimmed);
    return trimmed;
  }

  Future<List<String>> pushRecentSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return loadRecentSearches();
    }

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentSearchesKey) ?? <String>[];
    final updated = <String>[
      query,
      ...current.where((item) => item.toLowerCase() != query.toLowerCase()),
    ];
    final trimmed = updated.take(8).toList();
    await prefs.setStringList(_recentSearchesKey, trimmed);
    return trimmed;
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> saveContentCache({
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> matchingConfig,
    required List<Map<String, dynamic>> checklists,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentManifestKey, jsonEncode(manifest));
    await prefs.setString(_matchingConfigKey, jsonEncode(matchingConfig));
    await prefs.setString(_contentChecklistsKey, jsonEncode(checklists));
  }

  Future<Map<String, dynamic>?> loadCachedManifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentManifestKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadCachedChecklists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentChecklistsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>?> loadCachedMatchingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_matchingConfigKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveContentLastSyncAt(DateTime syncedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_contentLastSyncAtKey, syncedAt.millisecondsSinceEpoch);
  }

  Future<void> clearContentCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contentManifestKey);
    await prefs.remove(_matchingConfigKey);
    await prefs.remove(_contentChecklistsKey);
    await prefs.remove(_contentLastSyncAtKey);
  }

  Future<DateTime?> loadContentLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_contentLastSyncAtKey);
    if (raw == null || raw <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> saveLearningCache({
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> matchingConfig,
    required List<Map<String, dynamic>> materials,
    required List<Map<String, dynamic>> decks,
    required List<Map<String, dynamic>> cards,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_learningManifestKey, jsonEncode(manifest));
    await prefs.setString(
      _learningMatchingConfigKey,
      jsonEncode(matchingConfig),
    );
    await prefs.setString(_learningMaterialsKey, jsonEncode(materials));
    await prefs.setString(_learningDecksKey, jsonEncode(decks));
    await prefs.setString(_learningCardsKey, jsonEncode(cards));
  }

  Future<Map<String, dynamic>?> loadCachedLearningManifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningManifestKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> loadCachedLearningMatchingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningMatchingConfigKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadCachedLearningMaterials() async {
    return _loadJsonMapList(_learningMaterialsKey);
  }

  Future<List<Map<String, dynamic>>> loadCachedLearningDecks() async {
    return _loadJsonMapList(_learningDecksKey);
  }

  Future<List<Map<String, dynamic>>> loadCachedLearningCards() async {
    return _loadJsonMapList(_learningCardsKey);
  }

  Future<void> saveLearningReviewStates(
    List<Map<String, dynamic>> states,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_learningReviewStatesKey, jsonEncode(states));
  }

  Future<List<Map<String, dynamic>>> loadLearningReviewStates() async {
    return _loadJsonMapList(_learningReviewStatesKey);
  }

  Future<void> saveLearningLastSyncAt(DateTime syncedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _learningLastSyncAtKey,
      syncedAt.millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> loadLearningLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_learningLastSyncAtKey);
    if (raw == null || raw <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> clearLearningCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_learningManifestKey);
    await prefs.remove(_learningMatchingConfigKey);
    await prefs.remove(_learningMaterialsKey);
    await prefs.remove(_learningDecksKey);
    await prefs.remove(_learningCardsKey);
    await prefs.remove(_learningLastSyncAtKey);
  }

  Future<List<Map<String, dynamic>>> _loadJsonMapList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }
  Future<void> saveCatalogPreferences({
    required String filter,
    required List<String> selectedTags,
    required String sort,
    required List<String> recentTags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catalogFilterKey, filter);
    await prefs.setString(_catalogSortKey, sort);
    await prefs.setStringList(_catalogSelectedTagsKey, selectedTags);
    await prefs.setStringList(_catalogRecentTagsKey, recentTags);
    if (selectedTags.isEmpty) {
      await prefs.remove(_catalogSelectedTagKey);
    } else {
      await prefs.setString(_catalogSelectedTagKey, selectedTags.first);
    }
  }

  Future<CatalogPreferencesSnapshot> loadCatalogPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedTags =
        prefs.getStringList(_catalogSelectedTagsKey) ??
        [
          if ((prefs.getString(_catalogSelectedTagKey) ?? '').isNotEmpty)
            prefs.getString(_catalogSelectedTagKey)!,
        ];
    return CatalogPreferencesSnapshot(
      filter: prefs.getString(_catalogFilterKey) ?? '',
      selectedTags: selectedTags,
      sort: prefs.getString(_catalogSortKey) ?? '',
      recentTags: prefs.getStringList(_catalogRecentTagsKey) ?? const [],
    );
  }

  Future<void> saveCatalogPresets(List<CatalogFilterPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _catalogPresetsKey,
      jsonEncode(presets.map((preset) => preset.toJson()).toList()),
    );
  }

  Future<List<CatalogFilterPreset>> loadCatalogPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogPresetsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map(
          (item) => CatalogFilterPreset.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> saveAppLocaleMode(AppLocaleMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLocaleModeKey, mode.name);
  }

  Future<AppLocaleMode> loadAppLocaleMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appLocaleModeKey);
    return AppLocaleMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AppLocaleMode.system,
    );
  }

  Future<void> saveAppThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appThemeModeKey, mode.name);
  }

  Future<ThemeMode> loadAppThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appThemeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}

class CatalogPreferencesSnapshot {
  const CatalogPreferencesSnapshot({
    required this.filter,
    required this.selectedTags,
    required this.sort,
    required this.recentTags,
  });

  final String filter;
  final List<String> selectedTags;
  final String sort;
  final List<String> recentTags;
}

class CatalogFilterPreset {
  const CatalogFilterPreset({
    required this.name,
    required this.filter,
    required this.selectedTags,
    required this.sort,
  });

  factory CatalogFilterPreset.fromJson(Map<String, dynamic> json) {
    return CatalogFilterPreset(
      name: json['name'] as String? ?? '',
      filter: json['filter'] as String? ?? '',
      selectedTags: (json['selectedTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      sort: json['sort'] as String? ?? '',
    );
  }

  final String name;
  final String filter;
  final List<String> selectedTags;
  final String sort;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filter': filter,
      'selectedTags': selectedTags,
      'sort': sort,
    };
  }
}
