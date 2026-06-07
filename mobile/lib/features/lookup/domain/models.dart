enum StepRisk { safe, caution, danger }

class ChecklistStep {
  ChecklistStep({
    required this.step,
    required this.action,
    this.risk = StepRisk.safe,
  });

  factory ChecklistStep.fromJson(Map<String, dynamic> json) {
    return ChecklistStep(
      step: json['step'] as int? ?? 0,
      action: json['action'] as String? ?? '',
      risk: _parseStepRisk(json['risk'] ?? json['riskLevel']),
    );
  }

  final int step;
  final String action;
  final StepRisk risk;

  ChecklistStep copyWith({int? step, String? action, StepRisk? risk}) {
    return ChecklistStep(
      step: step ?? this.step,
      action: action ?? this.action,
      risk: risk ?? this.risk,
    );
  }

  Map<String, dynamic> toJson() {
    return {'step': step, 'action': action, 'risk': _stepRiskToJson(risk)};
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

class RunbookCommand {
  RunbookCommand({
    this.id = '',
    this.title = '',
    required this.command,
    this.step,
    this.risk = StepRisk.safe,
  });

  factory RunbookCommand.fromJson(Map<String, dynamic> json) {
    return RunbookCommand(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? json['label'] as String? ?? '',
      command:
          json['command'] as String? ??
          json['content'] as String? ??
          json['snippet'] as String? ??
          '',
      step: _intValue(json['step'] ?? json['stepId']),
      risk: _parseStepRisk(json['risk'] ?? json['riskLevel']),
    );
  }

  final String id;
  final String title;
  final String command;
  final int? step;
  final StepRisk risk;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'command': command,
      'step': step,
      'risk': _stepRiskToJson(risk),
    };
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
    List<String>? tags,
    String? summary,
    String? severity,
    List<String>? systems,
    List<String>? signals,
    String? impact,
    String? owner,
    String? escalation,
    String? lastReviewedAt,
    int? reviewIntervalDays,
    List<String>? prerequisites,
    List<ChecklistStep>? safeSteps,
    List<ChecklistStep>? cautionSteps,
    List<ChecklistStep>? dangerSteps,
    List<RunbookCommand>? commands,
    List<String>? relatedRunbooks,
  }) : tags = tags ?? const [],
       summary = summary ?? '',
       severity = _normalizeSeverity(severity),
       systems = systems ?? const [],
       signals = signals ?? const [],
       impact = impact ?? '',
       owner = owner ?? '',
       escalation = escalation ?? '',
       lastReviewedAt = lastReviewedAt ?? '',
       reviewIntervalDays = reviewIntervalDays ?? 180,
       prerequisites = prerequisites ?? const [],
       safeSteps = safeSteps ?? immediateActions,
       cautionSteps = cautionSteps ?? const [],
       dangerSteps = dangerSteps ?? const [],
       commands = commands ?? const [],
       relatedRunbooks = relatedRunbooks ?? const [];

  factory Checklist.fromJson(Map<String, dynamic> json) {
    final tags = _stringList(json['tags']);
    final keywords = _stringList(json['keywords']);
    final immediateActions = _mapList(
      json['immediateActions'],
      ChecklistStep.fromJson,
    );
    final explicitSafeSteps = _mapList(
      json['safeSteps'],
      ChecklistStep.fromJson,
    );
    final safeSteps = explicitSafeSteps.isEmpty
        ? immediateActions
              .map((step) => step.copyWith(risk: StepRisk.safe))
              .toList()
        : explicitSafeSteps;

    return Checklist(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      keywords: keywords.isEmpty ? tags : keywords,
      symptoms: _stringList(json['symptoms']),
      immediateActions: immediateActions.isEmpty ? safeSteps : immediateActions,
      decisionTree: _mapList(json['decisionTree'], ChecklistBranch.fromJson),
      rootCause: _stringList(json['rootCause']),
      longTermFix: _stringList(json['longTermFix']),
      tags: tags,
      summary: json['summary'] as String? ?? '',
      severity: json['severity'] as String?,
      systems: _stringList(json['systems']),
      signals: _stringList(json['signals']),
      impact: json['impact'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      escalation: json['escalation'] as String? ?? '',
      lastReviewedAt: json['lastReviewedAt'] as String? ?? '',
      reviewIntervalDays: _intValue(json['reviewIntervalDays']),
      prerequisites: _stringList(json['prerequisites']),
      safeSteps: safeSteps,
      cautionSteps: _mapList(json['cautionSteps'], ChecklistStep.fromJson),
      dangerSteps: _mapList(json['dangerSteps'], ChecklistStep.fromJson),
      commands: _mapList(json['commands'], RunbookCommand.fromJson),
      relatedRunbooks: _stringList(json['relatedRunbooks']),
    );
  }

  final String id;
  final String title;
  final List<String> keywords;
  final List<String> tags;
  final String summary;
  final String severity;
  final List<String> systems;
  final List<String> signals;
  final String impact;
  final String owner;
  final String escalation;
  final String lastReviewedAt;
  final int reviewIntervalDays;
  final List<String> prerequisites;
  final List<String> symptoms;
  final List<ChecklistStep> immediateActions;
  final List<ChecklistStep> safeSteps;
  final List<ChecklistStep> cautionSteps;
  final List<ChecklistStep> dangerSteps;
  final List<RunbookCommand> commands;
  final List<ChecklistBranch> decisionTree;
  final List<String> rootCause;
  final List<String> longTermFix;
  final List<String> relatedRunbooks;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'keywords': keywords,
      'tags': tags,
      'summary': summary,
      'severity': severity,
      'systems': systems,
      'signals': signals,
      'impact': impact,
      'owner': owner,
      'escalation': escalation,
      'lastReviewedAt': lastReviewedAt,
      'reviewIntervalDays': reviewIntervalDays,
      'prerequisites': prerequisites,
      'symptoms': symptoms,
      'immediateActions': immediateActions
          .map((item) => item.toJson())
          .toList(),
      'safeSteps': safeSteps.map((item) => item.toJson()).toList(),
      'cautionSteps': cautionSteps.map((item) => item.toJson()).toList(),
      'dangerSteps': dangerSteps.map((item) => item.toJson()).toList(),
      'commands': commands.map((item) => item.toJson()).toList(),
      'decisionTree': decisionTree.map((item) => item.toJson()).toList(),
      'rootCause': rootCause,
      'longTermFix': longTermFix,
      'relatedRunbooks': relatedRunbooks,
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
    this.ragAnswer,
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
      ragAnswer: json['ragAnswer'] == null
          ? null
          : RagAnswerResponse.fromJson(
              json['ragAnswer'] as Map<String, dynamic>? ?? const {},
            ),
    );
  }

  final String query;
  final RankedChecklist? bestMatch;
  final List<RankedChecklist> candidates;
  final List<String> clarifiers;
  final RagAnswerResponse? ragAnswer;

  AgentNavigationResponse copyWith({
    String? query,
    RankedChecklist? bestMatch,
    List<RankedChecklist>? candidates,
    List<String>? clarifiers,
    RagAnswerResponse? ragAnswer,
  }) {
    return AgentNavigationResponse(
      query: query ?? this.query,
      bestMatch: bestMatch ?? this.bestMatch,
      candidates: candidates ?? this.candidates,
      clarifiers: clarifiers ?? this.clarifiers,
      ragAnswer: ragAnswer ?? this.ragAnswer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'bestMatch': bestMatch?.toJson(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
      'clarifiers': clarifiers,
      'ragAnswer': ragAnswer?.toJson(),
    };
  }
}

class RagCitation {
  RagCitation({required this.id, required this.title, required this.score});

  factory RagCitation.fromJson(Map<String, dynamic> json) {
    return RagCitation(
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

class RagAnswerResponse {
  RagAnswerResponse({
    required this.query,
    required this.answer,
    required this.citations,
    required this.candidates,
    this.mode = 'local',
    this.provider,
    this.model,
    this.notice,
  });

  factory RagAnswerResponse.fromJson(Map<String, dynamic> json) {
    return RagAnswerResponse(
      query: json['query'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      citations: _mapList(json['citations'], RagCitation.fromJson),
      candidates: _mapList(json['candidates'], RankedChecklist.fromJson),
      mode: json['mode'] as String? ?? 'local',
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      notice: json['notice'] as String?,
    );
  }

  final String query;
  final String answer;
  final List<RagCitation> citations;
  final List<RankedChecklist> candidates;
  final String mode;
  final String? provider;
  final String? model;
  final String? notice;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'answer': answer,
      'citations': citations.map((item) => item.toJson()).toList(),
      'candidates': candidates.map((item) => item.toJson()).toList(),
      'mode': mode,
      'provider': provider,
      'model': model,
      'notice': notice,
    };
  }
}

class ContentManifest {
  ContentManifest({
    this.schemaVersion = 1,
    this.packageId = '',
    this.name = '',
    required this.version,
    required this.checklistCount,
    required this.generatedAt,
    this.team = '',
    this.sourceRevision = '',
    this.defaultLocale = '',
    this.minAppVersion = '',
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    return ContentManifest(
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      packageId: json['packageId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      checklistCount:
          _intValue(json['checklistCount'] ?? json['runbookCount']) ?? 0,
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
      team: json['team'] as String? ?? '',
      sourceRevision: json['sourceRevision'] as String? ?? '',
      defaultLocale: json['defaultLocale'] as String? ?? '',
      minAppVersion: json['minAppVersion'] as String? ?? '',
    );
  }

  final int schemaVersion;
  final String packageId;
  final String name;
  final String version;
  final int checklistCount;
  final int generatedAt;
  final String team;
  final String sourceRevision;
  final String defaultLocale;
  final String minAppVersion;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'packageId': packageId,
      'name': name,
      'version': version,
      'checklistCount': checklistCount,
      'runbookCount': checklistCount,
      'generatedAt': generatedAt,
      'team': team,
      'sourceRevision': sourceRevision,
      'defaultLocale': defaultLocale,
      'minAppVersion': minAppVersion,
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

  Map<String, dynamic> toJson() {
    return {'path': path, 'message': message};
  }
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
  bool get hasWarnings => warnings.isNotEmpty;
  bool get isEmpty => errors.isEmpty && warnings.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'errors': errors.map((item) => item.toJson()).toList(),
      'warnings': warnings.map((item) => item.toJson()).toList(),
    };
  }
}

class ContentBootstrap {
  ContentBootstrap({
    required this.manifest,
    required this.matchingConfig,
    required this.checklists,
    this.validationReport = ContentValidationReport.empty,
  });

  factory ContentBootstrap.fromJson(Map<String, dynamic> json) {
    return ContentBootstrap(
      manifest: ContentManifest.fromJson(_jsonObject(json['manifest'])),
      matchingConfig: MatchingConfig.fromJson(
        _jsonObject(json['matchingConfig']),
      ),
      checklists: _mapList(
        json['checklists'] ?? json['runbooks'],
        Checklist.fromJson,
      ),
      validationReport: json['validation'] is Map
          ? ContentValidationReport.fromJson(_jsonObject(json['validation']))
          : ContentValidationReport.empty,
    );
  }

  final ContentManifest manifest;
  final MatchingConfig matchingConfig;
  final List<Checklist> checklists;
  final ContentValidationReport validationReport;

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      'matchingConfig': matchingConfig.toJson(),
      'checklists': checklists.map((item) => item.toJson()).toList(),
      if (!validationReport.isEmpty) 'validation': validationReport.toJson(),
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

StepRisk _parseStepRisk(Object? value) {
  final normalized = (value as String? ?? '').trim().toLowerCase();
  return switch (normalized) {
    'danger' => StepRisk.danger,
    'destructive' => StepRisk.danger,
    'caution' => StepRisk.caution,
    'warning' => StepRisk.caution,
    _ => StepRisk.safe,
  };
}

String _stepRiskToJson(StepRisk risk) {
  return switch (risk) {
    StepRisk.safe => 'safe',
    StepRisk.caution => 'caution',
    StepRisk.danger => 'danger',
  };
}

String _normalizeSeverity(String? severity) {
  final normalized = (severity ?? '').trim().toLowerCase();
  return switch (normalized) {
    'p1' => 'p1',
    'p2' => 'p2',
    'p3' => 'p3',
    _ => 'p3',
  };
}
