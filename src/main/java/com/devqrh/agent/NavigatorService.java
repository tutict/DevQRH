package com.devqrh.agent;

import com.devqrh.core.engine.LookupResult;
import com.devqrh.core.engine.LookupService;
import com.devqrh.core.matcher.MatchResult;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NavigatorService {

    private final LookupService lookupService;

    public NavigatorService(LookupService lookupService) {
        this.lookupService = lookupService;
    }

    public NavigatorResponse navigate(String query) {
        LookupResult result = lookupService.lookup(query, 3);
        MatchResult best = result.candidates().isEmpty() ? null : result.candidates().get(0);
        List<String> clarifiers = result.candidates().stream()
                .flatMap(candidate -> candidate.checklist().getSymptoms().stream())
                .distinct()
                .filter(symptom -> !symptom.equalsIgnoreCase(result.query()))
                .limit(3)
                .map(symptom -> "check: " + symptom)
                .toList();

        return new NavigatorResponse(result.query(), best, result.candidates(), clarifiers);
    }
}
