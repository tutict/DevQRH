package com.devqrh.agent;

import com.devqrh.core.matcher.MatchResult;

import java.util.List;

public record NavigatorResponse(String query, MatchResult bestMatch, List<MatchResult> candidates, List<String> clarifiers) {
}
