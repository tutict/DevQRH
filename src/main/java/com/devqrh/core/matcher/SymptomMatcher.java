package com.devqrh.core.matcher;

import com.devqrh.core.checklist.Checklist;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Component
public class SymptomMatcher {

    private static final Pattern SPLIT_PATTERN = Pattern.compile("[^a-z0-9]+");

    private final MatchingConfigRepository configRepository;

    public SymptomMatcher(MatchingConfigRepository configRepository) {
        this.configRepository = configRepository;
    }

    public List<MatchResult> match(String query, List<Checklist> checklists, int limit) {
        MatchingConfigRepository.MatchingRuntime runtime = configRepository.current();
        MatchingConfig config = runtime.config();
        List<String> queryTokens = tokenize(query);
        if (queryTokens.isEmpty()) {
            return List.of();
        }

        List<MatchResult> results = new ArrayList<>();
        for (Checklist checklist : checklists) {
            double score = scoreChecklist(normalize(query), queryTokens, buildIndex(checklist), runtime, config);
            results.add(new MatchResult(checklist, score));
        }

        results.sort(Comparator.comparingDouble(MatchResult::score).reversed()
                .thenComparing(match -> match.checklist().getTitle()));

        return results.stream()
                .limit(Math.max(1, limit))
                .collect(Collectors.toList());
    }

    private double scoreChecklist(String normalizedQuery,
                                  List<String> queryTokens,
                                  ChecklistIndex checklistIndex,
                                  MatchingConfigRepository.MatchingRuntime runtime,
                                  MatchingConfig config) {
        MatchingConfig.Weights weights = config.getWeights();
        double total = 0;
        for (String queryToken : queryTokens) {
            total += scoreToken(queryToken, checklistIndex, runtime, config);
        }

        double tokenAverage = total / queryTokens.size();
        double score = (tokenAverage * weights.getTokenAverage())
                + (keywordCoverage(queryTokens, checklistIndex, runtime) * weights.getKeywordCoverage());
        if (checklistIndex.normalizedId().equals(normalizedQuery)) {
            return round(clamp(weights.getExactQueryId()));
        }

        if (checklistIndex.normalizedTitle().equals(normalizedQuery)) {
            score += weights.getExactTitleBoost();
        } else if (checklistIndex.normalizedTitle().contains(normalizedQuery) || normalizedQuery.contains(checklistIndex.normalizedTitle())) {
            score += weights.getPartialTitleBoost();
        }

        if (checklistIndex.normalizedId().contains(normalizedQuery) || normalizedQuery.contains(checklistIndex.normalizedId())) {
            score += weights.getPartialIdBoost();
        }

        if (normalizedQuery.length() >= 4 && checklistIndex.documentText().contains(normalizedQuery)) {
            score += weights.getPhraseBoost();
        }

        return round(clamp(score));
    }

    private double scoreToken(String token,
                              ChecklistIndex checklistIndex,
                              MatchingConfigRepository.MatchingRuntime runtime,
                              MatchingConfig config) {
        MatchingConfig.Weights weights = config.getWeights();
        if (checklistIndex.idTokens().contains(token)) {
            return weights.getExactIdToken();
        }
        if (checklistIndex.titleTokens().contains(token)) {
            return weights.getExactTitleToken();
        }
        if (checklistIndex.keywordTokens().contains(token)) {
            return weights.getExactKeywordToken();
        }
        if (checklistIndex.symptomTokens().contains(token)) {
            return weights.getExactSymptomToken();
        }
        if (checklistIndex.contextTokens().contains(token)) {
            return weights.getExactContextToken();
        }

        Set<String> synonyms = runtime.synonymsByToken().getOrDefault(token, Set.of());
        if (!synonyms.isEmpty()) {
            if (hasOverlap(synonyms, checklistIndex.keywordTokens())) {
                return weights.getSynonymKeyword();
            }
            if (hasOverlap(synonyms, checklistIndex.primaryTokens())) {
                return weights.getSynonymPrimary();
            }
            if (hasOverlap(synonyms, checklistIndex.allTokens())) {
                return weights.getSynonymAny();
            }
        }

        if (hasPartialMatch(token, checklistIndex.keywordTokens())) {
            return weights.getPartialKeyword();
        }
        if (hasPartialMatch(token, checklistIndex.primaryTokens())) {
            return weights.getPartialPrimary();
        }
        if (hasPartialMatch(token, checklistIndex.allTokens())) {
            return weights.getPartialAny();
        }

        return 0;
    }

    private double keywordCoverage(List<String> queryTokens,
                                   ChecklistIndex checklistIndex,
                                   MatchingConfigRepository.MatchingRuntime runtime) {
        int matched = 0;
        for (String token : queryTokens) {
            if (checklistIndex.keywordTokens().contains(token)) {
                matched++;
                continue;
            }
            Set<String> synonyms = runtime.synonymsByToken().getOrDefault(token, Set.of());
            if (hasOverlap(synonyms, checklistIndex.keywordTokens()) || hasPartialMatch(token, checklistIndex.keywordTokens(), runtime.config())) {
                matched++;
            }
        }
        return queryTokens.isEmpty() ? 0 : (double) matched / queryTokens.size();
    }

    private ChecklistIndex buildIndex(Checklist checklist) {
        Set<String> idTokens = new HashSet<>(tokenize(checklist.getId()));
        Set<String> titleTokens = new HashSet<>(tokenize(checklist.getTitle()));
        Set<String> keywordTokens = tokenizeAll(checklist.getKeywords());
        Set<String> symptomTokens = tokenizeAll(checklist.getSymptoms());
        Set<String> contextTokens = new HashSet<>();
        contextTokens.addAll(tokenizeAll(checklist.getRootCause()));
        contextTokens.addAll(tokenizeAll(checklist.getLongTermFix()));

        Set<String> primaryTokens = new HashSet<>();
        primaryTokens.addAll(titleTokens);
        primaryTokens.addAll(keywordTokens);
        primaryTokens.addAll(symptomTokens);

        Set<String> allTokens = new HashSet<>();
        allTokens.addAll(idTokens);
        allTokens.addAll(primaryTokens);
        allTokens.addAll(contextTokens);

        String documentText = normalize(String.join(" ",
                checklist.getId(),
                checklist.getTitle(),
                String.join(" ", checklist.getKeywords()),
                String.join(" ", checklist.getSymptoms()),
                String.join(" ", checklist.getRootCause()),
                String.join(" ", checklist.getLongTermFix())));

        return new ChecklistIndex(
                normalize(checklist.getId()),
                normalize(checklist.getTitle()),
                idTokens,
                titleTokens,
                keywordTokens,
                symptomTokens,
                contextTokens,
                primaryTokens,
                allTokens,
                documentText
        );
    }

    private Set<String> tokenizeAll(List<String> values) {
        Set<String> tokens = new HashSet<>();
        for (String value : values) {
            tokens.addAll(tokenize(value));
        }
        return tokens;
    }

    private boolean hasOverlap(Set<String> left, Set<String> right) {
        if (left.isEmpty() || right.isEmpty()) {
            return false;
        }
        for (String token : left) {
            if (right.contains(token)) {
                return true;
            }
        }
        return false;
    }

    private boolean hasPartialMatch(String token, Set<String> candidates) {
        return hasPartialMatch(token, candidates, configRepository.current().config());
    }

    private boolean hasPartialMatch(String token, Set<String> candidates, MatchingConfig config) {
        if (token.length() < config.getPartialMinLength()) {
            return false;
        }
        for (String candidate : candidates) {
            if (candidate.length() < config.getPartialMinLength()) {
                continue;
            }
            if (candidate.startsWith(token) || token.startsWith(candidate)) {
                return true;
            }
            if (candidate.contains(token) || token.contains(candidate)) {
                return true;
            }
        }
        return false;
    }

    private double clamp(double value) {
        if (value < 0) {
            return 0;
        }
        return Math.min(value, 1.0);
    }

    private double round(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    private List<String> tokenize(String input) {
        return List.of(SPLIT_PATTERN.split(normalize(input))).stream()
                .filter(token -> !token.isBlank())
                .distinct()
                .toList();
    }

    private String normalize(String input) {
        return input == null ? "" : input.toLowerCase(Locale.ROOT).trim();
    }

    private record ChecklistIndex(
            String normalizedId,
            String normalizedTitle,
            Set<String> idTokens,
            Set<String> titleTokens,
            Set<String> keywordTokens,
            Set<String> symptomTokens,
            Set<String> contextTokens,
            Set<String> primaryTokens,
            Set<String> allTokens,
            String documentText
    ) {
    }
}
