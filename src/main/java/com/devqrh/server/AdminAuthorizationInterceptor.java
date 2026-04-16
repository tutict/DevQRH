package com.devqrh.server;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class AdminAuthorizationInterceptor implements HandlerInterceptor {

    private static final String ADMIN_TOKEN_HEADER = "X-Admin-Token";
    private static final String BEARER_PREFIX = "Bearer ";

    private final boolean requireToken;
    private final String configuredToken;

    public AdminAuthorizationInterceptor(@Value("${devqrh.admin.reload.require-token:false}") boolean requireToken,
                                         @Value("${devqrh.admin.reload.token:}") String configuredToken) {
        this.requireToken = requireToken;
        this.configuredToken = configuredToken == null ? "" : configuredToken.trim();
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (!requireToken) {
            return true;
        }

        if (configuredToken.isBlank()) {
            throw new ApiRequestException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "admin_unavailable",
                    "Admin reload is not available"
            );
        }

        String presentedToken = resolvePresentedToken(request);
        if (!configuredToken.equals(presentedToken)) {
            throw new ApiRequestException(
                    HttpStatus.UNAUTHORIZED,
                    "unauthorized",
                    "Admin token required"
            );
        }
        return true;
    }

    private String resolvePresentedToken(HttpServletRequest request) {
        String headerToken = request.getHeader(ADMIN_TOKEN_HEADER);
        if (headerToken != null && !headerToken.isBlank()) {
            return headerToken.trim();
        }

        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization != null && authorization.startsWith(BEARER_PREFIX)) {
            return authorization.substring(BEARER_PREFIX.length()).trim();
        }
        return "";
    }
}
