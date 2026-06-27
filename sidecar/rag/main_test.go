package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestBuildRAGAnswerUsesRetrievedRunbook(t *testing.T) {
	answer := buildLocalRAGAnswer("cpu spike", sampleCandidates())

	for _, expected := range []string{
		"CPU 100%",
		"Immediate checks",
		"top",
		"bad code",
	} {
		if !strings.Contains(answer, expected) {
			t.Fatalf("expected answer to contain %q, got %q", expected, answer)
		}
	}
}

func TestContentSyncAndVersionedLookup(t *testing.T) {
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/content/sync", app.contentSync)
	mux.HandleFunc("/lookup", app.lookup)
	mux.HandleFunc("/metrics", app.metricsHandler)
	server := httptest.NewServer(mux)
	defer server.Close()

	syncResponse := postJSON[contentSyncResponse](t, server.URL+"/content/sync", contentSyncRequest{
		Bootstrap: sampleBootstrap(),
	}, http.StatusOK)
	if syncResponse.ContentVersion == "" {
		t.Fatal("expected content version")
	}
	if syncResponse.ChecklistCount != 2 {
		t.Fatalf("unexpected checklist count: %d", syncResponse.ChecklistCount)
	}
	if len(syncResponse.Validation.Warnings) == 0 {
		t.Fatal("expected validation warnings for legacy sample metadata")
	}

	lookup := postJSON[LookupResponse](t, server.URL+"/lookup", lookupRequest{
		Query:          "cpu spike",
		ContentVersion: syncResponse.ContentVersion,
	}, http.StatusOK)
	if lookup.BestMatch == nil || lookup.BestMatch.ID != "cpu_100" {
		t.Fatalf("unexpected lookup response: %+v", lookup)
	}

	metrics := postRaw[map[string]any](t, http.MethodGet, server.URL+"/metrics", nil, http.StatusOK)
	if metrics["contentVersion"] != syncResponse.ContentVersion {
		t.Fatalf("metrics did not expose content version: %+v", metrics)
	}
}

func TestLookupRejectsMissingAndUnknownContent(t *testing.T) {
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/lookup", app.lookup)
	server := httptest.NewServer(mux)
	defer server.Close()

	postJSON[map[string]string](t, server.URL+"/lookup", lookupRequest{
		Query: "cpu",
	}, http.StatusBadRequest)

	postJSON[map[string]string](t, server.URL+"/lookup", lookupRequest{
		Query:          "cpu",
		ContentVersion: "missing",
	}, http.StatusConflict)
}

func TestContentSyncRejectsInvalidBootstrap(t *testing.T) {
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/content/sync", app.contentSync)
	server := httptest.NewServer(mux)
	defer server.Close()

	invalid := sampleBootstrap()
	invalid.Manifest.ChecklistCount = 99
	response := postJSON[errorPayload](t, server.URL+"/content/sync", contentSyncRequest{
		Bootstrap: invalid,
	}, http.StatusBadRequest)
	if len(response.Validation.Errors) == 0 {
		t.Fatalf("expected validation errors, got %+v", response)
	}
}

func TestContentSyncRejectsInvalidStepRisk(t *testing.T) {
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/content/sync", app.contentSync)
	server := httptest.NewServer(mux)
	defer server.Close()

	invalid := sampleBootstrap()
	invalid.Checklists[0].SafeSteps = []ChecklistStep{
		{Step: 1, Action: "inspect host", Risk: "reckless"},
	}

	response := postJSON[errorPayload](t, server.URL+"/content/sync", contentSyncRequest{
		Bootstrap: invalid,
	}, http.StatusBadRequest)
	if len(response.Validation.Errors) == 0 ||
		!strings.Contains(response.Validation.Errors[0].Message, "invalid step risk") {
		t.Fatalf("expected invalid step risk error, got %+v", response)
	}
}

func TestUnknownQueryDoesNotReturnBestMatch(t *testing.T) {
	response := search("zzzz-not-in-book", sampleBootstrap())
	if response.BestMatch != nil {
		t.Fatalf("expected no best match, got %+v", response.BestMatch)
	}
	if len(response.Candidates) != 0 {
		t.Fatalf("expected no candidates, got %+v", response.Candidates)
	}
}

func TestGenerateRAGAnswerUsesOpenAICompatibleProvider(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer test-key" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var request chatCompletionRequest
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if request.Model != "test-model" {
			t.Fatalf("unexpected model: %s", request.Model)
		}
		if !strings.Contains(request.Messages[1].Content, "CPU 100%") {
			t.Fatalf("prompt did not include retrieved context: %s", request.Messages[1].Content)
		}

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"Use CPU 100% runbook. Source: cpu_100."}}]}`))
	}))
	defer server.Close()

	t.Setenv("DEVQRH_LLM_API_KEY", "test-key")
	t.Setenv("DEVQRH_LLM_MODEL", "test-model")
	t.Setenv("DEVQRH_LLM_BASE_URL", server.URL+"/v1")

	answer := generateRAGAnswer(t.Context(), "cpu spike", sampleCandidates())
	if answer.Mode != "llm" {
		t.Fatalf("expected llm mode, got %+v", answer)
	}
	if answer.Provider != "openai-compatible" || answer.Model != "test-model" {
		t.Fatalf("unexpected provider metadata: %+v", answer)
	}
	if !strings.Contains(answer.Answer, "CPU 100%") {
		t.Fatalf("unexpected answer: %s", answer.Answer)
	}
}

func sampleCandidates() []RankedChecklist {
	return []RankedChecklist{
		{
			Checklist: Checklist{
				ID:       "cpu_100",
				Title:    "CPU 100%",
				Symptoms: []string{"high CPU", "service slow"},
				ImmediateActions: []ChecklistStep{
					{Step: 1, Action: "top"},
					{Step: 2, Action: "top -Hp {pid}"},
				},
				DecisionTree: []ChecklistBranch{
					{Condition: "high GC", Action: "analyze heap dump"},
				},
				RootCause:   []string{"bad code"},
				LongTermFix: []string{"optimize hot path"},
			},
			Score: 0.88,
		},
	}
}

type errorPayload struct {
	Error      string           `json:"error"`
	Validation ValidationReport `json:"validation"`
}

func sampleBootstrap() ContentBootstrap {
	return ContentBootstrap{
		Manifest: ContentManifest{
			Version:        "test",
			ChecklistCount: 2,
			GeneratedAt:    1,
		},
		MatchingConfig: MatchingConfig{
			PartialMinLength: 3,
			SynonymGroups: [][]string{
				{"cpu", "load", "spike"},
				{"slow", "lag", "latency"},
			},
			Weights: defaultWeights(),
		},
		Checklists: []Checklist{
			{
				ID:       "cpu_100",
				Title:    "CPU 100%",
				Keywords: []string{"cpu", "load", "hot thread"},
				Symptoms: []string{"high CPU", "service slow"},
				ImmediateActions: []ChecklistStep{
					{Step: 1, Action: "top"},
				},
				RootCause:   []string{"bad code"},
				LongTermFix: []string{"optimize hot path"},
			},
			{
				ID:       "mysql_slow",
				Title:    "MySQL Slow Query",
				Keywords: []string{"mysql", "db", "query"},
				Symptoms: []string{"query latency high"},
				ImmediateActions: []ChecklistStep{
					{Step: 1, Action: "show processlist"},
				},
				RootCause:   []string{"missing index"},
				LongTermFix: []string{"add index review"},
			},
		},
	}
}

func postJSON[T any](t *testing.T, url string, payload any, expectedStatus int) T {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	return postRaw[T](t, http.MethodPost, url, body, expectedStatus)
}

func postRaw[T any](t *testing.T, method string, url string, body []byte, expectedStatus int) T {
	t.Helper()
	var reader *bytes.Reader
	if body == nil {
		reader = bytes.NewReader(nil)
	} else {
		reader = bytes.NewReader(body)
	}
	request, err := http.NewRequest(method, url, reader)
	if err != nil {
		t.Fatalf("create request: %v", err)
	}
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}

	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatalf("send request: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != expectedStatus {
		t.Fatalf("expected status %d, got %d", expectedStatus, response.StatusCode)
	}

	var decoded T
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}

func TestLearningBundleSyncLookupAnswerAndReview(t *testing.T) {
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/content/sync", app.contentSync)
	mux.HandleFunc("/lookup", app.lookup)
	mux.HandleFunc("/rag/answer", app.ragAnswer)
	mux.HandleFunc("/review/schedule", app.reviewSchedule)
	server := httptest.NewServer(mux)
	defer server.Close()

	syncResponse := postJSON[contentSyncResponse](t, server.URL+"/content/sync", contentSyncRequest{
		Bundle: sampleLearningBundlePtr(),
	}, http.StatusOK)
	if syncResponse.ContentVersion == "" {
		t.Fatal("expected learning content version")
	}
	if syncResponse.MaterialCount != 2 || syncResponse.CardCount != 1 {
		t.Fatalf("unexpected learning counts: %+v", syncResponse)
	}

	lookup := postJSON[KnowledgeSearchResponse](t, server.URL+"/lookup", lookupRequest{
		Query:          "api retry idempotency",
		ContentVersion: syncResponse.ContentVersion,
	}, http.StatusOK)
	if lookup.BestMatch == nil || lookup.BestMatch.ID != "api_retry" {
		t.Fatalf("unexpected learning lookup: %+v", lookup)
	}

	answer := postJSON[learningAnswerResponse](t, server.URL+"/rag/answer", lookupRequest{
		Query:          "api retry idempotency",
		ContentVersion: syncResponse.ContentVersion,
	}, http.StatusOK)
	if len(answer.Citations) == 0 || !strings.Contains(answer.Answer, "API Retry") {
		t.Fatalf("expected grounded learning answer, got %+v", answer)
	}

	review := postJSON[ReviewResult](t, server.URL+"/review/schedule", reviewScheduleRequest{
		Grade: "good",
		Now:   time.Date(2026, 6, 27, 12, 0, 0, 0, time.UTC).UnixMilli(),
		State: ReviewState{CardID: "card_retry", EaseFactor: 2.5},
	}, http.StatusOK)
	if review.UpdatedState.IntervalDays != 1 || review.NextDueAt <= 0 {
		t.Fatalf("unexpected review result: %+v", review)
	}
}

func TestLearningCardsGenerateRequiresConfiguredLLM(t *testing.T) {
	t.Setenv("DEVQRH_LLM_API_KEY", "")
	app := newServer()
	mux := http.NewServeMux()
	mux.HandleFunc("/content/sync", app.contentSync)
	mux.HandleFunc("/cards/generate", app.cardsGenerate)
	server := httptest.NewServer(mux)
	defer server.Close()

	syncResponse := postJSON[contentSyncResponse](t, server.URL+"/content/sync", contentSyncRequest{
		Bundle: sampleLearningBundlePtr(),
	}, http.StatusOK)

	postJSON[errorPayload](t, server.URL+"/cards/generate", cardsGenerateRequest{
		ContentVersion: syncResponse.ContentVersion,
		MaterialIDs:    []string{"api_retry"},
		Limit:          2,
	}, http.StatusServiceUnavailable)
}

func sampleLearningBundlePtr() *LearningBundle {
	bundle := sampleLearningBundle()
	return &bundle
}

func sampleLearningBundle() LearningBundle {
	return LearningBundle{
		Manifest: LearningManifest{
			SchemaVersion: 1,
			PackageID:     "test.learning",
			Name:          "Test Learning",
			Version:       "test-learning",
			GeneratedAt:   1,
			DefaultLocale: "en-US",
			SourceType:    "test",
		},
		MatchingConfig: MatchingConfig{
			PartialMinLength: 2,
			SynonymGroups: [][]string{
				{"api", "service"},
				{"retry", "idempotency"},
			},
			Weights: defaultWeights(),
		},
		Materials: []StudyMaterial{
			{
				ID:      "api_retry",
				Title:   "API Retry Strategy",
				Type:    "engineering",
				Tags:    []string{"api", "retry", "idempotency"},
				Summary: "Retries should be bounded and idempotent.",
				Content: "Retry only idempotent operations or requests with an idempotency key. Use backoff with jitter.",
				Chunks:  []string{"Retry only idempotent operations.", "Use backoff with jitter."},
			},
			{
				ID:      "english_context",
				Title:   "Infer Vocabulary From Context",
				Type:    "exam",
				Tags:    []string{"english", "vocabulary"},
				Summary: "Use contrast and examples to infer word meaning.",
				Content: "Contrast markers and examples help infer unknown words.",
			},
		},
		Decks: []StudyDeck{
			{ID: "engineering", Title: "Engineering", CardIDs: []string{"card_retry"}},
		},
		Cards: []StudyCard{
			{
				ID:                "card_retry",
				DeckID:            "engineering",
				Front:             "When is retry safe?",
				Back:              "When the operation is idempotent or has an idempotency key.",
				SourceMaterialIDs: []string{"api_retry"},
			},
		},
	}
}
