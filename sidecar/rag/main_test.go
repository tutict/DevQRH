package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
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
