package com.devqrh.server;

public record ApiErrorResponse(
        String code,
        String message,
        String path,
        long timestamp
) {
}
