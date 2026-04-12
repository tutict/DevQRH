package com.devqrh.server;

public record ReloadResponse(
        int checklistCount,
        int synonymGroupCount,
        int partialMinLength,
        String checklistSource,
        String matcherConfigSource
) {
}
