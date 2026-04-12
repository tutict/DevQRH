import '../../../core/storage/local_store.dart';
import '../../../core/network/devqrh_api_client.dart';
import '../domain/models.dart';
import 'offline_lookup_matcher.dart';

class LookupRepository {
  LookupRepository(this._apiClient, this._localStore)
    : _offlineLookupMatcher = OfflineLookupMatcher();

  final DevQrhApiClient _apiClient;
  final LocalStore _localStore;
  final OfflineLookupMatcher _offlineLookupMatcher;

  Future<LookupResponse> search(String query) async {
    try {
      final json = await _apiClient.getJson(
        '/api/lookup',
        queryParameters: {'q': query, 'top': '3'},
      );
      return LookupResponse.fromJson(json);
    } catch (_) {
      final cached = await loadCachedChecklists();
      final matchingConfig = await loadCachedMatchingConfig();
      return searchCached(
        query,
        checklists: cached,
        matchingConfig: matchingConfig,
      );
    }
  }

  Future<Checklist> fetchChecklist(String checklistId) async {
    try {
      final json = await _apiClient.getJson('/api/checklists/$checklistId');
      return Checklist.fromJson(json);
    } catch (_) {
      final cached = await loadCachedChecklists();
      return cached.firstWhere((item) => item.id == checklistId);
    }
  }

  Future<ContentSyncResult> syncContent() async {
    final cachedManifest = await loadCachedManifest();
    final cachedMatchingConfig =
        await loadCachedMatchingConfig() ?? _defaultMatchingConfig();
    final cachedChecklists = await loadCachedChecklists();

    try {
      final remoteManifestJson = await _apiClient.getJson(
        '/api/mobile/manifest',
      );
      final remoteManifest = ContentManifest.fromJson(remoteManifestJson);
      if (cachedManifest != null &&
          cachedManifest.version == remoteManifest.version) {
        return ContentSyncResult(
          bootstrap: ContentBootstrap(
            manifest: remoteManifest,
            matchingConfig: cachedMatchingConfig,
            checklists: cachedChecklists,
          ),
          refreshedFromNetwork: true,
        );
      }

      final bootstrapJson = await _apiClient.getJson('/api/mobile/bootstrap');
      final bootstrap = ContentBootstrap.fromJson(bootstrapJson);
      await _localStore.saveContentCache(
        manifest: bootstrap.manifest.toJson(),
        matchingConfig: bootstrap.matchingConfig.toJson(),
        checklists: bootstrap.checklists.map((item) => item.toJson()).toList(),
      );
      return ContentSyncResult(
        bootstrap: bootstrap,
        refreshedFromNetwork: true,
      );
    } catch (error) {
      if (cachedManifest == null) {
        return ContentSyncResult(
          bootstrap: null,
          refreshedFromNetwork: false,
          errorMessage: error.toString(),
        );
      }
      return ContentSyncResult(
        bootstrap: ContentBootstrap(
          manifest: cachedManifest,
          matchingConfig: cachedMatchingConfig,
          checklists: cachedChecklists,
        ),
        refreshedFromNetwork: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<ContentManifest?> loadCachedManifest() async {
    final json = await _localStore.loadCachedManifest();
    if (json == null) {
      return null;
    }
    return ContentManifest.fromJson(json);
  }

  Future<List<Checklist>> loadCachedChecklists() async {
    final json = await _localStore.loadCachedChecklists();
    return json.map(Checklist.fromJson).toList();
  }

  Future<ContentBootstrap?> loadCachedBootstrap() async {
    final manifest = await loadCachedManifest();
    if (manifest == null) {
      return null;
    }

    final matchingConfig =
        await loadCachedMatchingConfig() ?? _defaultMatchingConfig();
    final checklists = await loadCachedChecklists();

    return ContentBootstrap(
      manifest: manifest,
      matchingConfig: matchingConfig,
      checklists: checklists,
    );
  }

  Future<MatchingConfig?> loadCachedMatchingConfig() async {
    final json = await _localStore.loadCachedMatchingConfig();
    if (json == null) {
      return null;
    }
    return MatchingConfig.fromJson(json);
  }

  Future<LookupResponse> searchCachedBootstrap(
    String query, {
    ContentBootstrap? bootstrap,
  }) async {
    final resolvedBootstrap = bootstrap ?? await loadCachedBootstrap();
    if (resolvedBootstrap == null) {
      return LookupResponse(
        query: query,
        bestMatch: null,
        candidates: const [],
      );
    }

    return searchCached(
      query,
      checklists: resolvedBootstrap.checklists,
      matchingConfig: resolvedBootstrap.matchingConfig,
    );
  }

  LookupResponse searchCached(
    String query, {
    required List<Checklist> checklists,
    MatchingConfig? matchingConfig,
  }) {
    return _offlineLookupMatcher.search(
      query: query,
      checklists: checklists,
      config: matchingConfig ?? _defaultMatchingConfig(),
    );
  }

  MatchingConfig _defaultMatchingConfig() {
    return MatchingConfig(
      partialMinLength: 3,
      synonymGroups: const [
        ['slow', 'latency', 'timeout', 'lag', 'delay', 'sluggish'],
        ['cpu', 'load', 'hot', 'busy', 'spike', 'thread'],
        ['memory', 'heap', 'gc', 'oom', 'leak'],
        ['mysql', 'db', 'database', 'sql', 'query'],
        ['service', 'api', 'app', 'endpoint'],
        ['disk', 'io', 'iowait', 'storage', 'bottleneck'],
      ],
      weights: MatchingWeights(
        exactQueryId: 1.0,
        exactIdToken: 1.0,
        exactTitleToken: 0.95,
        exactKeywordToken: 0.90,
        exactSymptomToken: 0.78,
        exactContextToken: 0.60,
        synonymKeyword: 0.72,
        synonymPrimary: 0.62,
        synonymAny: 0.50,
        partialKeyword: 0.48,
        partialPrimary: 0.40,
        partialAny: 0.28,
        tokenAverage: 0.88,
        keywordCoverage: 0.12,
        exactTitleBoost: 0.12,
        partialTitleBoost: 0.07,
        partialIdBoost: 0.07,
        phraseBoost: 0.04,
      ),
    );
  }
}

class ContentSyncResult {
  ContentSyncResult({
    required this.bootstrap,
    required this.refreshedFromNetwork,
    this.errorMessage,
  });

  final ContentBootstrap? bootstrap;
  final bool refreshedFromNetwork;
  final String? errorMessage;
}
