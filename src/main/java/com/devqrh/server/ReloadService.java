package com.devqrh.server;

import com.devqrh.core.checklist.ChecklistRepository;
import com.devqrh.core.matcher.MatchingConfigRepository;
import org.springframework.stereotype.Service;

@Service
public class ReloadService {

    private final ChecklistRepository checklistRepository;
    private final MatchingConfigRepository matchingConfigRepository;

    public ReloadService(ChecklistRepository checklistRepository, MatchingConfigRepository matchingConfigRepository) {
        this.checklistRepository = checklistRepository;
        this.matchingConfigRepository = matchingConfigRepository;
    }

    public ReloadResponse reload() {
        int checklistCount = checklistRepository.reload();
        MatchingConfigRepository.MatchingRuntime runtime = matchingConfigRepository.reload();
        return new ReloadResponse(
                checklistCount,
                runtime.config().getSynonymGroups().size(),
                runtime.config().getPartialMinLength(),
                checklistRepository.sourceLocation(),
                matchingConfigRepository.sourceLocation()
        );
    }
}
