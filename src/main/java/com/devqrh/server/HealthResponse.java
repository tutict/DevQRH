package com.devqrh.server;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record HealthResponse(
        String status,
        int checklistCount,
        int synonymGroupCount,
        int partialMinLength,
        String checklistSource,
        String matcherConfigSource,
        long timestamp
) {
}
