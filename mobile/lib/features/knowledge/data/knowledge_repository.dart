import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/sidecar/rag_sidecar_client.dart';
import '../../../core/storage/local_store.dart';
import '../domain/models.dart';
import 'offline_knowledge_matcher.dart';
import 'review_scheduler.dart';

class KnowledgeRepository {
  KnowledgeRepository(
    this._localStore, {
    AssetBundle? assetBundle,
    RagSidecarClient? sidecarClient,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _sidecarClient = sidecarClient ?? RagSidecarClient(),
       _offlineMatcher = OfflineKnowledgeMatcher(),
       _reviewScheduler = ReviewScheduler();

  static const _defaultBundleAsset = 'assets/content/default_bundle.json';

  final LocalStore _localStore;
  final AssetBundle _assetBundle;
  final RagSidecarClient _sidecarClient;
  final OfflineKnowledgeMatcher _offlineMatcher;
  final ReviewScheduler _reviewScheduler;
  LearningBundle? _preferredBundleCache;

  void dispose() {
    _sidecarClient.dispose();
  }

  Future<LearningSyncResult> loadContent() async {
    try {
      final imported = await loadCachedBundle();
      if (imported != null) {
        _preferredBundleCache = imported;
        return LearningSyncResult(
          bundle: imported,
          usesImportedContent: true,
          validationReport: imported.validationReport,
        );
      }

      final bundled = await loadBundledBundle();
      _preferredBundleCache = bundled;
      return LearningSyncResult(
        bundle: bundled,
        usesImportedContent: false,
        validationReport: bundled.validationReport,
      );
    } catch (error) {
      await _localStore.clearLearningCache();
      try {
        final bundled = await loadBundledBundle();
        _preferredBundleCache = bundled;
        return LearningSyncResult(
          bundle: bundled,
          usesImportedContent: false,
          errorMessage:
              'Imported learning bundle could not be loaded. Using built-in library.',
          validationReport: bundled.validationReport,
        );
      } catch (_) {
        return LearningSyncResult(
          bundle: null,
          usesImportedContent: false,
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<LearningSyncResult> importPackage(String rawPackage) async {
    try {
      final bundle = _decodeBundle(rawPackage);
      await _saveBundle(bundle);
      _preferredBundleCache = bundle;
      return LearningSyncResult(
        bundle: bundle,
        usesImportedContent: true,
        validationReport: bundle.validationReport,
      );
    } catch (error) {
      return LearningSyncResult(
        bundle: null,
        usesImportedContent: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<LearningSyncResult> restoreBundledContent() async {
    await _localStore.clearLearningCache();
    final bundled = await loadBundledBundle();
    _preferredBundleCache = bundled;
    return LearningSyncResult(
      bundle: bundled,
      usesImportedContent: false,
      validationReport: bundled.validationReport,
    );
  }

  Future<LearningBundle> loadBundledBundle() async {
    final raw = await _assetBundle.loadString(_defaultBundleAsset);
    return _decodeBundle(raw, fallbackGeneratedAt: 1776124800000);
  }

  Future<LearningBundle?> loadCachedBundle() async {
    final manifestJson = await _localStore.loadCachedLearningManifest();
    if (manifestJson == null) {
      return null;
    }

    final matchingConfigJson =
        await _localStore.loadCachedLearningMatchingConfig() ??
        _defaultMatchingConfig().toJson();
    final materials = (await _localStore.loadCachedLearningMaterials())
        .map(StudyMaterial.fromJson)
        .toList();
    if (materials.isEmpty) {
      return null;
    }
    final decks = (await _localStore.loadCachedLearningDecks())
        .map(StudyDeck.fromJson)
        .toList();
    final cards = (await _localStore.loadCachedLearningCards())
        .map(StudyCard.fromJson)
        .toList();

    final manifest = LearningManifest.fromJson(manifestJson);
    final report = _validateBundle(manifest, materials, decks, cards);
    if (report.hasErrors) {
      throw FormatException(report.errors.first.message);
    }

    return LearningBundle(
      manifest: manifest,
      matchingConfig: MatchingConfig.fromJson(matchingConfigJson),
      materials: materials,
      decks: decks,
      cards: cards,
      validationReport: report,
    );
  }

  Future<LearningBundle> loadPreferredBundle() async {
    final cachedPreferred = _preferredBundleCache;
    if (cachedPreferred != null) {
      return cachedPreferred;
    }
    final cached = await loadCachedBundle();
    final resolved = cached ?? await loadBundledBundle();
    _preferredBundleCache = resolved;
    return resolved;
  }

  Future<StudyMaterial?> findMaterial(String materialId) async {
    final normalizedId = materialId.toLowerCase();
    final bundle = await loadPreferredBundle();
    for (final material in bundle.materials) {
      if (material.id.toLowerCase() == normalizedId) {
        return material;
      }
    }
    return null;
  }

  Future<StudyMaterial> fetchMaterial(String materialId) async {
    final material = await findMaterial(materialId);
    if (material != null) {
      return material;
    }
    throw StateError('Study material not found: $materialId');
  }

  Future<StudyDeck?> findDeck(String deckId) async {
    final normalizedId = deckId.toLowerCase();
    final bundle = await loadPreferredBundle();
    for (final deck in bundle.decks) {
      if (deck.id.toLowerCase() == normalizedId) {
        return deck;
      }
    }
    return null;
  }

  Future<StudyCard?> findCard(String cardId) async {
    final normalizedId = cardId.toLowerCase();
    final bundle = await loadPreferredBundle();
    for (final card in bundle.cards) {
      if (card.id.toLowerCase() == normalizedId) {
        return card;
      }
    }
    return null;
  }

  Future<KnowledgeSearchResponse> search(String rawQuery) async {
    final query = rawQuery.trim();
    final bundle = await loadPreferredBundle();
    if (query.isEmpty) {
      return KnowledgeSearchResponse(
        query: '',
        bestMatch: null,
        candidates: const [],
      );
    }

    final sidecarResult = await _sidecarClient.searchKnowledge(
      query,
      bundle: bundle,
    );
    if (sidecarResult != null) {
      return sidecarResult;
    }

    return searchCached(query, bundle: bundle);
  }

  KnowledgeSearchResponse searchCached(
    String rawQuery, {
    required LearningBundle bundle,
  }) {
    return _offlineMatcher.search(
      query: rawQuery,
      materials: bundle.materials,
      config: bundle.matchingConfig,
    );
  }

  Future<TutorAnswerResponse> answerQuestion(String rawQuery) async {
    final query = rawQuery.trim();
    final bundle = await loadPreferredBundle();
    if (query.isEmpty) {
      return TutorAnswerResponse(
        query: '',
        answer: '',
        citations: const [],
        candidates: const [],
      );
    }

    final sidecarAnswer = await _sidecarClient.answerLearningQuestion(
      query,
      bundle: bundle,
    );
    if (sidecarAnswer != null) {
      return sidecarAnswer;
    }

    return answerQuestionCached(query, bundle: bundle);
  }

  TutorAnswerResponse answerQuestionCached(
    String rawQuery, {
    required LearningBundle bundle,
  }) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return TutorAnswerResponse(
        query: '',
        answer: '',
        citations: const [],
        candidates: const [],
      );
    }

    final lookup = searchCached(query, bundle: bundle);
    return _buildTutorAnswer(query, lookup.candidates);
  }

  Future<GeneratedCardsResponse> generateCards({
    required List<String> materialIds,
    int limit = 6,
  }) async {
    final bundle = await loadPreferredBundle();
    final normalizedIds = materialIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final selectedMaterials = normalizedIds.isEmpty
        ? bundle.materials.take(3).toList()
        : bundle.materials
              .where((material) => normalizedIds.contains(material.id))
              .toList();

    if (selectedMaterials.isEmpty) {
      return GeneratedCardsResponse(
        materialIds: materialIds,
        cards: const [],
        mode: 'error',
        notice: 'No source materials were found for card generation.',
      );
    }

    final sidecarCards = await _sidecarClient.generateCards(
      materialIds: selectedMaterials.map((item) => item.id).toList(),
      bundle: bundle,
      limit: limit,
    );
    if (sidecarCards != null) {
      final updated = await addCards(sidecarCards.cards);
      return GeneratedCardsResponse(
        materialIds: sidecarCards.materialIds,
        cards: updated,
        mode: sidecarCards.mode,
        notice: sidecarCards.notice,
      );
    }

    return GeneratedCardsResponse(
      materialIds: selectedMaterials.map((item) => item.id).toList(),
      cards: const [],
      mode: 'error',
      notice:
          'AI card generation is unavailable. Configure the Go sidecar and an LLM provider to generate cards. Search and review still work offline.',
    );
  }

  Future<List<StudyCard>> addCards(List<StudyCard> cards) async {
    final cleanCards = cards
        .where(
          (card) =>
              card.id.trim().isNotEmpty &&
              card.front.trim().isNotEmpty &&
              card.back.trim().isNotEmpty,
        )
        .toList();
    if (cleanCards.isEmpty) {
      return const [];
    }

    final bundle = await loadPreferredBundle();
    final existingCards = <String, StudyCard>{
      for (final card in bundle.cards) card.id: card,
    };
    for (final card in cleanCards) {
      existingCards[card.id] = card;
    }

    final decksById = <String, StudyDeck>{for (final deck in bundle.decks) deck.id: deck};
    for (final card in cleanCards) {
      final deckId = card.deckId.trim().isEmpty ? 'generated' : card.deckId;
      final deck = decksById[deckId] ??
          StudyDeck(
            id: deckId,
            title: deckId == 'generated' ? 'Generated Cards' : deckId,
            goal: 'Review generated cards from imported materials.',
            tags: const ['generated'],
          );
      final nextIds = <String>{...deck.cardIds, card.id}.toList();
      decksById[deckId] = deck.copyWith(cardIds: nextIds);
    }

    final updatedBundle = bundle.copyWith(
      decks: decksById.values.toList(),
      cards: existingCards.values.toList(),
    );
    await _saveBundle(updatedBundle);
    _preferredBundleCache = updatedBundle;

    final reviewStates = await loadReviewStates();
    var changedReview = false;
    for (final card in cleanCards) {
      if (!reviewStates.containsKey(card.id)) {
        reviewStates[card.id] = ReviewState.newCard(card.id);
        changedReview = true;
      }
    }
    if (changedReview) {
      await saveReviewStates(reviewStates);
    }
    return cleanCards;
  }

  Future<Map<String, ReviewState>> loadReviewStates() async {
    final stored = (await _localStore.loadLearningReviewStates())
        .map(ReviewState.fromJson)
        .where((state) => state.cardId.trim().isNotEmpty)
        .toList();
    final byId = <String, ReviewState>{for (final state in stored) state.cardId: state};
    final bundle = await loadPreferredBundle();
    var changed = false;
    for (final card in bundle.cards) {
      if (!byId.containsKey(card.id)) {
        byId[card.id] = ReviewState.newCard(card.id);
        changed = true;
      }
    }
    if (changed) {
      await saveReviewStates(byId);
    }
    return byId;
  }

  Future<void> saveReviewStates(Map<String, ReviewState> states) async {
    await _localStore.saveLearningReviewStates(
      states.values.map((state) => state.toJson()).toList(),
    );
  }

  Future<List<StudyCard>> dueCards({DateTime? now}) async {
    final resolvedNow = now ?? DateTime.now();
    final bundle = await loadPreferredBundle();
    final states = await loadReviewStates();
    return bundle.cards
        .where((card) => states[card.id]?.isDue(resolvedNow) ?? true)
        .toList();
  }

  Future<ReviewResult> reviewCard({
    required String cardId,
    required ReviewGrade grade,
    DateTime? now,
  }) async {
    final states = await loadReviewStates();
    final state = states[cardId] ?? ReviewState.newCard(cardId, now: now);
    final result = _reviewScheduler.schedule(
      state: state,
      grade: grade,
      now: now,
    );
    states[cardId] = result.updatedState;
    await saveReviewStates(states);
    return result;
  }

  Future<void> _saveBundle(LearningBundle bundle) {
    return _localStore.saveLearningCache(
      manifest: bundle.manifest.toJson(),
      matchingConfig: bundle.matchingConfig.toJson(),
      materials: bundle.materials.map((item) => item.toJson()).toList(),
      decks: bundle.decks.map((item) => item.toJson()).toList(),
      cards: bundle.cards.map((item) => item.toJson()).toList(),
    );
  }

  LearningBundle _decodeBundle(
    String rawPackage, {
    int? fallbackGeneratedAt,
  }) {
    final decoded = jsonDecode(rawPackage);
    if (decoded is! Map) {
      throw const FormatException('Learning bundle must be a JSON object.');
    }

    final json = decoded.cast<String, dynamic>();
    final matchingConfigJson = _requireJsonObject(
      json['matchingConfig'],
      'matchingConfig',
    );
    final materialJson = _requireJsonList(json['materials'], 'materials');
    if (materialJson.isEmpty) {
      throw const FormatException(
        'Learning bundle must include at least one material.',
      );
    }

    final materials = materialJson
        .map((item) => StudyMaterial.fromJson(item.cast<String, dynamic>()))
        .where(
          (item) => item.id.trim().isNotEmpty && item.title.trim().isNotEmpty,
        )
        .toList();
    if (materials.isEmpty) {
      throw const FormatException(
        'Learning bundle materials must include non-empty id and title values.',
      );
    }

    final decks = _optionalJsonList(json['decks'])
        .map((item) => StudyDeck.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.id.trim().isNotEmpty && item.title.trim().isNotEmpty)
        .toList();
    final cards = _optionalJsonList(json['cards'])
        .map((item) => StudyCard.fromJson(item.cast<String, dynamic>()))
        .where(
          (item) =>
              item.id.trim().isNotEmpty &&
              item.front.trim().isNotEmpty &&
              item.back.trim().isNotEmpty,
        )
        .toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    final manifestJson = json['manifest'];
    final parsedManifest = manifestJson is Map
        ? LearningManifest.fromJson(manifestJson.cast<String, dynamic>())
        : null;
    final manifest = LearningManifest(
      schemaVersion: parsedManifest?.schemaVersion ?? 1,
      packageId: parsedManifest?.packageId ?? '',
      name: parsedManifest?.name ?? '',
      version: (parsedManifest?.version ?? '').trim().isNotEmpty
          ? parsedManifest!.version
          : _generatedVersion(now),
      generatedAt: parsedManifest == null || parsedManifest.generatedAt <= 0
          ? (fallbackGeneratedAt ?? now)
          : parsedManifest.generatedAt,
      defaultLocale: parsedManifest?.defaultLocale ?? 'zh-CN',
      sourceType: parsedManifest?.sourceType ?? 'bundle',
    );
    final report = _validateBundle(manifest, materials, decks, cards);
    if (report.hasErrors) {
      throw FormatException(report.errors.first.message);
    }

    return LearningBundle(
      manifest: manifest,
      matchingConfig: MatchingConfig.fromJson(matchingConfigJson),
      materials: materials,
      decks: decks,
      cards: cards,
      validationReport: report,
    );
  }

  ContentValidationReport _validateBundle(
    LearningManifest manifest,
    List<StudyMaterial> materials,
    List<StudyDeck> decks,
    List<StudyCard> cards,
  ) {
    final errors = <ContentValidationIssue>[];
    final warnings = <ContentValidationIssue>[];

    if (manifest.schemaVersion <= 0 || manifest.schemaVersion > 2) {
      errors.add(
        ContentValidationIssue(
          path: 'manifest.schemaVersion',
          message: 'Unsupported learning bundle schema version.',
        ),
      );
    }

    final materialIds = <String>{};
    for (var index = 0; index < materials.length; index++) {
      final material = materials[index];
      final path = 'materials[$index]';
      final id = material.id.trim();
      if (id.isEmpty || material.title.trim().isEmpty) {
        errors.add(
          ContentValidationIssue(
            path: path,
            message:
                'Learning bundle materials must include non-empty id and title values.',
          ),
        );
        continue;
      }
      final normalized = id.toLowerCase();
      if (materialIds.contains(normalized)) {
        errors.add(
          ContentValidationIssue(
            path: '$path.id',
            message: 'Duplicate material id "$id".',
          ),
        );
      }
      materialIds.add(normalized);
      if (material.summary.trim().length < 16) {
        warnings.add(
          ContentValidationIssue(
            path: '$path.summary',
            message: 'Study material summary is missing or too short.',
          ),
        );
      }
      if (material.content.trim().isEmpty && material.chunks.isEmpty) {
        warnings.add(
          ContentValidationIssue(
            path: '$path.content',
            message: 'Study material should include content or chunks.',
          ),
        );
      }
    }

    final deckIds = <String>{};
    for (var index = 0; index < decks.length; index++) {
      final deck = decks[index];
      final path = 'decks[$index]';
      final id = deck.id.trim();
      if (id.isEmpty || deck.title.trim().isEmpty) {
        errors.add(
          ContentValidationIssue(
            path: path,
            message: 'Decks must include non-empty id and title values.',
          ),
        );
      }
      final normalized = id.toLowerCase();
      if (deckIds.contains(normalized)) {
        errors.add(
          ContentValidationIssue(
            path: '$path.id',
            message: 'Duplicate deck id "$id".',
          ),
        );
      }
      deckIds.add(normalized);
    }

    final cardIds = <String>{};
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      final path = 'cards[$index]';
      final id = card.id.trim();
      if (id.isEmpty || card.front.trim().isEmpty || card.back.trim().isEmpty) {
        errors.add(
          ContentValidationIssue(
            path: path,
            message: 'Cards must include non-empty id, front, and back values.',
          ),
        );
      }
      final normalized = id.toLowerCase();
      if (cardIds.contains(normalized)) {
        errors.add(
          ContentValidationIssue(
            path: '$path.id',
            message: 'Duplicate card id "$id".',
          ),
        );
      }
      cardIds.add(normalized);
      if (card.deckId.trim().isNotEmpty &&
          deckIds.isNotEmpty &&
          !deckIds.contains(card.deckId.toLowerCase())) {
        warnings.add(
          ContentValidationIssue(
            path: '$path.deckId',
            message: 'Card references a missing deck.',
          ),
        );
      }
      for (final materialId in card.sourceMaterialIds) {
        if (!materialIds.contains(materialId.toLowerCase())) {
          warnings.add(
            ContentValidationIssue(
              path: '$path.sourceMaterialIds',
              message: 'Card references a missing source material.',
            ),
          );
          break;
        }
      }
    }

    return ContentValidationReport(errors: errors, warnings: warnings);
  }

  TutorAnswerResponse _buildTutorAnswer(
    String query,
    List<RankedKnowledgeItem> candidates,
  ) {
    final citations = candidates
        .map(
          (item) => TutorCitation(
            id: item.material.id,
            title: item.material.title,
            score: item.score,
          ),
        )
        .toList();

    if (candidates.isEmpty) {
      return TutorAnswerResponse(
        query: query,
        answer:
            'No matching material was found in the local library. Try a more specific concept, exam topic, project name, or error signal.',
        citations: citations,
        candidates: candidates,
        mode: 'local',
      );
    }

    final best = candidates.first.material;
    final buffer = StringBuffer()
      ..writeln('Start with "${best.title}" because it is the strongest match.')
      ..writeln();
    if (best.summary.trim().isNotEmpty) {
      buffer.writeln('Summary: ${best.summary.trim()}');
    }
    final chunks = best.chunks.isNotEmpty ? best.chunks : _splitSentences(best.content);
    if (chunks.isNotEmpty) {
      buffer.writeln('Key points:');
      for (final chunk in chunks.take(3)) {
        buffer.writeln('- ${chunk.trim()}');
      }
    }
    final alternatives = candidates.skip(1).take(2).toList();
    if (alternatives.isNotEmpty) {
      buffer.writeln(
        'Also compare: ${alternatives.map((item) => item.material.title).join(', ')}.',
      );
    }

    return TutorAnswerResponse(
      query: query,
      answer: buffer.toString().trim(),
      citations: citations,
      candidates: candidates,
      mode: 'local',
    );
  }


  List<String> _splitSentences(String value) {
    return value
        .split(RegExp(r'[。.!?！？\n]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 8)
        .toList();
  }


  Map<String, dynamic> _requireJsonObject(Object? value, String name) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw FormatException('Learning bundle is missing "$name".');
  }

  List<Map<dynamic, dynamic>> _requireJsonList(Object? value, String name) {
    if (value is List) {
      return value.whereType<Map>().toList();
    }
    throw FormatException('Learning bundle is missing "$name".');
  }

  List<Map<dynamic, dynamic>> _optionalJsonList(Object? value) {
    if (value is List) {
      return value.whereType<Map>().toList();
    }
    return const [];
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
      partialMinLength: 2,
      synonymGroups: const [
        ['english', 'vocabulary', 'word', 'phrase', 'translation'],
        ['exam', 'test', 'cet', 'postgraduate', 'score'],
        ['project', 'engineering', 'architecture', 'api', 'service'],
        ['database', 'sql', 'mysql', 'index', 'query'],
        ['review', 'card', 'memory', 'recall', 'practice'],
      ],
      weights: MatchingWeights(
        exactQueryId: 1.0,
        exactIdToken: 1.0,
        exactTitleToken: 0.95,
        exactKeywordToken: 0.9,
        exactSymptomToken: 0.78,
        exactContextToken: 0.6,
        synonymKeyword: 0.72,
        synonymPrimary: 0.62,
        synonymAny: 0.5,
        partialKeyword: 0.48,
        partialPrimary: 0.4,
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

class LearningSyncResult {
  LearningSyncResult({
    required this.bundle,
    required this.usesImportedContent,
    this.errorMessage,
    this.validationReport = ContentValidationReport.empty,
  });

  final LearningBundle? bundle;
  final bool usesImportedContent;
  final String? errorMessage;
  final ContentValidationReport validationReport;
}
