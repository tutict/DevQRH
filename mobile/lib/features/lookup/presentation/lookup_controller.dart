import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../data/lookup_repository.dart';
import '../domain/models.dart';

final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  return LookupRepository(ref.watch(localStoreProvider));
});

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore());

final favoritesProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<List<String>>>((ref) {
      return FavoritesController(ref.watch(localStoreProvider))..load();
    });

final recentProvider =
    StateNotifierProvider<RecentController, AsyncValue<List<String>>>((ref) {
      return RecentController(ref.watch(localStoreProvider))..load();
    });

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesController, AsyncValue<List<String>>>((
      ref,
    ) {
      return RecentSearchesController(ref.watch(localStoreProvider))..load();
    });

final lookupControllerProvider =
    StateNotifierProvider<LookupController, AsyncValue<LookupResponse?>>((ref) {
      return LookupController(ref.watch(lookupRepositoryProvider));
    });

final agentControllerProvider = StateNotifierProvider<AgentController,
    AsyncValue<AgentNavigationResponse?>>((ref) {
  return AgentController(ref.watch(lookupRepositoryProvider));
});

final contentSyncProvider =
    StateNotifierProvider<ContentSyncController, ContentSyncState>((ref) {
      return ContentSyncController(
        ref.watch(lookupRepositoryProvider),
        ref.watch(localStoreProvider),
      )..bootstrap();
    });

final checklistDetailProvider = FutureProvider.family<Checklist, String>((
  ref,
  checklistId,
) async {
  final cached = ref.watch(checklistIndexProvider)[checklistId];
  if (cached != null) {
    return cached;
  }

  final resolved = await ref
      .watch(lookupRepositoryProvider)
      .findChecklist(checklistId);
  if (resolved != null) {
    return resolved;
  }

  throw StateError('Checklist not found: $checklistId');
});

final checklistSummaryProvider = FutureProvider.family<Checklist?, String>((
  ref,
  checklistId,
) async {
  final cached = ref.watch(checklistIndexProvider)[checklistId];
  if (cached != null) {
    return cached;
  }

  return ref.watch(lookupRepositoryProvider).findChecklist(checklistId);
});

final contentCatalogProvider = Provider<List<Checklist>>((ref) {
  return ref.watch(contentSyncProvider).bootstrap?.checklists ?? const [];
});

final checklistIndexProvider = Provider<Map<String, Checklist>>((ref) {
  final catalog = ref.watch(contentCatalogProvider);
  return {for (final checklist in catalog) checklist.id: checklist};
});

final relatedChecklistsProvider = Provider.family<List<Checklist>, Checklist>((
  ref,
  checklist,
) {
  final catalog = ref.watch(contentCatalogProvider);
  final ranked =
      catalog
          .where((candidate) => candidate.id != checklist.id)
          .map(
            (candidate) => (
              checklist: candidate,
              score: _relatedScore(checklist, candidate),
            ),
          )
          .where((item) => item.score > 0)
          .toList()
        ..sort((left, right) {
          final scoreCompare = right.score.compareTo(left.score);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          return left.checklist.title.compareTo(right.checklist.title);
        });

  return ranked.take(3).map((item) => item.checklist).toList();
});

final searchSuggestionsProvider = Provider.family<List<String>, String>((
  ref,
  rawQuery,
) {
  final query = rawQuery.trim().toLowerCase();
  final recentSearches =
      ref.watch(recentSearchesProvider).valueOrNull ?? const [];
  final catalog = ref.watch(contentCatalogProvider);

  if (query.isEmpty) {
    return recentSearches.take(6).toList();
  }

  final suggestions = <String>[];
  void addSuggestion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    final exists = suggestions.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (!exists) {
      suggestions.add(normalized);
    }
  }

  for (final item in recentSearches) {
    if (item.toLowerCase().contains(query)) {
      addSuggestion(item);
    }
  }

  for (final checklist in catalog) {
    final candidates = [
      checklist.title,
      checklist.id,
      ...checklist.keywords,
      ...checklist.symptoms,
    ];
    for (final candidate in candidates) {
      final normalized = candidate.trim();
      if (normalized.toLowerCase().contains(query)) {
        addSuggestion(normalized);
      }
      if (suggestions.length >= 8) {
        return suggestions;
      }
    }
  }

  return suggestions;
});

final recentChecklistChainProvider = Provider.family<List<Checklist>, String>((
  ref,
  checklistId,
) {
  final recentIds = ref.watch(recentProvider).valueOrNull ?? const [];
  final catalog = ref.watch(contentCatalogProvider);
  final byId = {for (final checklist in catalog) checklist.id: checklist};

  return recentIds
      .where((id) => id != checklistId)
      .map((id) => byId[id])
      .whereType<Checklist>()
      .take(3)
      .toList();
});

final matchHintsProvider = Provider.family<List<String>, (String, Checklist)>((
  ref,
  input,
) {
  final query = input.$1;
  final checklist = input.$2;
  final matchingConfig = ref
      .watch(contentSyncProvider)
      .bootstrap
      ?.matchingConfig;
  return buildMatchHints(query, checklist, config: matchingConfig);
});

class LookupController extends StateNotifier<AsyncValue<LookupResponse?>> {
  LookupController(this._repository) : super(const AsyncData(null));

  final LookupRepository _repository;

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    final cached = await _repository.searchCachedBootstrap(query);
    final hasCached = cached.candidates.isNotEmpty;
    if (hasCached) {
      state = AsyncData(cached);
    } else {
      state = const AsyncLoading();
    }

    try {
      final remote = await _repository.search(query);
      state = AsyncData(remote);
    } catch (error, stackTrace) {
      if (!hasCached) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}

class AgentController
    extends StateNotifier<AsyncValue<AgentNavigationResponse?>> {
  AgentController(this._repository) : super(const AsyncData(null));

  final LookupRepository _repository;

  Future<void> navigate(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.navigateAgent(query));
  }
}

class ContentSyncController extends StateNotifier<ContentSyncState> {
  ContentSyncController(this._repository, this._localStore)
    : super(const ContentSyncState());

  final LookupRepository _repository;
  final LocalStore _localStore;

  Future<void> bootstrap() async {
    await sync();
  }

  Future<void> sync({bool manual = false}) async {
    if (state.isSyncing) {
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      retryCount: 0,
      clearNextRetryAt: true,
      clearError: true,
    );

    try {
      final result = await _repository.loadContent();
      if (!mounted) {
        return;
      }

      final lastSyncedAt = result.usesImportedContent
          ? await _localStore.loadContentLastSyncAt()
          : null;

      if (result.bootstrap == null) {
        state = state.copyWith(
          isSyncing: false,
          source: ContentSource.none,
          errorMessage: result.errorMessage,
          lastSyncedAt: lastSyncedAt,
        );
        return;
      }

      state = state.copyWith(
        bootstrap: result.bootstrap,
        isSyncing: false,
        source: result.usesImportedContent
            ? ContentSource.imported
            : ContentSource.bundled,
        lastSyncedAt: lastSyncedAt,
        retryCount: 0,
        clearNextRetryAt: true,
        errorMessage: result.errorMessage,
        clearError: result.errorMessage == null,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isSyncing: false,
        source: state.hasContent ? state.source : ContentSource.none,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> importPackage(String rawPackage) async {
    if (state.isSyncing) {
      return false;
    }

    final previous = state;
    state = state.copyWith(
      isSyncing: true,
      retryCount: 0,
      clearNextRetryAt: true,
      clearError: true,
    );

    final result = await _repository.importPackage(rawPackage);
    if (!mounted) {
      return false;
    }

    if (result.bootstrap == null) {
      state = previous.copyWith(
        isSyncing: false,
        errorMessage: result.errorMessage ?? 'Import failed',
      );
      return false;
    }

    final importedAt = DateTime.now();
    await _localStore.saveContentLastSyncAt(importedAt);
    state = state.copyWith(
      bootstrap: result.bootstrap,
      isSyncing: false,
      source: ContentSource.imported,
      lastSyncedAt: importedAt,
      retryCount: 0,
      clearNextRetryAt: true,
      clearError: true,
    );
    return true;
  }

  Future<void> restoreBundledContent() async {
    if (state.isSyncing) {
      return;
    }

    final previousBootstrap = state.bootstrap;
    state = state.copyWith(
      isSyncing: true,
      retryCount: 0,
      clearNextRetryAt: true,
      clearError: true,
    );

    try {
      final result = await _repository.restoreBundledContent();
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        bootstrap: result.bootstrap ?? previousBootstrap,
        isSyncing: false,
        source: result.bootstrap == null
            ? ContentSource.none
            : ContentSource.bundled,
        lastSyncedAt: null,
        retryCount: 0,
        clearNextRetryAt: true,
        errorMessage: result.errorMessage,
        clearError: result.errorMessage == null,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(isSyncing: false, errorMessage: error.toString());
    }
  }
}

enum ContentSource { none, bundled, imported }

class ContentSyncState {
  const ContentSyncState({
    this.bootstrap,
    this.isSyncing = false,
    this.source = ContentSource.none,
    this.errorMessage,
    this.lastSyncedAt,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  final ContentBootstrap? bootstrap;
  final bool isSyncing;
  final ContentSource source;
  final String? errorMessage;
  final DateTime? lastSyncedAt;
  final int retryCount;
  final DateTime? nextRetryAt;

  bool get hasContent => bootstrap != null;

  String get actionLabel {
    if (isSyncing) {
      return 'Loading...';
    }
    return hasContent ? 'Reload library' : 'Load library';
  }

  ContentSyncState copyWith({
    ContentBootstrap? bootstrap,
    bool? isSyncing,
    ContentSource? source,
    String? errorMessage,
    Object? lastSyncedAt = _noValue,
    int? retryCount,
    Object? nextRetryAt = _noValue,
    bool clearError = false,
    bool clearNextRetryAt = false,
  }) {
    return ContentSyncState(
      bootstrap: bootstrap ?? this.bootstrap,
      isSyncing: isSyncing ?? this.isSyncing,
      source: source ?? this.source,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSyncedAt: identical(lastSyncedAt, _noValue)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: clearNextRetryAt
          ? null
          : identical(nextRetryAt, _noValue)
          ? this.nextRetryAt
          : nextRetryAt as DateTime?,
    );
  }
}

const Object _noValue = Object();

class FavoritesController extends StateNotifier<AsyncValue<List<String>>> {
  FavoritesController(this._localStore) : super(const AsyncLoading());

  final LocalStore _localStore;

  Future<void> load() async {
    state = await AsyncValue.guard(_localStore.loadFavorites);
  }

  Future<void> toggle(String checklistId) async {
    state = await AsyncValue.guard(
      () => _localStore.toggleFavorite(checklistId),
    );
  }
}

class RecentController extends StateNotifier<AsyncValue<List<String>>> {
  RecentController(this._localStore) : super(const AsyncLoading());

  final LocalStore _localStore;

  Future<void> load() async {
    state = await AsyncValue.guard(_localStore.loadRecent);
  }

  Future<void> push(String checklistId) async {
    state = await AsyncValue.guard(() => _localStore.pushRecent(checklistId));
  }
}

class RecentSearchesController extends StateNotifier<AsyncValue<List<String>>> {
  RecentSearchesController(this._localStore) : super(const AsyncLoading());

  final LocalStore _localStore;

  Future<void> load() async {
    state = await AsyncValue.guard(_localStore.loadRecentSearches);
  }

  Future<void> push(String query) async {
    state = await AsyncValue.guard(() => _localStore.pushRecentSearch(query));
  }

  Future<void> clear() async {
    await _localStore.clearRecentSearches();
    state = const AsyncData([]);
  }
}

double _relatedScore(Checklist source, Checklist candidate) {
  final sourceKeywords = source.keywords.map(_normalizeToken).toSet();
  final candidateKeywords = candidate.keywords.map(_normalizeToken).toSet();
  final sourceSymptoms = _tokenizeAll(source.symptoms);
  final candidateSymptoms = _tokenizeAll(candidate.symptoms);
  final sourceContext = _tokenizeAll([
    ...source.rootCause,
    ...source.longTermFix,
  ]);
  final candidateContext = _tokenizeAll([
    ...candidate.rootCause,
    ...candidate.longTermFix,
  ]);

  final keywordOverlap = _overlapCount(sourceKeywords, candidateKeywords);
  final symptomOverlap = _overlapCount(sourceSymptoms, candidateSymptoms);
  final contextOverlap = _overlapCount(sourceContext, candidateContext);

  return ((keywordOverlap * 3) + (symptomOverlap * 2) + contextOverlap)
      .toDouble();
}

Set<String> _tokenizeAll(List<String> values) {
  final tokens = <String>{};
  for (final value in values) {
    for (final token in value.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      final normalized = token.trim();
      if (normalized.isNotEmpty) {
        tokens.add(normalized);
      }
    }
  }
  return tokens;
}

String _normalizeToken(String value) => value.toLowerCase().trim();

int _overlapCount(Set<String> left, Set<String> right) {
  var count = 0;
  for (final token in left) {
    if (right.contains(token)) {
      count++;
    }
  }
  return count;
}

List<String> buildMatchHints(
  String rawQuery,
  Checklist checklist, {
  MatchingConfig? config,
}) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) {
    return const [];
  }

  final queryTokens = _tokenizeAll([query]);
  final title = checklist.title.toLowerCase();
  final id = checklist.id.toLowerCase();
  final keywordTokens = checklist.keywords.map(_normalizeToken).toSet();
  final symptomTokens = _tokenizeAll(checklist.symptoms);
  final contextTokens = _tokenizeAll([
    ...checklist.rootCause,
    ...checklist.longTermFix,
  ]);
  final hints = <String>[];

  void addHint(String value) {
    if (!hints.contains(value)) {
      hints.add(value);
    }
  }

  if (title.contains(query) || id.contains(query)) {
    addHint('title/id match');
  }

  for (final token in queryTokens) {
    if (keywordTokens.contains(token)) {
      addHint('keyword $token');
    }
    if (symptomTokens.contains(token)) {
      addHint('symptom $token');
    }
    if (contextTokens.contains(token)) {
      addHint('context $token');
    }
  }

  final synonymsByToken = _buildSynonymsMap(config);
  for (final token in queryTokens) {
    final synonyms = synonymsByToken[token] ?? const <String>{};
    for (final synonym in synonyms) {
      if (keywordTokens.contains(synonym)) {
        addHint('synonym $token->$synonym');
        break;
      }
      if (symptomTokens.contains(synonym)) {
        addHint('symptom synonym $token->$synonym');
        break;
      }
    }
  }

  if (hints.isEmpty) {
    addHint('broad text overlap');
  }

  return hints.take(3).toList();
}

Map<String, Set<String>> _buildSynonymsMap(MatchingConfig? config) {
  if (config == null) {
    return const {};
  }

  final map = <String, Set<String>>{};
  for (final group in config.synonymGroups) {
    final normalizedGroup = group
        .map(_normalizeToken)
        .where((item) => item.isNotEmpty)
        .toSet();
    for (final token in normalizedGroup) {
      map[token] = normalizedGroup;
    }
  }
  return map;
}
