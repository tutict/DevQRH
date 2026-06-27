import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/storage/local_store_provider.dart';
import '../data/knowledge_repository.dart';
import '../domain/models.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  final repository = KnowledgeRepository(ref.watch(localStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final knowledgeSyncProvider =
    StateNotifierProvider<KnowledgeSyncController, KnowledgeSyncState>((ref) {
      return KnowledgeSyncController(
        ref.watch(knowledgeRepositoryProvider),
        ref.watch(localStoreProvider),
      )..bootstrap();
    });

final knowledgeSearchProvider =
    StateNotifierProvider<
      KnowledgeSearchController,
      AsyncValue<KnowledgeSearchResponse?>
    >((ref) {
      return KnowledgeSearchController(
        ref.watch(knowledgeRepositoryProvider),
        ref.read(recentQueriesProvider.notifier),
      );
    });

final tutorControllerProvider =
    StateNotifierProvider<TutorController, AsyncValue<TutorAnswerResponse?>>((
      ref,
    ) {
      return TutorController(
        ref.watch(knowledgeRepositoryProvider),
        ref.read(recentQueriesProvider.notifier),
      );
    });

final cardGenerationProvider =
    StateNotifierProvider<
      CardGenerationController,
      AsyncValue<GeneratedCardsResponse?>
    >((ref) {
      return CardGenerationController(ref.watch(knowledgeRepositoryProvider));
    });

final reviewStatesProvider =
    StateNotifierProvider<
      ReviewStatesController,
      AsyncValue<Map<String, ReviewState>>
    >((ref) {
      return ReviewStatesController(ref.watch(knowledgeRepositoryProvider))
        ..load();
    });

final favoriteMaterialsProvider =
    StateNotifierProvider<FavoriteMaterialsController, AsyncValue<List<String>>>((
      ref,
    ) {
      return FavoriteMaterialsController(ref.watch(localStoreProvider))..load();
    });

final recentMaterialsProvider =
    StateNotifierProvider<RecentMaterialsController, AsyncValue<List<String>>>((
      ref,
    ) {
      return RecentMaterialsController(ref.watch(localStoreProvider))..load();
    });

final recentQueriesProvider =
    StateNotifierProvider<RecentQueriesController, AsyncValue<List<String>>>((
      ref,
    ) {
      return RecentQueriesController(ref.watch(localStoreProvider))..load();
    });

final learningBundleProvider = Provider<LearningBundle?>((ref) {
  return ref.watch(knowledgeSyncProvider).bundle;
});

final studyMaterialsProvider = Provider<List<StudyMaterial>>((ref) {
  return ref.watch(learningBundleProvider)?.materials ?? const [];
});

final studyDecksProvider = Provider<List<StudyDeck>>((ref) {
  return ref.watch(learningBundleProvider)?.decks ?? const [];
});

final studyCardsProvider = Provider<List<StudyCard>>((ref) {
  return ref.watch(learningBundleProvider)?.cards ?? const [];
});

final materialIndexProvider = Provider<Map<String, StudyMaterial>>((ref) {
  return {
    for (final material in ref.watch(studyMaterialsProvider))
      material.id: material,
  };
});

final deckIndexProvider = Provider<Map<String, StudyDeck>>((ref) {
  return {for (final deck in ref.watch(studyDecksProvider)) deck.id: deck};
});

final cardIndexProvider = Provider<Map<String, StudyCard>>((ref) {
  return {for (final card in ref.watch(studyCardsProvider)) card.id: card};
});

final materialDetailProvider = FutureProvider.family<StudyMaterial, String>((
  ref,
  materialId,
) async {
  final cached = ref.watch(materialIndexProvider)[materialId];
  if (cached != null) {
    return cached;
  }
  final resolved = await ref
      .watch(knowledgeRepositoryProvider)
      .findMaterial(materialId);
  if (resolved != null) {
    return resolved;
  }
  throw StateError('Study material not found: $materialId');
});

final dueCardsProvider = Provider<List<StudyCard>>((ref) {
  final states = ref.watch(reviewStatesProvider).value ?? const <String, ReviewState>{};
  final now = DateTime.now();
  return ref
      .watch(studyCardsProvider)
      .where((card) => states[card.id]?.isDue(now) ?? true)
      .toList();
});

final nextDueCardsProvider = Provider<List<StudyCard>>((ref) {
  final states = ref.watch(reviewStatesProvider).value ?? const <String, ReviewState>{};
  final cards = List<StudyCard>.from(ref.watch(studyCardsProvider));
  cards.sort((left, right) {
    final leftDue =
        states[left.id]?.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDue =
        states[right.id]?.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final compare = leftDue.compareTo(rightDue);
    if (compare != 0) {
      return compare;
    }
    return left.front.compareTo(right.front);
  });
  return cards.take(8).toList();
});

final recentMaterialItemsProvider = Provider<List<StudyMaterial>>((ref) {
  final ids = ref.watch(recentMaterialsProvider).value ?? const [];
  final byId = ref.watch(materialIndexProvider);
  return ids.map((id) => byId[id]).whereType<StudyMaterial>().toList();
});

final favoriteMaterialItemsProvider = Provider<List<StudyMaterial>>((ref) {
  final ids = ref.watch(favoriteMaterialsProvider).value ?? const [];
  final byId = ref.watch(materialIndexProvider);
  return ids.map((id) => byId[id]).whereType<StudyMaterial>().toList();
});

final searchSuggestionsProvider = Provider.family<List<String>, String>((
  ref,
  rawQuery,
) {
  final query = rawQuery.trim().toLowerCase();
  final recentQueries = ref.watch(recentQueriesProvider).value ?? const [];
  final materials = ref.watch(studyMaterialsProvider);

  if (query.isEmpty) {
    return recentQueries.take(6).toList();
  }

  final suggestions = <String>[];
  void add(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!suggestions.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    )) {
      suggestions.add(normalized);
    }
  }

  for (final recent in recentQueries) {
    if (recent.toLowerCase().contains(query)) {
      add(recent);
    }
  }
  for (final material in materials) {
    final candidates = [
      material.title,
      material.id,
      ...material.tags,
      material.summary,
    ];
    for (final candidate in candidates) {
      if (candidate.toLowerCase().contains(query)) {
        add(candidate);
      }
      if (suggestions.length >= 8) {
        return suggestions;
      }
    }
  }
  return suggestions;
});

final relatedMaterialsProvider = Provider.family<List<StudyMaterial>, StudyMaterial>((
  ref,
  material,
) {
  final materials = ref.watch(studyMaterialsProvider);
  final ranked = materials
      .where((candidate) => candidate.id != material.id)
      .map(
        (candidate) => (
          material: candidate,
          score: relatedMaterialScore(material, candidate),
        ),
      )
      .where((item) => item.score > 0)
      .toList()
    ..sort((left, right) {
      final compare = right.score.compareTo(left.score);
      if (compare != 0) {
        return compare;
      }
      return left.material.title.compareTo(right.material.title);
    });
  return ranked.take(3).map((item) => item.material).toList();
});

class KnowledgeSyncController extends StateNotifier<KnowledgeSyncState> {
  KnowledgeSyncController(this._repository, this._localStore)
    : super(const KnowledgeSyncState());

  final KnowledgeRepository _repository;
  final LocalStore _localStore;

  Future<void> bootstrap() => sync();

  Future<void> sync() async {
    if (state.isSyncing) {
      return;
    }
    state = state.copyWith(isSyncing: true, clearError: true);
    final result = await _repository.loadContent();
    if (!mounted) {
      return;
    }
    final lastSyncedAt = result.usesImportedContent
        ? await _localStore.loadLearningLastSyncAt()
        : null;
    if (result.bundle == null) {
      state = state.copyWith(
        isSyncing: false,
        source: KnowledgeSource.none,
        errorMessage: result.errorMessage,
        lastSyncedAt: lastSyncedAt,
      );
      return;
    }
    state = state.copyWith(
      bundle: result.bundle,
      isSyncing: false,
      source: result.usesImportedContent
          ? KnowledgeSource.imported
          : KnowledgeSource.bundled,
      errorMessage: result.errorMessage,
      clearError: result.errorMessage == null,
      lastSyncedAt: lastSyncedAt,
    );
  }

  Future<bool> importPackage(String rawPackage) async {
    if (state.isSyncing) {
      return false;
    }
    final previous = state;
    state = state.copyWith(isSyncing: true, clearError: true);
    final result = await _repository.importPackage(rawPackage);
    if (!mounted) {
      return false;
    }
    if (result.bundle == null) {
      state = previous.copyWith(
        isSyncing: false,
        errorMessage: result.errorMessage ?? 'Import failed',
      );
      return false;
    }
    final importedAt = DateTime.now();
    await _localStore.saveLearningLastSyncAt(importedAt);
    state = state.copyWith(
      bundle: result.bundle,
      isSyncing: false,
      source: KnowledgeSource.imported,
      lastSyncedAt: importedAt,
      clearError: true,
    );
    return true;
  }

  Future<void> restoreBundledContent() async {
    if (state.isSyncing) {
      return;
    }
    state = state.copyWith(isSyncing: true, clearError: true);
    final result = await _repository.restoreBundledContent();
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      bundle: result.bundle,
      isSyncing: false,
      source: result.bundle == null
          ? KnowledgeSource.none
          : KnowledgeSource.bundled,
      lastSyncedAt: null,
      errorMessage: result.errorMessage,
      clearError: result.errorMessage == null,
    );
  }
}

enum KnowledgeSource { none, bundled, imported }

class KnowledgeSyncState {
  const KnowledgeSyncState({
    this.bundle,
    this.isSyncing = false,
    this.source = KnowledgeSource.none,
    this.errorMessage,
    this.lastSyncedAt,
  });

  final LearningBundle? bundle;
  final bool isSyncing;
  final KnowledgeSource source;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  bool get hasContent => bundle != null;

  KnowledgeSyncState copyWith({
    LearningBundle? bundle,
    bool? isSyncing,
    KnowledgeSource? source,
    String? errorMessage,
    Object? lastSyncedAt = _noValue,
    bool clearError = false,
  }) {
    return KnowledgeSyncState(
      bundle: bundle ?? this.bundle,
      isSyncing: isSyncing ?? this.isSyncing,
      source: source ?? this.source,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSyncedAt: identical(lastSyncedAt, _noValue)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }
}

class KnowledgeSearchController
    extends StateNotifier<AsyncValue<KnowledgeSearchResponse?>> {
  KnowledgeSearchController(this._repository, this._recentQueries)
    : super(const AsyncData(null));

  final KnowledgeRepository _repository;
  final RecentQueriesController _recentQueries;

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    await _recentQueries.push(query);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.search(query));
  }
}

class TutorController extends StateNotifier<AsyncValue<TutorAnswerResponse?>> {
  TutorController(this._repository, this._recentQueries)
    : super(const AsyncData(null));

  final KnowledgeRepository _repository;
  final RecentQueriesController _recentQueries;

  Future<void> ask(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    await _recentQueries.push(query);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.answerQuestion(query));
  }
}

class CardGenerationController
    extends StateNotifier<AsyncValue<GeneratedCardsResponse?>> {
  CardGenerationController(this._repository) : super(const AsyncData(null));

  final KnowledgeRepository _repository;

  Future<void> generate({required List<String> materialIds, int limit = 6}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.generateCards(materialIds: materialIds, limit: limit),
    );
  }
}

class ReviewStatesController
    extends StateNotifier<AsyncValue<Map<String, ReviewState>>> {
  ReviewStatesController(this._repository) : super(const AsyncLoading());

  final KnowledgeRepository _repository;

  Future<void> load() async {
    state = await AsyncValue.guard(_repository.loadReviewStates);
  }

  Future<void> review({required String cardId, required ReviewGrade grade}) async {
    final current = state.value ?? await _repository.loadReviewStates();
    final result = await _repository.reviewCard(cardId: cardId, grade: grade);
    state = AsyncData({...current, cardId: result.updatedState});
  }
}

class FavoriteMaterialsController extends StateNotifier<AsyncValue<List<String>>> {
  FavoriteMaterialsController(this._localStore) : super(const AsyncLoading());

  final LocalStore _localStore;

  Future<void> load() async {
    state = await AsyncValue.guard(_localStore.loadFavorites);
  }

  Future<void> toggle(String materialId) async {
    state = await AsyncValue.guard(() => _localStore.toggleFavorite(materialId));
  }
}

class RecentMaterialsController extends StateNotifier<AsyncValue<List<String>>> {
  RecentMaterialsController(this._localStore) : super(const AsyncLoading());

  final LocalStore _localStore;

  Future<void> load() async {
    state = await AsyncValue.guard(_localStore.loadRecent);
  }

  Future<void> push(String materialId) async {
    state = await AsyncValue.guard(() => _localStore.pushRecent(materialId));
  }
}

class RecentQueriesController extends StateNotifier<AsyncValue<List<String>>> {
  RecentQueriesController(this._localStore) : super(const AsyncLoading());

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

String knowledgeSourceLabel(KnowledgeSource source) {
  return switch (source) {
    KnowledgeSource.bundled => 'Bundled',
    KnowledgeSource.imported => 'Imported',
    KnowledgeSource.none => 'Offline',
  };
}

String materialTypeLabel(MaterialType type) {
  return switch (type) {
    MaterialType.exam => 'Exam',
    MaterialType.engineering => 'Engineering',
    MaterialType.course => 'Course',
    MaterialType.project => 'Project',
    MaterialType.note => 'Note',
  };
}

String reviewGradeLabel(ReviewGrade grade) {
  return switch (grade) {
    ReviewGrade.again => 'Again',
    ReviewGrade.hard => 'Hard',
    ReviewGrade.good => 'Good',
    ReviewGrade.easy => 'Easy',
  };
}

String buildMaterialPreview(StudyMaterial material) {
  final lines = <String>[];
  if (material.summary.trim().isNotEmpty) {
    lines.add('Summary: ${material.summary.trim()}');
  }
  if (material.chunks.isNotEmpty) {
    lines.add('Key point: ${material.chunks.first.trim()}');
  }
  if (material.source.trim().isNotEmpty) {
    lines.add('Source: ${material.source.trim()}');
  }
  return lines.isEmpty ? material.title : lines.join('\n');
}

String buildCardMasteryLabel(ReviewState? state) {
  if (state == null || state.repetitionCount == 0) {
    return 'new';
  }
  if (state.lapses > 0 && state.intervalDays <= 1) {
    return 'needs review';
  }
  if (state.intervalDays >= 7) {
    return 'stable';
  }
  return 'learning';
}

double relatedMaterialScore(StudyMaterial source, StudyMaterial candidate) {
  final sourceTags = source.tags.map(_normalizeToken).toSet();
  final candidateTags = candidate.tags.map(_normalizeToken).toSet();
  final sourceText = _tokenizeAll([
    source.title,
    source.summary,
    source.content,
    ...source.chunks,
  ]);
  final candidateText = _tokenizeAll([
    candidate.title,
    candidate.summary,
    candidate.content,
    ...candidate.chunks,
  ]);
  return (_overlapCount(sourceTags, candidateTags) * 3 +
          _overlapCount(sourceText, candidateText))
      .toDouble();
}

Set<String> _tokenizeAll(List<String> values) {
  final tokens = <String>{};
  for (final value in values) {
    for (final token in value.toLowerCase().split(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'))) {
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

const Object _noValue = Object();
