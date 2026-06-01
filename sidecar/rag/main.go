package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type ChecklistStep struct {
	Step   int    `json:"step"`
	Action string `json:"action"`
}

type ChecklistBranch struct {
	Condition string `json:"condition"`
	Action    string `json:"action"`
}

type Checklist struct {
	ID               string            `json:"id"`
	Title            string            `json:"title"`
	Keywords         []string          `json:"keywords"`
	Symptoms         []string          `json:"symptoms"`
	ImmediateActions []ChecklistStep   `json:"immediateActions"`
	DecisionTree     []ChecklistBranch `json:"decisionTree"`
	RootCause        []string          `json:"rootCause"`
	LongTermFix      []string          `json:"longTermFix"`
}

type RankedChecklist struct {
	Checklist Checklist `json:"checklist"`
	Score     float64   `json:"score"`
}

type LookupResponse struct {
	Query      string            `json:"query"`
	BestMatch  *Checklist        `json:"bestMatch"`
	Candidates []RankedChecklist `json:"candidates"`
}

type AgentNavigationResponse struct {
	Query      string            `json:"query"`
	BestMatch  *RankedChecklist  `json:"bestMatch"`
	Candidates []RankedChecklist `json:"candidates"`
	Clarifiers []string          `json:"clarifiers"`
}

type ContentManifest struct {
	Version        string `json:"version"`
	ChecklistCount int    `json:"checklistCount"`
	GeneratedAt    int64  `json:"generatedAt"`
}

type ContentBootstrap struct {
	Manifest       ContentManifest `json:"manifest"`
	MatchingConfig MatchingConfig  `json:"matchingConfig"`
	Checklists     []Checklist     `json:"checklists"`
}

type MatchingConfig struct {
	PartialMinLength int             `json:"partialMinLength"`
	SynonymGroups    [][]string      `json:"synonymGroups"`
	Weights          MatchingWeights `json:"weights"`
}

type MatchingWeights struct {
	ExactQueryID      float64 `json:"exactQueryId"`
	ExactIDToken      float64 `json:"exactIdToken"`
	ExactTitleToken   float64 `json:"exactTitleToken"`
	ExactKeywordToken float64 `json:"exactKeywordToken"`
	ExactSymptomToken float64 `json:"exactSymptomToken"`
	ExactContextToken float64 `json:"exactContextToken"`
	SynonymKeyword    float64 `json:"synonymKeyword"`
	SynonymPrimary    float64 `json:"synonymPrimary"`
	SynonymAny        float64 `json:"synonymAny"`
	PartialKeyword    float64 `json:"partialKeyword"`
	PartialPrimary    float64 `json:"partialPrimary"`
	PartialAny        float64 `json:"partialAny"`
	TokenAverage      float64 `json:"tokenAverage"`
	KeywordCoverage   float64 `json:"keywordCoverage"`
	ExactTitleBoost   float64 `json:"exactTitleBoost"`
	PartialTitleBoost float64 `json:"partialTitleBoost"`
	PartialIDBoost    float64 `json:"partialIdBoost"`
	PhraseBoost       float64 `json:"phraseBoost"`
}

type contentSyncRequest struct {
	Bootstrap ContentBootstrap `json:"bootstrap"`
}

type contentSyncResponse struct {
	ContentVersion string `json:"contentVersion"`
	ChecklistCount int    `json:"checklistCount"`
	IndexedAt      int64  `json:"indexedAt"`
}

type lookupRequest struct {
	Query          string            `json:"query"`
	ContentVersion string            `json:"contentVersion,omitempty"`
	Bootstrap      *ContentBootstrap `json:"bootstrap,omitempty"`
}

type ragAnswerResponse struct {
	Query      string            `json:"query"`
	Answer     string            `json:"answer"`
	Citations  []ragCitation     `json:"citations"`
	Candidates []RankedChecklist `json:"candidates"`
	Mode       string            `json:"mode"`
	Provider   string            `json:"provider,omitempty"`
	Model      string            `json:"model,omitempty"`
	Notice     string            `json:"notice,omitempty"`
}

type ragCitation struct {
	ID    string  `json:"id"`
	Title string  `json:"title"`
	Score float64 `json:"score"`
}

const (
	maxContentSyncBytes = 32 << 20
	minMatchScore       = 0.25
)

type server struct {
	store      *contentStore
	metrics    *serverMetrics
	llmLimiter chan struct{}
	llmBreaker *circuitBreaker
	llmClient  *http.Client
}

func newServer() *server {
	return &server{
		store:      &contentStore{},
		metrics:    &serverMetrics{},
		llmLimiter: make(chan struct{}, llmMaxConcurrency()),
		llmBreaker: &circuitBreaker{
			maxFailures: 3,
			cooldown:    30 * time.Second,
		},
		llmClient: &http.Client{},
	}
}

type serverMetrics struct {
	requests       atomic.Int64
	errors         atomic.Int64
	contentSyncs   atomic.Int64
	llmRequests    atomic.Int64
	llmFailures    atomic.Int64
	llmRejected    atomic.Int64
	lastContentSet atomic.Int64
}

type contentStore struct {
	mu       sync.RWMutex
	current  *contentSnapshot
	versions map[string]*contentSnapshot
}

type contentSnapshot struct {
	version        string
	manifest       ContentManifest
	runtime        matchingRuntime
	entries        []indexedChecklist
	checklistCount int
	indexedAt      time.Time
}

type indexedChecklist struct {
	checklist Checklist
	index     checklistIndex
}

func (store *contentStore) sync(bootstrap ContentBootstrap) (*contentSnapshot, error) {
	snapshot, err := newContentSnapshot(bootstrap)
	if err != nil {
		return nil, err
	}

	store.mu.Lock()
	defer store.mu.Unlock()
	if store.versions == nil {
		store.versions = map[string]*contentSnapshot{}
	}
	store.current = snapshot
	store.versions[snapshot.version] = snapshot
	return snapshot, nil
}

func (store *contentStore) get(version string) (*contentSnapshot, bool) {
	store.mu.RLock()
	defer store.mu.RUnlock()
	if version == "" {
		if store.current == nil {
			return nil, false
		}
		return store.current, true
	}
	if store.versions == nil {
		return nil, false
	}
	snapshot, ok := store.versions[version]
	return snapshot, ok
}

func newContentSnapshot(bootstrap ContentBootstrap) (*contentSnapshot, error) {
	if err := validateBootstrap(bootstrap); err != nil {
		return nil, err
	}

	config := normalizeConfig(bootstrap.MatchingConfig)
	runtime := newMatchingRuntime(config)
	entries := make([]indexedChecklist, 0, len(bootstrap.Checklists))
	for _, checklist := range bootstrap.Checklists {
		entries = append(entries, indexedChecklist{
			checklist: checklist,
			index:     newChecklistIndex(checklist),
		})
	}

	return &contentSnapshot{
		version:        contentVersion(bootstrap),
		manifest:       bootstrap.Manifest,
		runtime:        runtime,
		entries:        entries,
		checklistCount: len(entries),
		indexedAt:      time.Now(),
	}, nil
}

func validateBootstrap(bootstrap ContentBootstrap) error {
	if len(bootstrap.Checklists) == 0 {
		return fmt.Errorf("bootstrap must include at least one checklist")
	}
	if bootstrap.Manifest.ChecklistCount > 0 && bootstrap.Manifest.ChecklistCount != len(bootstrap.Checklists) {
		return fmt.Errorf("manifest checklistCount %d does not match %d checklists", bootstrap.Manifest.ChecklistCount, len(bootstrap.Checklists))
	}
	seen := map[string]bool{}
	for index, checklist := range bootstrap.Checklists {
		id := strings.TrimSpace(checklist.ID)
		title := strings.TrimSpace(checklist.Title)
		if id == "" || title == "" {
			return fmt.Errorf("checklist %d must include non-empty id and title", index)
		}
		normalizedID := strings.ToLower(id)
		if seen[normalizedID] {
			return fmt.Errorf("duplicate checklist id %q", id)
		}
		seen[normalizedID] = true
	}
	return nil
}

func contentVersion(bootstrap ContentBootstrap) string {
	encoded, err := json.Marshal(bootstrap)
	if err != nil {
		return strings.TrimSpace(bootstrap.Manifest.Version)
	}
	sum := sha256.Sum256(encoded)
	version := strings.TrimSpace(bootstrap.Manifest.Version)
	if version == "" {
		version = "content"
	}
	return fmt.Sprintf("%s-%x", version, sum[:8])
}

func main() {
	port := flag.Int("port", 0, "loopback port to listen on, 0 chooses a free port")
	flag.Parse()

	listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		log.Fatalf("listen: %v", err)
	}

	mux := http.NewServeMux()
	app := newServer()
	mux.HandleFunc("/health", app.health)
	mux.HandleFunc("/metrics", app.metricsHandler)
	mux.HandleFunc("/content/sync", app.contentSync)
	mux.HandleFunc("/lookup", app.lookup)
	mux.HandleFunc("/agent/navigate", app.agentNavigate)
	mux.HandleFunc("/rag/answer", app.ragAnswer)

	actualPort := listener.Addr().(*net.TCPAddr).Port
	ready := map[string]any{
		"event": "ready",
		"port":  actualPort,
	}
	if err := json.NewEncoder(log.Writer()).Encode(ready); err != nil {
		log.Printf("ready log failed: %v", err)
	}
	fmt.Printf("{\"event\":\"ready\",\"port\":%d}\n", actualPort)

	httpServer := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	if err := httpServer.Serve(listener); err != nil && err != http.ErrServerClosed {
		log.Fatalf("serve: %v", err)
	}
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, map[string]string{
		"status": "ok",
		"mode":   "local-rag-sidecar",
	})
}

func (s *server) metricsHandler(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	current, _ := s.store.get("")
	payload := map[string]any{
		"requests":       s.metrics.requests.Load(),
		"errors":         s.metrics.errors.Load(),
		"contentSyncs":   s.metrics.contentSyncs.Load(),
		"llmRequests":    s.metrics.llmRequests.Load(),
		"llmFailures":    s.metrics.llmFailures.Load(),
		"llmRejected":    s.metrics.llmRejected.Load(),
		"lastContentSet": s.metrics.lastContentSet.Load(),
	}
	if current != nil {
		payload["contentVersion"] = current.version
		payload["checklistCount"] = current.checklistCount
		payload["indexedAt"] = current.indexedAt.UnixMilli()
	}
	writeJSON(w, payload)
}

func (s *server) contentSync(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var request contentSyncRequest
	if !s.decodeJSON(w, r, maxContentSyncBytes, &request) {
		return
	}

	snapshot, err := s.store.sync(request.Bootstrap)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	s.metrics.contentSyncs.Add(1)
	s.metrics.lastContentSet.Store(time.Now().UnixMilli())
	writeJSON(w, contentSyncResponse{
		ContentVersion: snapshot.version,
		ChecklistCount: snapshot.checklistCount,
		IndexedAt:      snapshot.indexedAt.UnixMilli(),
	})
}

func (s *server) lookup(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	request, snapshot, ok := s.decodeResolvedLookupRequest(w, r)
	if !ok {
		return
	}
	writeJSON(w, searchSnapshot(request.Query, snapshot))
}

func (s *server) agentNavigate(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	request, snapshot, ok := s.decodeResolvedLookupRequest(w, r)
	if !ok {
		return
	}

	lookup := searchSnapshot(request.Query, snapshot)
	var best *RankedChecklist
	if len(lookup.Candidates) > 0 {
		candidate := lookup.Candidates[0]
		best = &candidate
	}

	clarifiers := make([]string, 0, 3)
	query := strings.TrimSpace(request.Query)
	for _, candidate := range lookup.Candidates {
		for _, symptom := range candidate.Checklist.Symptoms {
			addClarifier(&clarifiers, query, symptom)
			if len(clarifiers) >= 3 {
				break
			}
		}
		if len(clarifiers) >= 3 {
			break
		}
	}

	writeJSON(w, AgentNavigationResponse{
		Query:      lookup.Query,
		BestMatch:  best,
		Candidates: lookup.Candidates,
		Clarifiers: clarifiers,
	})
}

func (s *server) ragAnswer(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	request, snapshot, ok := s.decodeResolvedLookupRequest(w, r)
	if !ok {
		return
	}

	lookup := searchSnapshot(request.Query, snapshot)
	citations := make([]ragCitation, 0, len(lookup.Candidates))
	for _, candidate := range lookup.Candidates {
		citations = append(citations, ragCitation{
			ID:    candidate.Checklist.ID,
			Title: candidate.Checklist.Title,
			Score: candidate.Score,
		})
	}

	answer := s.generateRAGAnswer(r.Context(), request.Query, lookup.Candidates)
	writeJSON(w, ragAnswerResponse{
		Query:      request.Query,
		Answer:     answer.Answer,
		Citations:  citations,
		Candidates: lookup.Candidates,
		Mode:       answer.Mode,
		Provider:   answer.Provider,
		Model:      answer.Model,
		Notice:     answer.Notice,
	})
}

type ragAnswerResult struct {
	Answer   string
	Mode     string
	Provider string
	Model    string
	Notice   string
}

func generateRAGAnswer(ctx context.Context, query string, candidates []RankedChecklist) ragAnswerResult {
	return newServer().generateRAGAnswer(ctx, query, candidates)
}

func (s *server) generateRAGAnswer(ctx context.Context, query string, candidates []RankedChecklist) ragAnswerResult {
	localAnswer := buildLocalRAGAnswer(query, candidates)
	config, ok := loadLLMConfig()
	if !ok {
		return ragAnswerResult{Answer: localAnswer, Mode: "local"}
	}
	if !s.llmBreaker.allow() {
		s.metrics.llmRejected.Add(1)
		return ragAnswerResult{
			Answer:   localAnswer,
			Mode:     "local_fallback",
			Provider: config.Provider,
			Model:    config.Model,
			Notice:   "LLM provider circuit is open; using local retrieval answer.",
		}
	}

	select {
	case s.llmLimiter <- struct{}{}:
		defer func() { <-s.llmLimiter }()
	default:
		s.metrics.llmRejected.Add(1)
		return ragAnswerResult{
			Answer:   localAnswer,
			Mode:     "local_fallback",
			Provider: config.Provider,
			Model:    config.Model,
			Notice:   "LLM concurrency limit was reached; using local retrieval answer.",
		}
	}

	s.metrics.llmRequests.Add(1)
	answer, err := callLLM(ctx, s.llmClient, config, query, candidates)
	if err != nil {
		s.metrics.llmFailures.Add(1)
		s.llmBreaker.recordFailure()
		log.Printf("llm provider failed: %v", err)
		return ragAnswerResult{
			Answer:   localAnswer,
			Mode:     "local_fallback",
			Provider: config.Provider,
			Model:    config.Model,
			Notice:   "LLM provider was unavailable; using local retrieval answer.",
		}
	}
	s.llmBreaker.recordSuccess()

	return ragAnswerResult{
		Answer:   answer,
		Mode:     "llm",
		Provider: config.Provider,
		Model:    config.Model,
	}
}

func buildLocalRAGAnswer(query string, candidates []RankedChecklist) string {
	if len(candidates) == 0 || candidates[0].Score <= 0 {
		return "No matching runbook was found in the local handbook. Try adding a more specific symptom, component, or error signal."
	}

	best := candidates[0].Checklist
	var builder strings.Builder
	fmt.Fprintf(&builder, "Start with %q because it is the strongest retrieved runbook for %q.\n\n", best.Title, strings.TrimSpace(query))

	if len(best.Symptoms) > 0 {
		fmt.Fprintf(&builder, "Matched signals: %s.\n", strings.Join(takeStrings(best.Symptoms, 3), ", "))
	}
	if len(best.ImmediateActions) > 0 {
		builder.WriteString("Immediate checks:\n")
		for _, step := range takeSteps(best.ImmediateActions, 3) {
			fmt.Fprintf(&builder, "%d. %s\n", step.Step, step.Action)
		}
	}
	if len(best.DecisionTree) > 0 {
		builder.WriteString("Decision points:\n")
		for _, branch := range takeBranches(best.DecisionTree, 2) {
			fmt.Fprintf(&builder, "- If %s, %s.\n", branch.Condition, branch.Action)
		}
	}
	if len(best.RootCause) > 0 {
		fmt.Fprintf(&builder, "Likely causes: %s.\n", strings.Join(takeStrings(best.RootCause, 3), ", "))
	}
	if len(best.LongTermFix) > 0 {
		fmt.Fprintf(&builder, "Long-term fixes: %s.\n", strings.Join(takeStrings(best.LongTermFix, 3), ", "))
	}

	alternatives := []string{}
	for _, candidate := range candidates[1:] {
		if candidate.Score <= 0 {
			continue
		}
		alternatives = append(alternatives, candidate.Checklist.Title)
		if len(alternatives) >= 2 {
			break
		}
	}
	if len(alternatives) > 0 {
		fmt.Fprintf(&builder, "Also compare: %s.\n", strings.Join(alternatives, ", "))
	}

	return strings.TrimSpace(builder.String())
}

type llmConfig struct {
	Provider    string
	BaseURL     string
	APIKey      string
	Model       string
	Temperature float64
	Timeout     time.Duration
}

type circuitBreaker struct {
	mu          sync.Mutex
	failures    int
	maxFailures int
	openUntil   time.Time
	cooldown    time.Duration
}

func (breaker *circuitBreaker) allow() bool {
	breaker.mu.Lock()
	defer breaker.mu.Unlock()
	return time.Now().After(breaker.openUntil)
}

func (breaker *circuitBreaker) recordSuccess() {
	breaker.mu.Lock()
	defer breaker.mu.Unlock()
	breaker.failures = 0
	breaker.openUntil = time.Time{}
}

func (breaker *circuitBreaker) recordFailure() {
	breaker.mu.Lock()
	defer breaker.mu.Unlock()
	breaker.failures++
	if breaker.failures >= breaker.maxFailures {
		breaker.openUntil = time.Now().Add(breaker.cooldown)
	}
}

func llmMaxConcurrency() int {
	raw := strings.TrimSpace(os.Getenv("DEVQRH_LLM_MAX_CONCURRENCY"))
	if raw == "" {
		return 2
	}
	parsed, err := strconv.Atoi(raw)
	if err != nil || parsed <= 0 {
		return 2
	}
	if parsed > 16 {
		return 16
	}
	return parsed
}

func loadLLMConfig() (llmConfig, bool) {
	apiKey := strings.TrimSpace(os.Getenv("DEVQRH_LLM_API_KEY"))
	model := strings.TrimSpace(os.Getenv("DEVQRH_LLM_MODEL"))
	if apiKey == "" || model == "" {
		return llmConfig{}, false
	}

	baseURL := strings.TrimSpace(os.Getenv("DEVQRH_LLM_BASE_URL"))
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}

	temperature := 0.2
	if raw := strings.TrimSpace(os.Getenv("DEVQRH_LLM_TEMPERATURE")); raw != "" {
		if parsed, err := strconv.ParseFloat(raw, 64); err == nil {
			temperature = parsed
		}
	}

	timeout := 20 * time.Second
	if raw := strings.TrimSpace(os.Getenv("DEVQRH_LLM_TIMEOUT_SECONDS")); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			timeout = time.Duration(parsed) * time.Second
		}
	}

	return llmConfig{
		Provider:    "openai-compatible",
		BaseURL:     strings.TrimRight(baseURL, "/"),
		APIKey:      apiKey,
		Model:       model,
		Temperature: temperature,
		Timeout:     timeout,
	}, true
}

type chatCompletionRequest struct {
	Model       string        `json:"model"`
	Temperature float64       `json:"temperature"`
	Messages    []chatMessage `json:"messages"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatCompletionResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func callLLM(ctx context.Context, client *http.Client, config llmConfig, query string, candidates []RankedChecklist) (string, error) {
	if len(candidates) == 0 || candidates[0].Score <= 0 {
		return buildLocalRAGAnswer(query, candidates), nil
	}

	requestBody := chatCompletionRequest{
		Model:       config.Model,
		Temperature: config.Temperature,
		Messages: []chatMessage{
			{
				Role: "system",
				Content: strings.Join([]string{
					"You are DevQRH's incident-response RAG assistant.",
					"Answer only from the retrieved runbook context.",
					"If the context is insufficient, say what is missing.",
					"Keep the answer concise and operational.",
					"Use the same language as the user's question when possible.",
					"Reference source titles or ids naturally; do not invent facts.",
				}, " "),
			},
			{
				Role:    "user",
				Content: buildLLMPrompt(query, candidates),
			},
		},
	}

	encoded, err := json.Marshal(requestBody)
	if err != nil {
		return "", fmt.Errorf("marshal chat request: %w", err)
	}

	ctx, cancel := context.WithTimeout(ctx, config.Timeout)
	defer cancel()

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, config.BaseURL+"/chat/completions", bytes.NewReader(encoded))
	if err != nil {
		return "", fmt.Errorf("create chat request: %w", err)
	}
	request.Header.Set("Authorization", "Bearer "+config.APIKey)
	request.Header.Set("Content-Type", "application/json")

	response, err := client.Do(request)
	if err != nil {
		return "", fmt.Errorf("call chat completions: %w", err)
	}
	defer response.Body.Close()

	var decoded chatCompletionResponse
	if err := json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&decoded); err != nil {
		return "", fmt.Errorf("decode chat response: %w", err)
	}

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		if decoded.Error != nil && decoded.Error.Message != "" {
			return "", fmt.Errorf("chat completions status %d: %s", response.StatusCode, decoded.Error.Message)
		}
		return "", fmt.Errorf("chat completions status %d", response.StatusCode)
	}
	if len(decoded.Choices) == 0 {
		return "", fmt.Errorf("chat completions returned no choices")
	}

	content := strings.TrimSpace(decoded.Choices[0].Message.Content)
	if content == "" {
		return "", fmt.Errorf("chat completions returned an empty message")
	}
	return content, nil
}

func buildLLMPrompt(query string, candidates []RankedChecklist) string {
	var builder strings.Builder
	fmt.Fprintf(&builder, "User question:\n%s\n\n", strings.TrimSpace(query))
	builder.WriteString("Retrieved runbooks:\n")
	for index, candidate := range candidates {
		if index >= 3 || candidate.Score <= 0 {
			break
		}
		checklist := candidate.Checklist
		fmt.Fprintf(&builder, "\n[%d] %s (%s), score %.2f\n", index+1, checklist.Title, checklist.ID, candidate.Score)
		writePromptList(&builder, "Symptoms", checklist.Symptoms, 4)
		writePromptSteps(&builder, "Immediate actions", checklist.ImmediateActions, 4)
		writePromptBranches(&builder, "Decision points", checklist.DecisionTree, 3)
		writePromptList(&builder, "Likely causes", checklist.RootCause, 4)
		writePromptList(&builder, "Long-term fixes", checklist.LongTermFix, 4)
	}
	builder.WriteString("\nReturn a grounded answer with: recommendation, immediate checks, decision points, and sources.\n")
	return builder.String()
}

func writePromptList(builder *strings.Builder, label string, values []string, limit int) {
	if len(values) == 0 {
		return
	}
	fmt.Fprintf(builder, "- %s: %s\n", label, strings.Join(takeStrings(values, limit), "; "))
}

func writePromptSteps(builder *strings.Builder, label string, values []ChecklistStep, limit int) {
	if len(values) == 0 {
		return
	}
	builder.WriteString("- " + label + ": ")
	parts := []string{}
	for _, step := range takeSteps(values, limit) {
		parts = append(parts, fmt.Sprintf("%d. %s", step.Step, step.Action))
	}
	builder.WriteString(strings.Join(parts, "; "))
	builder.WriteString("\n")
}

func writePromptBranches(builder *strings.Builder, label string, values []ChecklistBranch, limit int) {
	if len(values) == 0 {
		return
	}
	builder.WriteString("- " + label + ": ")
	parts := []string{}
	for _, branch := range takeBranches(values, limit) {
		parts = append(parts, fmt.Sprintf("if %s -> %s", branch.Condition, branch.Action))
	}
	builder.WriteString(strings.Join(parts, "; "))
	builder.WriteString("\n")
}

func (s *server) decodeJSON(w http.ResponseWriter, r *http.Request, maxBytes int64, target any) bool {
	defer r.Body.Close()

	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			s.writeError(w, http.StatusRequestEntityTooLarge, "request body is too large")
			return false
		}
		s.writeError(w, http.StatusBadRequest, "invalid JSON request")
		return false
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		s.writeError(w, http.StatusBadRequest, "request body must contain a single JSON object")
		return false
	}
	return true
}

func (s *server) decodeResolvedLookupRequest(w http.ResponseWriter, r *http.Request) (lookupRequest, *contentSnapshot, bool) {
	var request lookupRequest
	if !s.decodeJSON(w, r, maxContentSyncBytes, &request) {
		return lookupRequest{}, nil, false
	}
	request.Query = strings.TrimSpace(request.Query)
	if request.Query == "" {
		s.writeError(w, http.StatusBadRequest, "query is required")
		return lookupRequest{}, nil, false
	}

	if request.ContentVersion != "" {
		if snapshot, ok := s.store.get(request.ContentVersion); ok {
			return request, snapshot, true
		}
		if request.Bootstrap == nil {
			s.writeError(w, http.StatusConflict, "contentVersion is not synced")
			return lookupRequest{}, nil, false
		}
	}

	if request.Bootstrap != nil {
		snapshot, err := s.store.sync(*request.Bootstrap)
		if err != nil {
			s.writeError(w, http.StatusBadRequest, err.Error())
			return lookupRequest{}, nil, false
		}
		s.metrics.contentSyncs.Add(1)
		s.metrics.lastContentSet.Store(time.Now().UnixMilli())
		return request, snapshot, true
	}

	s.writeError(w, http.StatusBadRequest, "contentVersion or bootstrap is required")
	return lookupRequest{}, nil, false
}

func search(query string, bootstrap ContentBootstrap) LookupResponse {
	snapshot, err := newContentSnapshot(bootstrap)
	if err != nil {
		return LookupResponse{
			Query:      query,
			BestMatch:  nil,
			Candidates: []RankedChecklist{},
		}
	}
	return searchSnapshot(query, snapshot)
}

func searchSnapshot(query string, snapshot *contentSnapshot) LookupResponse {
	normalizedQuery := normalize(query)
	queryTokens := tokenize(query)
	if len(queryTokens) == 0 || snapshot == nil {
		return LookupResponse{
			Query:      query,
			BestMatch:  nil,
			Candidates: []RankedChecklist{},
		}
	}

	ranked := make([]RankedChecklist, 0, 3)
	for _, entry := range snapshot.entries {
		score := scoreIndexedChecklist(normalizedQuery, queryTokens, entry.index, snapshot.runtime)
		if score < minMatchScore {
			continue
		}
		ranked = insertTopCandidate(ranked, RankedChecklist{
			Checklist: entry.checklist,
			Score:     score,
		}, 3)
	}
	var best *Checklist
	if len(ranked) > 0 {
		checklist := ranked[0].Checklist
		best = &checklist
	}

	return LookupResponse{
		Query:      query,
		BestMatch:  best,
		Candidates: ranked,
	}
}

func insertTopCandidate(candidates []RankedChecklist, candidate RankedChecklist, limit int) []RankedChecklist {
	insertAt := len(candidates)
	for index, existing := range candidates {
		if candidate.Score > existing.Score ||
			(candidate.Score == existing.Score && candidate.Checklist.Title < existing.Checklist.Title) {
			insertAt = index
			break
		}
	}
	candidates = append(candidates, RankedChecklist{})
	copy(candidates[insertAt+1:], candidates[insertAt:])
	candidates[insertAt] = candidate
	if len(candidates) > limit {
		candidates = candidates[:limit]
	}
	return candidates
}

type matchingRuntime struct {
	config          MatchingConfig
	synonymsByToken map[string]map[string]bool
}

func newMatchingRuntime(config MatchingConfig) matchingRuntime {
	synonyms := map[string]map[string]bool{}
	for _, group := range config.SynonymGroups {
		normalizedGroup := map[string]bool{}
		for _, item := range group {
			normalized := normalize(item)
			if normalized != "" {
				normalizedGroup[normalized] = true
			}
		}
		for token := range normalizedGroup {
			synonyms[token] = normalizedGroup
		}
	}
	return matchingRuntime{
		config:          config,
		synonymsByToken: synonyms,
	}
}

type checklistIndex struct {
	normalizedID    string
	normalizedTitle string
	idTokens        map[string]bool
	titleTokens     map[string]bool
	keywordTokens   map[string]bool
	symptomTokens   map[string]bool
	contextTokens   map[string]bool
	primaryTokens   map[string]bool
	allTokens       map[string]bool
	documentText    string
}

func newChecklistIndex(checklist Checklist) checklistIndex {
	idTokens := tokenSet(checklist.ID)
	titleTokens := tokenSet(checklist.Title)
	keywordTokens := tokenSetAll(checklist.Keywords)
	symptomTokens := tokenSetAll(checklist.Symptoms)
	contextTokens := mergeSets(
		tokenSetAll(checklist.RootCause),
		tokenSetAll(checklist.LongTermFix),
	)
	primaryTokens := mergeSets(titleTokens, keywordTokens, symptomTokens)
	allTokens := mergeSets(idTokens, primaryTokens, contextTokens)

	documentParts := []string{
		checklist.ID,
		checklist.Title,
	}
	documentParts = append(documentParts, checklist.Keywords...)
	documentParts = append(documentParts, checklist.Symptoms...)
	documentParts = append(documentParts, checklist.RootCause...)
	documentParts = append(documentParts, checklist.LongTermFix...)

	return checklistIndex{
		normalizedID:    normalize(checklist.ID),
		normalizedTitle: normalize(checklist.Title),
		idTokens:        idTokens,
		titleTokens:     titleTokens,
		keywordTokens:   keywordTokens,
		symptomTokens:   symptomTokens,
		contextTokens:   contextTokens,
		primaryTokens:   primaryTokens,
		allTokens:       allTokens,
		documentText:    normalize(strings.Join(documentParts, " ")),
	}
}

func scoreChecklist(normalizedQuery string, queryTokens []string, checklist Checklist, runtime matchingRuntime) float64 {
	return scoreIndexedChecklist(normalizedQuery, queryTokens, newChecklistIndex(checklist), runtime)
}

func scoreIndexedChecklist(normalizedQuery string, queryTokens []string, index checklistIndex, runtime matchingRuntime) float64 {
	weights := runtime.config.Weights

	total := 0.0
	for _, token := range queryTokens {
		total += scoreToken(token, index, runtime)
	}

	score := ((total / float64(len(queryTokens))) * weights.TokenAverage) +
		(keywordCoverage(queryTokens, index, runtime) * weights.KeywordCoverage)

	if index.normalizedID == normalizedQuery {
		return round(clamp(weights.ExactQueryID))
	}

	if index.normalizedTitle == normalizedQuery {
		score += weights.ExactTitleBoost
	} else if strings.Contains(index.normalizedTitle, normalizedQuery) ||
		strings.Contains(normalizedQuery, index.normalizedTitle) {
		score += weights.PartialTitleBoost
	}

	if strings.Contains(index.normalizedID, normalizedQuery) ||
		strings.Contains(normalizedQuery, index.normalizedID) {
		score += weights.PartialIDBoost
	}

	if len(normalizedQuery) >= 4 && strings.Contains(index.documentText, normalizedQuery) {
		score += weights.PhraseBoost
	}

	return round(clamp(score))
}

func scoreToken(token string, index checklistIndex, runtime matchingRuntime) float64 {
	weights := runtime.config.Weights
	if index.idTokens[token] {
		return weights.ExactIDToken
	}
	if index.titleTokens[token] {
		return weights.ExactTitleToken
	}
	if index.keywordTokens[token] {
		return weights.ExactKeywordToken
	}
	if index.symptomTokens[token] {
		return weights.ExactSymptomToken
	}
	if index.contextTokens[token] {
		return weights.ExactContextToken
	}

	synonyms := runtime.synonymsByToken[token]
	if len(synonyms) > 0 {
		if hasOverlap(synonyms, index.keywordTokens) {
			return weights.SynonymKeyword
		}
		if hasOverlap(synonyms, index.primaryTokens) {
			return weights.SynonymPrimary
		}
		if hasOverlap(synonyms, index.allTokens) {
			return weights.SynonymAny
		}
	}

	partialMinLength := runtime.config.PartialMinLength
	if hasPartialMatch(token, index.keywordTokens, partialMinLength) {
		return weights.PartialKeyword
	}
	if hasPartialMatch(token, index.primaryTokens, partialMinLength) {
		return weights.PartialPrimary
	}
	if hasPartialMatch(token, index.allTokens, partialMinLength) {
		return weights.PartialAny
	}
	return 0
}

func keywordCoverage(queryTokens []string, index checklistIndex, runtime matchingRuntime) float64 {
	if len(queryTokens) == 0 {
		return 0
	}
	matched := 0
	for _, token := range queryTokens {
		if index.keywordTokens[token] {
			matched++
			continue
		}
		synonyms := runtime.synonymsByToken[token]
		if hasOverlap(synonyms, index.keywordTokens) ||
			hasPartialMatch(token, index.keywordTokens, runtime.config.PartialMinLength) {
			matched++
		}
	}
	return float64(matched) / float64(len(queryTokens))
}

func addClarifier(clarifiers *[]string, query string, value string) {
	normalized := strings.TrimSpace(value)
	if normalized == "" || strings.EqualFold(normalized, query) {
		return
	}
	for _, existing := range *clarifiers {
		if strings.EqualFold(existing, "check: "+normalized) {
			return
		}
	}
	*clarifiers = append(*clarifiers, "check: "+normalized)
}

func takeStrings(values []string, limit int) []string {
	if len(values) <= limit {
		return values
	}
	return values[:limit]
}

func takeSteps(values []ChecklistStep, limit int) []ChecklistStep {
	if len(values) <= limit {
		return values
	}
	return values[:limit]
}

func takeBranches(values []ChecklistBranch, limit int) []ChecklistBranch {
	if len(values) <= limit {
		return values
	}
	return values[:limit]
}

var tokenSplitter = regexp.MustCompile(`[^a-z0-9]+`)

func tokenize(input string) []string {
	parts := tokenSplitter.Split(normalize(input), -1)
	seen := map[string]bool{}
	tokens := []string{}
	for _, part := range parts {
		if part == "" || seen[part] {
			continue
		}
		seen[part] = true
		tokens = append(tokens, part)
	}
	return tokens
}

func tokenSet(input string) map[string]bool {
	result := map[string]bool{}
	for _, token := range tokenize(input) {
		result[token] = true
	}
	return result
}

func tokenSetAll(values []string) map[string]bool {
	result := map[string]bool{}
	for _, value := range values {
		for token := range tokenSet(value) {
			result[token] = true
		}
	}
	return result
}

func mergeSets(sets ...map[string]bool) map[string]bool {
	result := map[string]bool{}
	for _, set := range sets {
		for token := range set {
			result[token] = true
		}
	}
	return result
}

func hasOverlap(left map[string]bool, right map[string]bool) bool {
	for token := range left {
		if right[token] {
			return true
		}
	}
	return false
}

func hasPartialMatch(token string, candidates map[string]bool, partialMinLength int) bool {
	if len(token) < partialMinLength {
		return false
	}
	for candidate := range candidates {
		if len(candidate) < partialMinLength {
			continue
		}
		if strings.HasPrefix(candidate, token) ||
			strings.HasPrefix(token, candidate) ||
			strings.Contains(candidate, token) ||
			strings.Contains(token, candidate) {
			return true
		}
	}
	return false
}

func normalize(input string) string {
	return strings.TrimSpace(strings.ToLower(input))
}

func clamp(value float64) float64 {
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}

func round(value float64) float64 {
	return math.Round(value*100) / 100
}

func normalizeConfig(config MatchingConfig) MatchingConfig {
	if config.PartialMinLength <= 0 {
		config.PartialMinLength = 3
	}
	if config.Weights.TokenAverage == 0 {
		config.Weights = defaultWeights()
	}
	return config
}

func defaultWeights() MatchingWeights {
	return MatchingWeights{
		ExactQueryID:      1.0,
		ExactIDToken:      1.0,
		ExactTitleToken:   0.95,
		ExactKeywordToken: 0.90,
		ExactSymptomToken: 0.78,
		ExactContextToken: 0.60,
		SynonymKeyword:    0.72,
		SynonymPrimary:    0.62,
		SynonymAny:        0.50,
		PartialKeyword:    0.48,
		PartialPrimary:    0.40,
		PartialAny:        0.28,
		TokenAverage:      0.88,
		KeywordCoverage:   0.12,
		ExactTitleBoost:   0.12,
		PartialTitleBoost: 0.07,
		PartialIDBoost:    0.07,
		PhraseBoost:       0.04,
	}
}

func writeJSON(w http.ResponseWriter, payload any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("write response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func (s *server) writeError(w http.ResponseWriter, status int, message string) {
	s.metrics.errors.Add(1)
	writeError(w, status, message)
}
