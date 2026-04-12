package com.devqrh.server;

public record ContentManifestResponse(
        String version,
        int checklistCount,
        long generatedAt
) {
}
