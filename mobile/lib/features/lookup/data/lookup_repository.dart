import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/sidecar/rag_sidecar_client.dart';
import '../../../core/storage/local_store.dart';
import '../domain/models.dart';
import 'offline_lookup_matcher.dart';

class LookupRepository {
  LookupRepository(
    this._localStore, {
    AssetBundle? assetBundle,
    RagSidecarClient? sidecarClient,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _sidecarClient = sidecarClient ?? RagSidecarClient(),
       _offlineLookupMatcher = OfflineLookupMatcher();

  static const _defaultBundleAsset = 'assets/content/default_bundle.json';

  final LocalStore _localStore;
  final AssetBundle _assetBundle;
  final RagSidecarClient _sidecarClient;
  final OfflineLookupMatcher _offlineLookupMatcher;
  ContentBootstrap? _preferredBootstrapCache;

  void dispose() {
    _sidecarClient.dispose();
  }

  Future<LookupResponse> search(String query) async {
    final bootstrap = await loadPreferredBootstrap();
    final sidecarResult = await _sidecarClient.search(
      query,
      bootstrap: bootstrap,
    );
    if (sidecarResult != null) {
      return sidecarResult;
    }

    return searchCached(
      query,
      checklists: bootstrap.checklists,
      matchingConfig: bootstrap.matchingConfig,
    );
  }

  Future<Checklist> fetchChecklist(String checklistId) async {
    final checklist = await findChecklist(checklistId);
    if (checklist != null) {
      return checklist;
    }
    throw StateError('Checklist not found: $checklistId');
  }

  Future<Checklist?> findChecklist(String checklistId) async {
    final normalizedId = checklistId.toLowerCase();
    final bootstrap = await loadPreferredBootstrap();
    for (final checklist in bootstrap.checklists) {
      if (checklist.id.toLowerCase() == normalizedId) {
        return checklist;
      }
    }
    return null;
  }

  Future<ContentSyncResult> loadContent() async {
    try {
      final imported = await loadCachedBootstrap();
      if (imported != null) {
        _preferredBootstrapCache = imported;
        return ContentSyncResult(
          bootstrap: imported,
          usesImportedContent: true,
        );
      }

      final bundled = await loadBundledBootstrap();
      _preferredBootstrapCache = bundled;
      return ContentSyncResult(bootstrap: bundled, usesImportedContent: false);
    } catch (error) {
      await _localStore.clearContentCache();
      try {
        final bundled = await loadBundledBootstrap();
        _preferredBootstrapCache = bundled;
        return ContentSyncResult(
          bootstrap: bundled,
          usesImportedContent: false,
          errorMessage:
              'Imported package could not be loaded. Using built-in library.',
        );
      } catch (_) {
        return ContentSyncResult(
          bootstrap: null,
          usesImportedContent: false,
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<ContentSyncResult> importPackage(String rawPackage) async {
    try {
      final bootstrap = _decodeBootstrap(rawPackage);
      await _localStore.saveContentCache(
        manifest: bootstrap.manifest.toJson(),
        matchingConfig: bootstrap.matchingConfig.toJson(),
        checklists: bootstrap.checklists.map((item) => item.toJson()).toList(),
      );
      _preferredBootstrapCache = bootstrap;
      return ContentSyncResult(bootstrap: bootstrap, usesImportedContent: true);
    } catch (error) {
      return ContentSyncResult(
        bootstrap: null,
        usesImportedContent: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<ContentSyncResult> restoreBundledContent() async {
    await _localStore.clearContentCache();
    final bundled = await loadBundledBootstrap();
    _preferredBootstrapCache = bundled;
    return ContentSyncResult(bootstrap: bundled, usesImportedContent: false);
  }

  Future<ContentBootstrap> loadBundledBootstrap() async {
    final raw = await _assetBundle.loadString(_defaultBundleAsset);
    return _decodeBootstrap(raw, fallbackGeneratedAt: 1776124800000);
  }

  Future<ContentBootstrap?> loadCachedBootstrap() async {
    final manifest = await loadCachedManifest();
    if (manifest == null) {
      return null;
    }

    final matchingConfig =
        await loadCachedMatchingConfig() ?? _defaultMatchingConfig();
    final checklists = await loadCachedChecklists();
    if (checklists.isEmpty) {
      return null;
    }

    return ContentBootstrap(
      manifest: manifest,
      matchingConfig: matchingConfig,
      checklists: checklists,
    );
  }

  Future<ContentBootstrap> loadPreferredBootstrap() async {
    final cachedPreferred = _preferredBootstrapCache;
    if (cachedPreferred != null) {
      return cachedPreferred;
    }
    final cached = await loadCachedBootstrap();
    final resolved = cached ?? await loadBundledBootstrap();
    _preferredBootstrapCache = resolved;
    return resolved;
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
    final resolvedBootstrap = bootstrap ?? await loadPreferredBootstrap();
    return searchCached(
      query,
      checklists: resolvedBootstrap.checklists,
      matchingConfig: resolvedBootstrap.matchingConfig,
    );
  }

  Future<AgentNavigationResponse> navigateAgent(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return AgentNavigationResponse(
        query: '',
        bestMatch: null,
        candidates: const [],
        clarifiers: const [],
      );
    }

    final bootstrap = await loadPreferredBootstrap();
    final ragAnswer = await answerQuestion(query, bootstrap: bootstrap);
    return _navigationFromCandidates(
      query,
      ragAnswer.candidates,
    ).copyWith(ragAnswer: ragAnswer);
  }

  Future<RagAnswerResponse> answerQuestion(
    String rawQuery, {
    ContentBootstrap? bootstrap,
  }) async {
    final query = rawQuery.trim();
    final resolvedBootstrap = bootstrap ?? await loadPreferredBootstrap();
    if (query.isEmpty) {
      return RagAnswerResponse(
        query: '',
        answer: '',
        citations: const [],
        candidates: const [],
      );
    }

    final sidecarAnswer = await _sidecarClient.answerQuestion(
      query,
      bootstrap: resolvedBootstrap,
    );
    if (sidecarAnswer != null) {
      return sidecarAnswer;
    }

    return answerQuestionCached(
      query,
      checklists: resolvedBootstrap.checklists,
      matchingConfig: resolvedBootstrap.matchingConfig,
    );
  }

  RagAnswerResponse answerQuestionCached(
    String rawQuery, {
    required List<Checklist> checklists,
    MatchingConfig? matchingConfig,
  }) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return RagAnswerResponse(
        query: '',
        answer: '',
        citations: const [],
        candidates: const [],
      );
    }

    final lookup = searchCached(
      query,
      checklists: checklists,
      matchingConfig: matchingConfig,
    );
    return _buildRagAnswer(query, lookup.candidates);
  }

  Future<AgentNavigationResponse> navigateAgentCachedBootstrap(
    String query, {
    ContentBootstrap? bootstrap,
  }) async {
    final resolvedBootstrap = bootstrap ?? await loadPreferredBootstrap();
    return navigateAgentCached(
      query,
      checklists: resolvedBootstrap.checklists,
      matchingConfig: resolvedBootstrap.matchingConfig,
    );
  }

  AgentNavigationResponse navigateAgentCached(
    String rawQuery, {
    required List<Checklist> checklists,
    MatchingConfig? matchingConfig,
  }) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return AgentNavigationResponse(
        query: '',
        bestMatch: null,
        candidates: const [],
        clarifiers: const [],
      );
    }

    final lookup = searchCached(
      query,
      checklists: checklists,
      matchingConfig: matchingConfig,
    );
    return _navigationFromCandidates(query, lookup.candidates);
  }

  AgentNavigationResponse _navigationFromCandidates(
    String query,
    List<RankedChecklist> candidates,
  ) {
    final bestMatch = candidates.isEmpty ? null : candidates.first;
    final clarifiers = <String>[];

    void addClarifier(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty ||
          normalized.toLowerCase() == query.toLowerCase()) {
        return;
      }
      final exists = clarifiers.any(
        (item) => item.toLowerCase() == normalized.toLowerCase(),
      );
      if (!exists) {
        clarifiers.add('check: $normalized');
      }
    }

    for (final candidate in candidates) {
      for (final symptom in candidate.checklist.symptoms) {
        addClarifier(symptom);
        if (clarifiers.length >= 3) {
          break;
        }
      }
      if (clarifiers.length >= 3) {
        break;
      }
    }

    return AgentNavigationResponse(
      query: query,
      bestMatch: bestMatch,
      candidates: candidates,
      clarifiers: clarifiers,
    );
  }

  RagAnswerResponse _buildRagAnswer(
    String query,
    List<RankedChecklist> candidates,
  ) {
    final citations = candidates
        .map(
          (item) => RagCitation(
            id: item.checklist.id,
            title: item.checklist.title,
            score: item.score,
          ),
        )
        .toList();

    if (candidates.isEmpty) {
      return RagAnswerResponse(
        query: query,
        answer:
            'No matching runbook was found in the local handbook. Try adding a more specific symptom, component, or error signal.',
        citations: citations,
        candidates: candidates,
      );
    }

    final best = candidates.first.checklist;
    final buffer = StringBuffer()
      ..writeln('Start with "${best.title}" because it is the strongest match.')
      ..writeln();

    if (best.symptoms.isNotEmpty) {
      buffer.writeln('Matched signals: ${best.symptoms.take(3).join(', ')}.');
    }
    if (best.immediateActions.isNotEmpty) {
      buffer.writeln('Immediate checks:');
      for (final step in best.immediateActions.take(3)) {
        buffer.writeln('${step.step}. ${step.action}');
      }
    }
    if (best.decisionTree.isNotEmpty) {
      buffer.writeln('Decision points:');
      for (final branch in best.decisionTree.take(2)) {
        buffer.writeln('- If ${branch.condition}, ${branch.action}.');
      }
    }
    if (best.rootCause.isNotEmpty) {
      buffer.writeln('Likely causes: ${best.rootCause.take(3).join(', ')}.');
    }
    if (best.longTermFix.isNotEmpty) {
      buffer.writeln(
        'Long-term fixes: ${best.longTermFix.take(3).join(', ')}.',
      );
    }
    final alternatives = candidates.skip(1).take(2).toList();
    if (alternatives.isNotEmpty) {
      buffer.writeln(
        'Also compare: ${alternatives.map((item) => item.checklist.title).join(', ')}.',
      );
    }

    return RagAnswerResponse(
      query: query,
      answer: buffer.toString().trim(),
      citations: citations,
      candidates: candidates,
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

  ContentBootstrap _decodeBootstrap(
    String rawPackage, {
    int? fallbackGeneratedAt,
  }) {
    final decoded = jsonDecode(rawPackage);
    if (decoded is! Map) {
      throw const FormatException('Content package must be a JSON object.');
    }

    final json = decoded.cast<String, dynamic>();
    final matchingConfigJson = _requireJsonObject(
      json['matchingConfig'],
      'matchingConfig',
    );
    final checklistJson = _requireJsonList(json['checklists'], 'checklists');
    if (checklistJson.isEmpty) {
      throw const FormatException(
        'Content package must include at least one checklist.',
      );
    }

    final checklists = checklistJson
        .map((item) => Checklist.fromJson(item.cast<String, dynamic>()))
        .where(
          (item) => item.id.trim().isNotEmpty && item.title.trim().isNotEmpty,
        )
        .toList();
    if (checklists.isEmpty) {
      throw const FormatException(
        'Content package checklists must include non-empty id and title values.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final manifestJson = json['manifest'];
    final parsedManifest = manifestJson is Map
        ? ContentManifest.fromJson(manifestJson.cast<String, dynamic>())
        : null;
    final manifest = ContentManifest(
      version: (parsedManifest?.version ?? '').trim().isNotEmpty
          ? parsedManifest!.version
          : _generatedVersion(now),
      checklistCount:
          parsedManifest == null || parsedManifest.checklistCount <= 0
          ? checklists.length
          : parsedManifest.checklistCount,
      generatedAt: parsedManifest == null || parsedManifest.generatedAt <= 0
          ? (fallbackGeneratedAt ?? now)
          : parsedManifest.generatedAt,
    );

    return ContentBootstrap(
      manifest: manifest,
      matchingConfig: MatchingConfig.fromJson(matchingConfigJson),
      checklists: checklists,
    );
  }

  Map<String, dynamic> _requireJsonObject(Object? value, String name) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw FormatException('Content package is missing "$name".');
  }

  List<Map<dynamic, dynamic>> _requireJsonList(Object? value, String name) {
    if (value is List) {
      return value.whereType<Map>().toList();
    }
    throw FormatException('Content package is missing "$name".');
  }

  String _friendlyError(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    return 'Import failed: $error';
  }

  String _generatedVersion(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}${twoDigits(date.month)}${twoDigits(date.day)}-$milliseconds';
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
    required this.usesImportedContent,
    this.errorMessage,
  });

  final ContentBootstrap? bootstrap;
  final bool usesImportedContent;
  final String? errorMessage;
}
