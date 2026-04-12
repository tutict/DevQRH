package com.devqrh.core.engine;

import com.devqrh.core.checklist.Checklist;
import com.devqrh.core.checklist.ChecklistRepository;
import com.devqrh.core.matcher.MatchResult;
import com.devqrh.core.matcher.SymptomMatcher;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LookupService {

    private final ChecklistRepository repository;
    private final SymptomMatcher matcher;

    public LookupService(ChecklistRepository repository, SymptomMatcher matcher) {
        this.repository = repository;
        this.matcher = matcher;
    }

    public LookupResult lookup(String query, int limit) {
        String sanitized = query == null ? "" : query.trim();
        if (sanitized.isBlank()) {
            return new LookupResult("", null, List.of());
        }

        List<MatchResult> candidates = matcher.match(sanitized, repository.findAll(), limit);
        Checklist best = candidates.isEmpty() ? null : candidates.get(0).checklist();
        return new LookupResult(sanitized, best, candidates);
    }

    public Checklist getChecklist(String id) {
        return repository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Checklist not found: " + id));
    }
}
