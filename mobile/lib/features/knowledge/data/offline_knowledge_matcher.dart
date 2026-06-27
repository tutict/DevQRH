import '../domain/models.dart';

class OfflineKnowledgeMatcher {
  KnowledgeSearchResponse search({
    required String query,
    required List<StudyMaterial> materials,
    required MatchingConfig config,
  }) {
    final normalizedQuery = _normalize(query);
    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) {
      return KnowledgeSearchResponse(
        query: query,
        bestMatch: null,
        candidates: const [],
      );
    }

    final runtime = _MatchingRuntime.fromConfig(config);
    final ranked =
        materials
            .map(
              (material) => RankedKnowledgeItem(
                material: material,
                score: _scoreMaterial(
                  normalizedQuery: normalizedQuery,
                  queryTokens: queryTokens,
                  material: material,
                  runtime: runtime,
                ),
              ),
            )
            .where((item) => item.score >= 0.12)
            .toList()
          ..sort((left, right) {
            final scoreCompare = right.score.compareTo(left.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return left.material.title.compareTo(right.material.title);
          });

    final candidates = ranked.take(5).toList();
    return KnowledgeSearchResponse(
      query: query,
      bestMatch: candidates.isEmpty ? null : candidates.first.material,
      candidates: candidates,
    );
  }

  double _scoreMaterial({
    required String normalizedQuery,
    required List<String> queryTokens,
    required StudyMaterial material,
    required _MatchingRuntime runtime,
  }) {
    final weights = runtime.config.weights;
    final index = _MaterialIndex.fromMaterial(material);
    var total = 0.0;

    for (final token in queryTokens) {
      total += _scoreToken(token: token, index: index, runtime: runtime);
    }

    var score =
        ((total / queryTokens.length) * weights.tokenAverage) +
        (_tagCoverage(queryTokens, index, runtime) * weights.keywordCoverage);

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
    required _MaterialIndex index,
    required _MatchingRuntime runtime,
  }) {
    final weights = runtime.config.weights;
    if (index.idTokens.contains(token)) {
      return weights.exactIdToken;
    }
    if (index.titleTokens.contains(token)) {
      return weights.exactTitleToken;
    }
    if (index.tagTokens.contains(token)) {
      return weights.exactKeywordToken;
    }
    if (index.summaryTokens.contains(token)) {
      return weights.exactSymptomToken;
    }
    if (index.contextTokens.contains(token)) {
      return weights.exactContextToken;
    }

    final synonyms = runtime.synonymsByToken[token] ?? const <String>{};
    if (synonyms.isNotEmpty) {
      if (_hasOverlap(synonyms, index.tagTokens)) {
        return weights.synonymKeyword;
      }
      if (_hasOverlap(synonyms, index.primaryTokens)) {
        return weights.synonymPrimary;
      }
      if (_hasOverlap(synonyms, index.allTokens)) {
        return weights.synonymAny;
      }
    }

    if (_hasPartialMatch(token, index.tagTokens, runtime.config.partialMinLength)) {
      return weights.partialKeyword;
    }
    if (_hasPartialMatch(
      token,
      index.primaryTokens,
      runtime.config.partialMinLength,
    )) {
      return weights.partialPrimary;
    }
    if (_hasPartialMatch(token, index.allTokens, runtime.config.partialMinLength)) {
      return weights.partialAny;
    }
    return 0;
  }

  double _tagCoverage(
    List<String> queryTokens,
    _MaterialIndex index,
    _MatchingRuntime runtime,
  ) {
    var matched = 0;
    for (final token in queryTokens) {
      if (index.tagTokens.contains(token)) {
        matched++;
        continue;
      }
      final synonyms = runtime.synonymsByToken[token] ?? const <String>{};
      if (_hasOverlap(synonyms, index.tagTokens) ||
          _hasPartialMatch(token, index.tagTokens, runtime.config.partialMinLength)) {
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
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'))
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalize(String input) => input.toLowerCase().trim();

  double _clamp(double value) {
    if (value < 0) {
      return 0;
    }
    return value > 1 ? 1 : value;
  }

  double _round(double value) => (value * 100).roundToDouble() / 100;
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

class _MaterialIndex {
  _MaterialIndex({
    required this.normalizedId,
    required this.normalizedTitle,
    required this.idTokens,
    required this.titleTokens,
    required this.tagTokens,
    required this.summaryTokens,
    required this.contextTokens,
    required this.primaryTokens,
    required this.allTokens,
    required this.documentText,
  });

  factory _MaterialIndex.fromMaterial(StudyMaterial material) {
    final idTokens = _tokens(material.id);
    final titleTokens = _tokens(material.title);
    final tagTokens = _tokensAll([...material.tags, material.type.name]);
    final summaryTokens = _tokens(material.summary);
    final contextTokens = _tokensAll([
      material.content,
      material.source,
      ...material.chunks,
    ]);
    final primaryTokens = <String>{
      ...titleTokens,
      ...tagTokens,
      ...summaryTokens,
    };
    final allTokens = <String>{...idTokens, ...primaryTokens, ...contextTokens};

    return _MaterialIndex(
      normalizedId: material.id.toLowerCase().trim(),
      normalizedTitle: material.title.toLowerCase().trim(),
      idTokens: idTokens,
      titleTokens: titleTokens,
      tagTokens: tagTokens,
      summaryTokens: summaryTokens,
      contextTokens: contextTokens,
      primaryTokens: primaryTokens,
      allTokens: allTokens,
      documentText: material.searchableText.toLowerCase().trim(),
    );
  }

  final String normalizedId;
  final String normalizedTitle;
  final Set<String> idTokens;
  final Set<String> titleTokens;
  final Set<String> tagTokens;
  final Set<String> summaryTokens;
  final Set<String> contextTokens;
  final Set<String> primaryTokens;
  final Set<String> allTokens;
  final String documentText;

  static Set<String> _tokens(String value) {
    return value
        .toLowerCase()
        .trim()
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'))
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
