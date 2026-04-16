class ChecklistStep {
  ChecklistStep({required this.step, required this.action});

  factory ChecklistStep.fromJson(Map<String, dynamic> json) {
    return ChecklistStep(
      step: json['step'] as int? ?? 0,
      action: json['action'] as String? ?? '',
    );
  }

  final int step;
  final String action;

  Map<String, dynamic> toJson() {
    return {'step': step, 'action': action};
  }
}

class ChecklistBranch {
  ChecklistBranch({required this.condition, required this.action});

  factory ChecklistBranch.fromJson(Map<String, dynamic> json) {
    return ChecklistBranch(
      condition: json['condition'] as String? ?? '',
      action: json['action'] as String? ?? '',
    );
  }

  final String condition;
  final String action;

  Map<String, dynamic> toJson() {
    return {'condition': condition, 'action': action};
  }
}

class Checklist {
  Checklist({
    required this.id,
    required this.title,
    required this.keywords,
    required this.symptoms,
    required this.immediateActions,
    required this.decisionTree,
    required this.rootCause,
    required this.longTermFix,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      keywords: _stringList(json['keywords']),
      symptoms: _stringList(json['symptoms']),
      immediateActions: _mapList(
        json['immediateActions'],
        ChecklistStep.fromJson,
      ),
      decisionTree: _mapList(json['decisionTree'], ChecklistBranch.fromJson),
      rootCause: _stringList(json['rootCause']),
      longTermFix: _stringList(json['longTermFix']),
    );
  }

  final String id;
  final String title;
  final List<String> keywords;
  final List<String> symptoms;
  final List<ChecklistStep> immediateActions;
  final List<ChecklistBranch> decisionTree;
  final List<String> rootCause;
  final List<String> longTermFix;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'keywords': keywords,
      'symptoms': symptoms,
      'immediateActions': immediateActions
          .map((item) => item.toJson())
          .toList(),
      'decisionTree': decisionTree.map((item) => item.toJson()).toList(),
      'rootCause': rootCause,
      'longTermFix': longTermFix,
    };
  }
}

class RankedChecklist {
  RankedChecklist({required this.checklist, required this.score});

  factory RankedChecklist.fromJson(Map<String, dynamic> json) {
    return RankedChecklist(
      checklist: Checklist.fromJson(
        json['checklist'] as Map<String, dynamic>? ?? const {},
      ),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  final Checklist checklist;
  final double score;

  Map<String, dynamic> toJson() {
    return {'checklist': checklist.toJson(), 'score': score};
  }
}

class LookupResponse {
  LookupResponse({
    required this.query,
    required this.bestMatch,
    required this.candidates,
  });

  factory LookupResponse.fromJson(Map<String, dynamic> json) {
    return LookupResponse(
      query: json['query'] as String? ?? '',
      bestMatch: json['bestMatch'] == null
          ? null
          : Checklist.fromJson(json['bestMatch'] as Map<String, dynamic>),
      candidates: _mapList(json['candidates'], RankedChecklist.fromJson),
    );
  }

  final String query;
  final Checklist? bestMatch;
  final List<RankedChecklist> candidates;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'bestMatch': bestMatch?.toJson(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
    };
  }
}

class AgentNavigationResponse {
  AgentNavigationResponse({
    required this.query,
    required this.bestMatch,
    required this.candidates,
    required this.clarifiers,
  });

  factory AgentNavigationResponse.fromJson(Map<String, dynamic> json) {
    return AgentNavigationResponse(
      query: json['query'] as String? ?? '',
      bestMatch: json['bestMatch'] == null
          ? null
          : RankedChecklist.fromJson(
              json['bestMatch'] as Map<String, dynamic>? ?? const {},
            ),
      candidates: _mapList(json['candidates'], RankedChecklist.fromJson),
      clarifiers: _stringList(json['clarifiers']),
    );
  }

  final String query;
  final RankedChecklist? bestMatch;
  final List<RankedChecklist> candidates;
  final List<String> clarifiers;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'bestMatch': bestMatch?.toJson(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
      'clarifiers': clarifiers,
    };
  }
}

class ContentManifest {
  ContentManifest({
    required this.version,
    required this.checklistCount,
    required this.generatedAt,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    return ContentManifest(
      version: json['version'] as String? ?? '',
      checklistCount: json['checklistCount'] as int? ?? 0,
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String version;
  final int checklistCount;
  final int generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'checklistCount': checklistCount,
      'generatedAt': generatedAt,
    };
  }
}

class ContentBootstrap {
  ContentBootstrap({
    required this.manifest,
    required this.matchingConfig,
    required this.checklists,
  });

  factory ContentBootstrap.fromJson(Map<String, dynamic> json) {
    return ContentBootstrap(
      manifest: ContentManifest.fromJson(
        json['manifest'] as Map<String, dynamic>? ?? const {},
      ),
      matchingConfig: MatchingConfig.fromJson(
        json['matchingConfig'] as Map<String, dynamic>? ?? const {},
      ),
      checklists: _mapList(json['checklists'], Checklist.fromJson),
    );
  }

  final ContentManifest manifest;
  final MatchingConfig matchingConfig;
  final List<Checklist> checklists;

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      'matchingConfig': matchingConfig.toJson(),
      'checklists': checklists.map((item) => item.toJson()).toList(),
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
      partialMinLength: json['partialMinLength'] as int? ?? 3,
      synonymGroups: (json['synonymGroups'] as List<dynamic>? ?? const [])
          .map((group) => (group as List<dynamic>).whereType<String>().toList())
          .toList(),
      weights: MatchingWeights.fromJson(
        json['weights'] as Map<String, dynamic>? ?? const {},
      ),
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
    double number(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;

    return MatchingWeights(
      exactQueryId: number('exactQueryId', 1.0),
      exactIdToken: number('exactIdToken', 1.0),
      exactTitleToken: number('exactTitleToken', 0.95),
      exactKeywordToken: number('exactKeywordToken', 0.90),
      exactSymptomToken: number('exactSymptomToken', 0.78),
      exactContextToken: number('exactContextToken', 0.60),
      synonymKeyword: number('synonymKeyword', 0.72),
      synonymPrimary: number('synonymPrimary', 0.62),
      synonymAny: number('synonymAny', 0.50),
      partialKeyword: number('partialKeyword', 0.48),
      partialPrimary: number('partialPrimary', 0.40),
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
