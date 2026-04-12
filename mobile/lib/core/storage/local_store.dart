import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _favoritesKey = 'favorites';
  static const _recentKey = 'recent';
  static const _contentManifestKey = 'content_manifest';
  static const _matchingConfigKey = 'matching_config';
  static const _contentChecklistsKey = 'content_checklists';
  static const _contentLastSyncAtKey = 'content_last_sync_at';

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? const [];
  }

  Future<List<String>> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
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

  Future<DateTime?> loadContentLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_contentLastSyncAtKey);
    if (raw == null || raw <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
}
