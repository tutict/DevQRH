import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/devqrh_api_client.dart';
import '../../../core/storage/local_store.dart';
import '../data/lookup_repository.dart';
import '../domain/models.dart';

final apiClientProvider = Provider<DevQrhApiClient>((ref) {
  return DevQrhApiClient(baseUrl: AppConfig.apiBaseUrl);
});

final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  return LookupRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
  );
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

final lookupControllerProvider =
    StateNotifierProvider<LookupController, AsyncValue<LookupResponse?>>((ref) {
      return LookupController(ref.watch(lookupRepositoryProvider));
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
  return ref.watch(lookupRepositoryProvider).fetchChecklist(checklistId);
});

final contentCatalogProvider = Provider<List<Checklist>>((ref) {
  return ref.watch(contentSyncProvider).bootstrap?.checklists ?? const [];
});

final checklistIndexProvider = Provider<Map<String, Checklist>>((ref) {
  final catalog = ref.watch(contentCatalogProvider);
  return {for (final checklist in catalog) checklist.id: checklist};
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

class ContentSyncController extends StateNotifier<ContentSyncState> {
  ContentSyncController(this._repository, this._localStore)
    : super(const ContentSyncState());

  final LookupRepository _repository;
  final LocalStore _localStore;
  static const _maxAutoRetryAttempts = 2;
  Timer? _retryTimer;

  Future<void> bootstrap() async {
    final cached = await _repository.loadCachedBootstrap();
    final lastSyncedAt = await _localStore.loadContentLastSyncAt();
    if (cached != null) {
      state = state.copyWith(
        bootstrap: cached,
        source: ContentSource.cache,
        isSyncing: false,
        lastSyncedAt: lastSyncedAt,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        isSyncing: false,
        source: ContentSource.none,
        lastSyncedAt: lastSyncedAt,
        clearError: true,
      );
    }
    await sync();
  }

  Future<void> sync({bool manual = false}) async {
    if (state.isSyncing) {
      return;
    }

    _retryTimer?.cancel();
    if (manual) {
      state = state.copyWith(
        isSyncing: true,
        retryCount: 0,
        clearNextRetryAt: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        isSyncing: true,
        clearNextRetryAt: true,
        clearError: true,
      );
    }

    try {
      final result = await _repository.syncContent();
      if (!mounted) {
        return;
      }

      if (result.bootstrap == null) {
        state = state.copyWith(
          isSyncing: false,
          source: ContentSource.none,
          errorMessage: result.errorMessage ?? 'No content available',
        );
        _scheduleRetryIfNeeded(
          manual: manual,
          hasContent: false,
          errorMessage: result.errorMessage,
        );
        return;
      }

      DateTime? lastSyncedAt = state.lastSyncedAt;
      if (result.refreshedFromNetwork) {
        lastSyncedAt = DateTime.now();
        await _localStore.saveContentLastSyncAt(lastSyncedAt);
      }

      state = state.copyWith(
        bootstrap: result.bootstrap,
        isSyncing: false,
        source: result.refreshedFromNetwork
            ? ContentSource.network
            : ContentSource.cache,
        lastSyncedAt: lastSyncedAt,
        retryCount: 0,
        clearNextRetryAt: true,
        errorMessage: result.errorMessage,
        clearError: result.errorMessage == null,
      );

      _scheduleRetryIfNeeded(
        manual: manual,
        hasContent: true,
        errorMessage: result.errorMessage,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isSyncing: false,
        source: state.hasContent ? ContentSource.cache : ContentSource.none,
        errorMessage: error.toString(),
      );
      _scheduleRetryIfNeeded(
        manual: manual,
        hasContent: state.hasContent,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetryIfNeeded({
    required bool manual,
    required bool hasContent,
    String? errorMessage,
  }) {
    if (manual || errorMessage == null || !hasContent) {
      return;
    }

    final nextAttempt = state.retryCount + 1;
    if (nextAttempt > _maxAutoRetryAttempts) {
      return;
    }

    final delay = Duration(seconds: 4 * nextAttempt);
    final nextRetryAt = DateTime.now().add(delay);
    state = state.copyWith(retryCount: nextAttempt, nextRetryAt: nextRetryAt);

    _retryTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      sync();
    });
  }
}

enum ContentSource { none, cache, network }

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
      return 'Syncing...';
    }
    if (errorMessage != null) {
      return 'Retry now';
    }
    return hasContent ? 'Refresh content' : 'Sync now';
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
