package com.devqrh.core.matcher;

import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;

@Repository
public class MatchingConfigRepository {

    private final MatchingConfigLoader loader;
    private final AtomicReference<MatchingRuntime> runtime;

    public MatchingConfigRepository(MatchingConfigLoader loader) {
        this.loader = loader;
        this.runtime = new AtomicReference<>(toRuntime(loader.loadConfig()));
    }

    public MatchingRuntime current() {
        return runtime.get();
    }

    public MatchingRuntime reload() {
        MatchingRuntime reloaded = toRuntime(loader.loadConfig());
        runtime.set(reloaded);
        return reloaded;
    }

    public String sourceLocation() {
        return loader.sourceLocation();
    }

    private MatchingRuntime toRuntime(MatchingConfig config) {
        return new MatchingRuntime(config, buildSynonymMap(config));
    }

    private Map<String, Set<String>> buildSynonymMap(MatchingConfig config) {
        Map<String, Set<String>> synonyms = new java.util.HashMap<>();
        for (List<String> groupValues : config.getSynonymGroups()) {
            Set<String> group = groupValues.stream()
                    .map(value -> value == null ? "" : value.trim().toLowerCase())
                    .filter(token -> !token.isBlank())
                    .collect(Collectors.toUnmodifiableSet());
            for (String token : group) {
                synonyms.put(token, group);
            }
        }
        return Map.copyOf(synonyms);
    }

    public record MatchingRuntime(MatchingConfig config, Map<String, Set<String>> synonymsByToken) {
    }
}
