package com.devqrh.core.engine;

import com.devqrh.core.checklist.Checklist;
import com.devqrh.core.matcher.MatchResult;

import java.util.List;

public record LookupResult(String query, Checklist bestMatch, List<MatchResult> candidates) {
}
