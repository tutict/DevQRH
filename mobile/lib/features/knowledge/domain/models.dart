enum MaterialType { exam, engineering, course, project, note }

enum ReviewGrade { again, hard, good, easy }

class LearningManifest {
  LearningManifest({
    this.schemaVersion = 1,
    this.packageId = '',
    this.name = '',
    required this.version,
    required this.generatedAt,
    this.defaultLocale = 'zh-CN',
    this.sourceType = 'bundle',
  });

  factory LearningManifest.fromJson(Map<String, dynamic> json) {
    return LearningManifest(
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      packageId: json['packageId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
      defaultLocale: json['defaultLocale'] as String? ?? 'zh-CN',
      sourceType: json['sourceType'] as String? ?? 'bundle',
    );
  }

  final int schemaVersion;
  final String packageId;
  final String name;
  final String version;
  final int generatedAt;
  final String defaultLocale;
  final String sourceType;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'packageId': packageId,
      'name': name,
      'version': version,
      'generatedAt': generatedAt,
      'defaultLocale': defaultLocale,
      'sourceType': sourceType,
    };
  }
}

class StudyMaterial {
  StudyMaterial({
    required this.id,
    required this.title,
    this.type = MaterialType.note,
    this.tags = const [],
    this.summary = '',
    this.content = '',
    this.source = '',
    this.chunks = const [],
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: _parseMaterialType(json['type']),
      tags: _stringList(json['tags']),
      summary: json['summary'] as String? ?? '',
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? '',
      chunks: _stringList(json['chunks']),
    );
  }

  final String id;
  final String title;
  final MaterialType type;
  final List<String> tags;
  final String summary;
  final String content;
  final String source;
  final List<String> chunks;

  String get searchableText {
    return [
      id,
      title,
      type.name,
      ...tags,
      summary,
      content,
      source,
      ...chunks,
    ].join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'tags': tags,
      'summary': summary,
      'content': content,
      'source': source,
      'chunks': chunks,
    };
  }
}

class StudyDeck {
  StudyDeck({
    required this.id,
    required this.title,
    this.goal = '',
    this.tags = const [],
    this.cardIds = const [],
  });

  factory StudyDeck.fromJson(Map<String, dynamic> json) {
    return StudyDeck(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      tags: _stringList(json['tags']),
      cardIds: _stringList(json['cardIds']),
    );
  }

  final String id;
  final String title;
  final String goal;
  final List<String> tags;
  final List<String> cardIds;

  StudyDeck copyWith({List<String>? cardIds}) {
    return StudyDeck(
      id: id,
      title: title,
      goal: goal,
      tags: tags,
      cardIds: cardIds ?? this.cardIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'goal': goal,
      'tags': tags,
      'cardIds': cardIds,
    };
  }
}

class StudyCard {
  StudyCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.explanation = '',
    this.tags = const [],
    this.difficulty = 2,
    this.sourceMaterialIds = const [],
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      id: json['id'] as String? ?? '',
      deckId: json['deckId'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      tags: _stringList(json['tags']),
      difficulty: _intValue(json['difficulty']) ?? 2,
      sourceMaterialIds: _stringList(json['sourceMaterialIds']),
    );
  }

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String explanation;
  final List<String> tags;
  final int difficulty;
  final List<String> sourceMaterialIds;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deckId': deckId,
      'front': front,
      'back': back,
      'explanation': explanation,
      'tags': tags,
      'difficulty': difficulty,
      'sourceMaterialIds': sourceMaterialIds,
    };
  }
}

class RankedKnowledgeItem {
  RankedKnowledgeItem({required this.material, required this.score});

  factory RankedKnowledgeItem.fromJson(Map<String, dynamic> json) {
    return RankedKnowledgeItem(
      material: StudyMaterial.fromJson(_jsonObject(json['material'])),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  final StudyMaterial material;
  final double score;

  Map<String, dynamic> toJson() {
    return {'material': material.toJson(), 'score': score};
  }
}

class KnowledgeSearchResponse {
  KnowledgeSearchResponse({
    required this.query,
    required this.bestMatch,
    required this.candidates,
  });

  factory KnowledgeSearchResponse.fromJson(Map<String, dynamic> json) {
    return KnowledgeSearchResponse(
      query: json['query'] as String? ?? '',
      bestMatch: json['bestMatch'] == null
          ? null
          : StudyMaterial.fromJson(_jsonObject(json['bestMatch'])),
      candidates: _mapList(json['candidates'], RankedKnowledgeItem.fromJson),
    );
  }

  final String query;
  final StudyMaterial? bestMatch;
  final List<RankedKnowledgeItem> candidates;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'bestMatch': bestMatch?.toJson(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
    };
  }
}

class TutorCitation {
  TutorCitation({required this.id, required this.title, required this.score});

  factory TutorCitation.fromJson(Map<String, dynamic> json) {
    return TutorCitation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String title;
  final double score;

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'score': score};
  }
}

class TutorAnswerResponse {
  TutorAnswerResponse({
    required this.query,
    required this.answer,
    required this.citations,
    required this.candidates,
    this.mode = 'local',
    this.notice,
  });

  factory TutorAnswerResponse.fromJson(Map<String, dynamic> json) {
    return TutorAnswerResponse(
      query: json['query'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      citations: _mapList(json['citations'], TutorCitation.fromJson),
      candidates: _mapList(json['candidates'], RankedKnowledgeItem.fromJson),
      mode: json['mode'] as String? ?? 'local',
      notice: json['notice'] as String?,
    );
  }

  final String query;
  final String answer;
  final List<TutorCitation> citations;
  final List<RankedKnowledgeItem> candidates;
  final String mode;
  final String? notice;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'answer': answer,
      'citations': citations.map((item) => item.toJson()).toList(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
      'mode': mode,
      'notice': notice,
    };
  }
}

class GeneratedCardsResponse {
  GeneratedCardsResponse({
    required this.materialIds,
    required this.cards,
    this.mode = 'local',
    this.notice,
  });

  factory GeneratedCardsResponse.fromJson(Map<String, dynamic> json) {
    return GeneratedCardsResponse(
      materialIds: _stringList(json['materialIds']),
      cards: _mapList(json['cards'], StudyCard.fromJson),
      mode: json['mode'] as String? ?? 'local',
      notice: json['notice'] as String?,
    );
  }

  final List<String> materialIds;
  final List<StudyCard> cards;
  final String mode;
  final String? notice;

  Map<String, dynamic> toJson() {
    return {
      'materialIds': materialIds,
      'cards': cards.map((item) => item.toJson()).toList(),
      'mode': mode,
      'notice': notice,
    };
  }
}

class ReviewState {
  ReviewState({
    required this.cardId,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitionCount = 0,
    required this.dueAt,
    this.lastReviewedAt,
    this.lapses = 0,
  });

  factory ReviewState.newCard(String cardId, {DateTime? now}) {
    return ReviewState(cardId: cardId, dueAt: now ?? DateTime.now());
  }

  factory ReviewState.fromJson(Map<String, dynamic> json) {
    return ReviewState(
      cardId: json['cardId'] as String? ?? '',
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: _intValue(json['intervalDays']) ?? 0,
      repetitionCount: _intValue(json['repetitionCount']) ?? 0,
      dueAt: _dateValue(json['dueAt']) ?? DateTime.now(),
      lastReviewedAt: _dateValue(json['lastReviewedAt']),
      lapses: _intValue(json['lapses']) ?? 0,
    );
  }

  final String cardId;
  final double easeFactor;
  final int intervalDays;
  final int repetitionCount;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int lapses;

  bool isDue(DateTime now) {
    return !dueAt.isAfter(now);
  }

  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'repetitionCount': repetitionCount,
      'dueAt': dueAt.millisecondsSinceEpoch,
      'lastReviewedAt': lastReviewedAt?.millisecondsSinceEpoch,
      'lapses': lapses,
    };
  }
}

class ReviewResult {
  ReviewResult({
    required this.cardId,
    required this.nextDueAt,
    required this.updatedState,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      cardId: json['cardId'] as String? ?? '',
      nextDueAt: _dateValue(json['nextDueAt']) ?? DateTime.now(),
      updatedState: ReviewState.fromJson(_jsonObject(json['updatedState'])),
    );
  }

  final String cardId;
  final DateTime nextDueAt;
  final ReviewState updatedState;

  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'nextDueAt': nextDueAt.millisecondsSinceEpoch,
      'updatedState': updatedState.toJson(),
    };
  }
}

class LearningBundle {
  LearningBundle({
    required this.manifest,
    required this.matchingConfig,
    required this.materials,
    this.decks = const [],
    this.cards = const [],
    this.validationReport = ContentValidationReport.empty,
  });

  factory LearningBundle.fromJson(Map<String, dynamic> json) {
    return LearningBundle(
      manifest: LearningManifest.fromJson(_jsonObject(json['manifest'])),
      matchingConfig: MatchingConfig.fromJson(_jsonObject(json['matchingConfig'])),
      materials: _mapList(json['materials'], StudyMaterial.fromJson),
      decks: _mapList(json['decks'], StudyDeck.fromJson),
      cards: _mapList(json['cards'], StudyCard.fromJson),
      validationReport: json['validation'] is Map
          ? ContentValidationReport.fromJson(_jsonObject(json['validation']))
          : ContentValidationReport.empty,
    );
  }

  final LearningManifest manifest;
  final MatchingConfig matchingConfig;
  final List<StudyMaterial> materials;
  final List<StudyDeck> decks;
  final List<StudyCard> cards;
  final ContentValidationReport validationReport;

  LearningBundle copyWith({
    List<StudyMaterial>? materials,
    List<StudyDeck>? decks,
    List<StudyCard>? cards,
  }) {
    return LearningBundle(
      manifest: manifest,
      matchingConfig: matchingConfig,
      materials: materials ?? this.materials,
      decks: decks ?? this.decks,
      cards: cards ?? this.cards,
      validationReport: validationReport,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      'matchingConfig': matchingConfig.toJson(),
      'materials': materials.map((item) => item.toJson()).toList(),
      'decks': decks.map((item) => item.toJson()).toList(),
      'cards': cards.map((item) => item.toJson()).toList(),
      if (!validationReport.isEmpty) 'validation': validationReport.toJson(),
    };
  }
}

class ContentValidationIssue {
  ContentValidationIssue({required this.path, required this.message});

  factory ContentValidationIssue.fromJson(Map<String, dynamic> json) {
    return ContentValidationIssue(
      path: json['path'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final String path;
  final String message;

  Map<String, dynamic> toJson() => {'path': path, 'message': message};
}

class ContentValidationReport {
  const ContentValidationReport({
    this.errors = const [],
    this.warnings = const [],
  });

  factory ContentValidationReport.fromJson(Map<String, dynamic> json) {
    return ContentValidationReport(
      errors: _mapList(json['errors'], ContentValidationIssue.fromJson),
      warnings: _mapList(json['warnings'], ContentValidationIssue.fromJson),
    );
  }

  static const empty = ContentValidationReport();

  final List<ContentValidationIssue> errors;
  final List<ContentValidationIssue> warnings;

  bool get hasErrors => errors.isNotEmpty;
  bool get isEmpty => errors.isEmpty && warnings.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'errors': errors.map((item) => item.toJson()).toList(),
      'warnings': warnings.map((item) => item.toJson()).toList(),
    };
  }
}

class MatchingConfig {
  MatchingConfig({
    required this.partialMinLength,
    required this.synonymGroups,
    required this.weights,
  });

  factory MatchingConfig.fromJson(Map<String, dynamic> json) {
    return MatchingConfig(
      partialMinLength: _intValue(json['partialMinLength']) ?? 2,
      synonymGroups: (json['synonymGroups'] as List<dynamic>? ?? const [])
          .map((group) => (group as List<dynamic>).whereType<String>().toList())
          .toList(),
      weights: MatchingWeights.fromJson(_jsonObject(json['weights'])),
    );
  }

  final int partialMinLength;
  final List<List<String>> synonymGroups;
  final MatchingWeights weights;

  Map<String, dynamic> toJson() {
    return {
      'partialMinLength': partialMinLength,
      'synonymGroups': synonymGroups,
      'weights': weights.toJson(),
    };
  }
}

class MatchingWeights {
  MatchingWeights({
    required this.exactQueryId,
    required this.exactIdToken,
    required this.exactTitleToken,
    required this.exactKeywordToken,
    required this.exactSymptomToken,
    required this.exactContextToken,
    required this.synonymKeyword,
    required this.synonymPrimary,
    required this.synonymAny,
    required this.partialKeyword,
    required this.partialPrimary,
    required this.partialAny,
    required this.tokenAverage,
    required this.keywordCoverage,
    required this.exactTitleBoost,
    required this.partialTitleBoost,
    required this.partialIdBoost,
    required this.phraseBoost,
  });

  factory MatchingWeights.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      return (json[key] as num?)?.toDouble() ?? fallback;
    }

    return MatchingWeights(
      exactQueryId: number('exactQueryId', 1.0),
      exactIdToken: number('exactIdToken', 1.0),
      exactTitleToken: number('exactTitleToken', 0.95),
      exactKeywordToken: number('exactKeywordToken', 0.9),
      exactSymptomToken: number('exactSymptomToken', 0.78),
      exactContextToken: number('exactContextToken', 0.6),
      synonymKeyword: number('synonymKeyword', 0.72),
      synonymPrimary: number('synonymPrimary', 0.62),
      synonymAny: number('synonymAny', 0.5),
      partialKeyword: number('partialKeyword', 0.48),
      partialPrimary: number('partialPrimary', 0.4),
      partialAny: number('partialAny', 0.28),
      tokenAverage: number('tokenAverage', 0.88),
      keywordCoverage: number('keywordCoverage', 0.12),
      exactTitleBoost: number('exactTitleBoost', 0.12),
      partialTitleBoost: number('partialTitleBoost', 0.07),
      partialIdBoost: number('partialIdBoost', 0.07),
      phraseBoost: number('phraseBoost', 0.04),
    );
  }

  final double exactQueryId;
  final double exactIdToken;
  final double exactTitleToken;
  final double exactKeywordToken;
  final double exactSymptomToken;
  final double exactContextToken;
  final double synonymKeyword;
  final double synonymPrimary;
  final double synonymAny;
  final double partialKeyword;
  final double partialPrimary;
  final double partialAny;
  final double tokenAverage;
  final double keywordCoverage;
  final double exactTitleBoost;
  final double partialTitleBoost;
  final double partialIdBoost;
  final double phraseBoost;

  Map<String, dynamic> toJson() {
    return {
      'exactQueryId': exactQueryId,
      'exactIdToken': exactIdToken,
      'exactTitleToken': exactTitleToken,
      'exactKeywordToken': exactKeywordToken,
      'exactSymptomToken': exactSymptomToken,
      'exactContextToken': exactContextToken,
      'synonymKeyword': synonymKeyword,
      'synonymPrimary': synonymPrimary,
      'synonymAny': synonymAny,
      'partialKeyword': partialKeyword,
      'partialPrimary': partialPrimary,
      'partialAny': partialAny,
      'tokenAverage': tokenAverage,
      'keywordCoverage': keywordCoverage,
      'exactTitleBoost': exactTitleBoost,
      'partialTitleBoost': partialTitleBoost,
      'partialIdBoost': partialIdBoost,
      'phraseBoost': phraseBoost,
    };
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const [];
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => mapper(item.cast<String, dynamic>()))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _jsonObject(Object? value) {
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return const {};
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int && value > 0) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num && value > 0) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

MaterialType _parseMaterialType(Object? value) {
  final normalized = (value as String? ?? '').trim().toLowerCase();
  return MaterialType.values.firstWhere(
    (type) => type.name == normalized,
    orElse: () => MaterialType.note,
  );
}
