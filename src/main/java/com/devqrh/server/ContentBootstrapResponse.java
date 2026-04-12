package com.devqrh.server;

import com.devqrh.core.checklist.Checklist;
import com.devqrh.core.matcher.MatchingConfig;

import java.util.List;

public record ContentBootstrapResponse(
        ContentManifestResponse manifest,
        MatchingConfig matchingConfig,
        List<Checklist> checklists
) {
}
