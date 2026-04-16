package com.devqrh.server;

import com.devqrh.core.checklist.ChecklistRepository;
import com.devqrh.core.matcher.MatchingConfigRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class HealthController {

    private final ChecklistRepository checklistRepository;
    private final MatchingConfigRepository matchingConfigRepository;
    private final boolean includeSourceLocations;

    public HealthController(ChecklistRepository checklistRepository,
                            MatchingConfigRepository matchingConfigRepository,
                            @Value("${devqrh.health.include-source-locations:true}") boolean includeSourceLocations) {
        this.checklistRepository = checklistRepository;
        this.matchingConfigRepository = matchingConfigRepository;
        this.includeSourceLocations = includeSourceLocations;
    }

    @GetMapping("/health")
    public HealthResponse health() {
        MatchingConfigRepository.MatchingRuntime runtime = matchingConfigRepository.current();
        return new HealthResponse(
                "ok",
                checklistRepository.findAll().size(),
                runtime.config().getSynonymGroups().size(),
                runtime.config().getPartialMinLength(),
                includeSourceLocations ? checklistRepository.sourceLocation() : null,
                includeSourceLocations ? matchingConfigRepository.sourceLocation() : null,
                System.currentTimeMillis()
        );
    }
}
