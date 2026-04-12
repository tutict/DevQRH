package com.devqrh.core.matcher;

import com.devqrh.core.checklist.Checklist;

public record MatchResult(Checklist checklist, double score) {
}
