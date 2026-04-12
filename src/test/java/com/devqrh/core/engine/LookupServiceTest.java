package com.devqrh.core.engine;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = WebEnvironment.NONE)
class LookupServiceTest {

    @Autowired
    private LookupService lookupService;

    @Test
    void findsCpuChecklist() {
        LookupResult result = lookupService.lookup("CPU 100%", 3);
        assertThat(result.bestMatch()).isNotNull();
        assertThat(result.bestMatch().getId()).isEqualTo("cpu_100");
        assertThat(result.candidates().get(0).score()).isEqualTo(1.0);
    }

    @Test
    void returnsRankedCandidatesWithScores() {
        LookupResult result = lookupService.lookup("service lag", 3);
        assertThat(result.candidates()).hasSize(3);
        assertThat(result.candidates())
                .extracting(match -> match.checklist().getId())
                .containsExactlyInAnyOrder("cpu_100", "mysql_slow", "io_bottleneck");
        assertThat(result.candidates())
                .extracting(match -> match.score())
                .allMatch(score -> score >= 0.0 && score <= 1.0);
        assertThat(result.candidates().get(0).score()).isGreaterThanOrEqualTo(result.candidates().get(1).score());
        assertThat(result.candidates().get(1).score()).isGreaterThanOrEqualTo(result.candidates().get(2).score());
    }

    @Test
    void supportsSynonymAndPartialMatch() {
        LookupResult synonymResult = lookupService.lookup("timeout query", 3);
        assertThat(synonymResult.bestMatch()).isNotNull();
        assertThat(synonymResult.bestMatch().getId()).isEqualTo("mysql_slow");

        LookupResult partialResult = lookupService.lookup("mys lat", 3);
        assertThat(partialResult.bestMatch()).isNotNull();
        assertThat(partialResult.bestMatch().getId()).isEqualTo("mysql_slow");

        LookupResult externalizedSynonymResult = lookupService.lookup("sluggish api", 3);
        assertThat(externalizedSynonymResult.candidates()).isNotEmpty();
        assertThat(externalizedSynonymResult.candidates().get(0).score()).isGreaterThan(0.0);
    }
}
