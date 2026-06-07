import '../domain/models.dart';

class OfflineLookupMatcher {
  LookupResponse search({
    required String query,
    required List<Checklist> checklists,
    required MatchingConfig config,
  }) {
    final normalizedQuery = _normalize(query);
    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) {
      return LookupResponse(
        query: query,
        bestMatch: null,
        candidates: const [],
      );
    }

    final runtime = _MatchingRuntime.fromConfig(config);
    final ranked =
        checklists
            .map(
              (checklist) => RankedChecklist(
                checklist: checklist,
                score: _scoreChecklist(
                  normalizedQuery: normalizedQuery,
                  queryTokens: queryTokens,
                  checklist: checklist,
                  runtime: runtime,
                ),
              ),
            )
            .toList()
          ..sort((left, right) {
            final compareScore = right.score.compareTo(left.score);
            if (compareScore != 0) {
              return compareScore;
            }
            return left.checklist.title.compareTo(right.checklist.title);
          });

    final candidates = ranked.take(3).toList();
    return LookupResponse(
      query: query,
      bestMatch: candidates.isEmpty ? null : candidates.first.checklist,
      candidates: candidates,
    );
  }

  double _scoreChecklist({
    required String normalizedQuery,
    required List<String> queryTokens,
    required Checklist checklist,
    required _MatchingRuntime runtime,
  }) {
    final weights = runtime.config.weights;
    final index = _ChecklistIndex.fromChecklist(checklist);

    var total = 0.0;
    for (final token in queryTokens) {
      total += _scoreToken(token: token, index: index, runtime: runtime);
    }

    var score =
        ((total / queryTokens.length) * weights.tokenAverage) +
        (_keywordCoverage(queryTokens, index, runtime) *
            weights.keywordCoverage);

    if (index.normalizedId == normalizedQuery) {
      return _round(_clamp(weights.exactQueryId));
    }

    if (index.normalizedTitle == normalizedQuery) {
      score += weights.exactTitleBoost;
    } else if (index.normalizedTitle.contains(normalizedQuery) ||
        normalizedQuery.contains(index.normalizedTitle)) {
      score += weights.partialTitleBoost;
    }

    if (index.normalizedId.contains(normalizedQuery) ||
        normalizedQuery.contains(index.normalizedId)) {
      score += weights.partialIdBoost;
    }

    if (normalizedQuery.length >= 4 &&
        index.documentText.contains(normalizedQuery)) {
      score += weights.phraseBoost;
    }

    return _round(_clamp(score));
  }

  double _scoreToken({
    required String token,
    required _ChecklistIndex index,
    required _MatchingRuntime runtime,
  }) {
    final weights = runtime.config.weights;
    if (index.idTokens.contains(token)) {
      return weights.exactIdToken;
    }
    if (index.titleTokens.contains(token)) {
      return weights.exactTitleToken;
    }
    if (index.keywordTokens.contains(token)) {
      return weights.exactKeywordToken;
    }
    if (index.symptomTokens.contains(token)) {
      return weights.exactSymptomToken;
    }
    if (index.contextTokens.contains(token)) {
      return weights.exactContextToken;
    }

    final synonyms = runtime.synonymsByToken[token] ?? const <String>{};
    if (synonyms.isNotEmpty) {
      if (_hasOverlap(synonyms, index.keywordTokens)) {
        return weights.synonymKeyword;
      }
      if (_hasOverlap(synonyms, index.primaryTokens)) {
        return weights.synonymPrimary;
      }
      if (_hasOverlap(synonyms, index.allTokens)) {
        return weights.synonymAny;
      }
    }

    if (_hasPartialMatch(
      token,
      index.keywordTokens,
      runtime.config.partialMinLength,
    )) {
      return weights.partialKeyword;
    }
    if (_hasPartialMatch(
      token,
      index.primaryTokens,
      runtime.config.partialMinLength,
    )) {
      return weights.partialPrimary;
    }
    if (_hasPartialMatch(
      token,
      index.allTokens,
      runtime.config.partialMinLength,
    )) {
      return weights.partialAny;
    }

    return 0;
  }

  double _keywordCoverage(
    List<String> queryTokens,
    _ChecklistIndex index,
    _MatchingRuntime runtime,
  ) {
    var matched = 0;
    for (final token in queryTokens) {
      if (index.keywordTokens.contains(token)) {
        matched++;
        continue;
      }

      final synonyms = runtime.synonymsByToken[token] ?? const <String>{};
      if (_hasOverlap(synonyms, index.keywordTokens) ||
          _hasPartialMatch(
            token,
            index.keywordTokens,
            runtime.config.partialMinLength,
          )) {
        matched++;
      }
    }
    return queryTokens.isEmpty ? 0 : matched / queryTokens.length;
  }

  bool _hasOverlap(Set<String> left, Set<String> right) {
    for (final token in left) {
      if (right.contains(token)) {
        return true;
      }
    }
    return false;
  }

  bool _hasPartialMatch(
    String token,
    Set<String> candidates,
    int partialMinLength,
  ) {
    if (token.length < partialMinLength) {
      return false;
    }
    for (final candidate in candidates) {
      if (candidate.length < partialMinLength) {
        continue;
      }
      if (candidate.startsWith(token) ||
          token.startsWith(candidate) ||
          candidate.contains(token) ||
          token.contains(candidate)) {
        return true;
      }
    }
    return false;
  }

  List<String> _tokenize(String input) {
    return _normalize(input)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalize(String input) {
    return input.toLowerCase().trim();
  }

  double _clamp(double value) {
    if (value < 0) {
      return 0;
    }
    return value > 1 ? 1 : value;
  }

  double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class _MatchingRuntime {
  _MatchingRuntime({required this.config, required this.synonymsByToken});

  factory _MatchingRuntime.fromConfig(MatchingConfig config) {
    final synonyms = <String, Set<String>>{};
    for (final group in config.synonymGroups) {
      final normalizedGroup = group
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
      for (final token in normalizedGroup) {
        synonyms[token] = normalizedGroup;
      }
    }
    return _MatchingRuntime(config: config, synonymsByToken: synonyms);
  }

  final MatchingConfig config;
  final Map<String, Set<String>> synonymsByToken;
}

class _ChecklistIndex {
  _ChecklistIndex({
    required this.normalizedId,
    required this.normalizedTitle,
    required this.idTokens,
    required this.titleTokens,
    required this.keywordTokens,
    required this.symptomTokens,
    required this.contextTokens,
    required this.primaryTokens,
    required this.allTokens,
    required this.documentText,
  });

  factory _ChecklistIndex.fromChecklist(Checklist checklist) {
    final idTokens = _tokens(checklist.id);
    final titleTokens = _tokens(checklist.title);
    final keywordTokens = _tokensAll([
      ...checklist.keywords,
      ...checklist.tags,
    ]);
    final symptomTokens = _tokensAll([
      ...checklist.symptoms,
      ...checklist.signals,
    ]);
    final contextTokens = <String>{
      ..._tokens(checklist.summary),
      ..._tokens(checklist.severity),
      ..._tokensAll(checklist.systems),
      ..._tokens(checklist.impact),
      ..._tokens(checklist.owner),
      ..._tokens(checklist.escalation),
      ..._tokensAll(checklist.prerequisites),
      ..._tokensAll(checklist.safeSteps.map((step) => step.action).toList()),
      ..._tokensAll(checklist.cautionSteps.map((step) => step.action).toList()),
      ..._tokensAll(checklist.dangerSteps.map((step) => step.action).toList()),
      ..._tokensAll(checklist.commands.map((item) => item.command).toList()),
      ..._tokensAll(checklist.rootCause),
      ..._tokensAll(checklist.longTermFix),
    };
    final primaryTokens = <String>{
      ...titleTokens,
      ...keywordTokens,
      ...symptomTokens,
    };
    final allTokens = <String>{...idTokens, ...primaryTokens, ...contextTokens};

    return _ChecklistIndex(
      normalizedId: checklist.id.toLowerCase().trim(),
      normalizedTitle: checklist.title.toLowerCase().trim(),
      idTokens: idTokens,
      titleTokens: titleTokens,
      keywordTokens: keywordTokens,
      symptomTokens: symptomTokens,
      contextTokens: contextTokens,
      primaryTokens: primaryTokens,
      allTokens: allTokens,
      documentText: [
        checklist.id,
        checklist.title,
        checklist.summary,
        checklist.severity,
        ...checklist.keywords,
        ...checklist.tags,
        ...checklist.systems,
        ...checklist.symptoms,
        ...checklist.signals,
        checklist.impact,
        checklist.owner,
        checklist.escalation,
        ...checklist.prerequisites,
        ...checklist.safeSteps.map((step) => step.action),
        ...checklist.cautionSteps.map((step) => step.action),
        ...checklist.dangerSteps.map((step) => step.action),
        ...checklist.commands.map((item) => item.command),
        ...checklist.rootCause,
        ...checklist.longTermFix,
      ].join(' ').toLowerCase().trim(),
    );
  }

  final String normalizedId;
  final String normalizedTitle;
  final Set<String> idTokens;
  final Set<String> titleTokens;
  final Set<String> keywordTokens;
  final Set<String> symptomTokens;
  final Set<String> contextTokens;
  final Set<String> primaryTokens;
  final Set<String> allTokens;
  final String documentText;

  static Set<String> _tokens(String value) {
    return value
        .toLowerCase()
        .trim()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static Set<String> _tokensAll(List<String> values) {
    final tokens = <String>{};
    for (final value in values) {
      tokens.addAll(_tokens(value));
    }
    return tokens;
  }
}
