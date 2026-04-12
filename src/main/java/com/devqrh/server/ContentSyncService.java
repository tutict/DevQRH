package com.devqrh.server;

import com.devqrh.core.checklist.Checklist;
import com.devqrh.core.checklist.ChecklistRepository;
import com.devqrh.core.matcher.MatchingConfig;
import com.devqrh.core.matcher.MatchingConfigRepository;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ContentSyncService {

    private final ChecklistRepository checklistRepository;
    private final MatchingConfigRepository matchingConfigRepository;

    public ContentSyncService(ChecklistRepository checklistRepository, MatchingConfigRepository matchingConfigRepository) {
        this.checklistRepository = checklistRepository;
        this.matchingConfigRepository = matchingConfigRepository;
    }

    public ContentManifestResponse manifest() {
        List<Checklist> checklists = checklistRepository.findAll();
        MatchingConfig matchingConfig = matchingConfigRepository.current().config();
        return new ContentManifestResponse(
                buildVersion(checklists, matchingConfig),
                checklists.size(),
                System.currentTimeMillis()
        );
    }

    public ContentBootstrapResponse bootstrap() {
        List<Checklist> checklists = checklistRepository.findAll();
        MatchingConfig matchingConfig = matchingConfigRepository.current().config();
        return new ContentBootstrapResponse(
                new ContentManifestResponse(
                        buildVersion(checklists, matchingConfig),
                        checklists.size(),
                        System.currentTimeMillis()
                ),
                matchingConfig,
                checklists
        );
    }

    private String buildVersion(List<Checklist> checklists, MatchingConfig matchingConfig) {
        String materialized = checklists.stream()
                .map(this::serializeChecklist)
                .collect(Collectors.joining("\n"))
                + "\n" + serializeConfig(matchingConfig);
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(materialized.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }

    private String serializeChecklist(Checklist checklist) {
        return String.join("|",
                checklist.getId(),
                checklist.getTitle(),
                String.join(",", checklist.getKeywords()),
                String.join(",", checklist.getSymptoms()),
                checklist.getImmediateActions().stream()
                        .map(step -> step.getStep() + ":" + step.getAction())
                        .collect(Collectors.joining(",")),
                checklist.getDecisionTree().stream()
                        .map(branch -> branch.getCondition() + ":" + branch.getAction())
                        .collect(Collectors.joining(",")),
                String.join(",", checklist.getRootCause()),
                String.join(",", checklist.getLongTermFix())
        );
    }

    private String serializeConfig(MatchingConfig matchingConfig) {
        return String.join("|",
                Integer.toString(matchingConfig.getPartialMinLength()),
                matchingConfig.getSynonymGroups().stream()
                        .map(group -> String.join(",", group))
                        .collect(Collectors.joining(";")),
                Double.toString(matchingConfig.getWeights().getExactQueryId()),
                Double.toString(matchingConfig.getWeights().getExactIdToken()),
                Double.toString(matchingConfig.getWeights().getExactTitleToken()),
                Double.toString(matchingConfig.getWeights().getExactKeywordToken()),
                Double.toString(matchingConfig.getWeights().getExactSymptomToken()),
                Double.toString(matchingConfig.getWeights().getExactContextToken()),
                Double.toString(matchingConfig.getWeights().getSynonymKeyword()),
                Double.toString(matchingConfig.getWeights().getSynonymPrimary()),
                Double.toString(matchingConfig.getWeights().getSynonymAny()),
                Double.toString(matchingConfig.getWeights().getPartialKeyword()),
                Double.toString(matchingConfig.getWeights().getPartialPrimary()),
                Double.toString(matchingConfig.getWeights().getPartialAny()),
                Double.toString(matchingConfig.getWeights().getTokenAverage()),
                Double.toString(matchingConfig.getWeights().getKeywordCoverage()),
                Double.toString(matchingConfig.getWeights().getExactTitleBoost()),
                Double.toString(matchingConfig.getWeights().getPartialTitleBoost()),
                Double.toString(matchingConfig.getWeights().getPartialIdBoost()),
                Double.toString(matchingConfig.getWeights().getPhraseBoost())
        );
    }
}
