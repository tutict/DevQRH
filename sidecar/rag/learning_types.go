package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"
)

type MaterialType string

type LearningManifest struct {
	SchemaVersion int    `json:"schemaVersion,omitempty"`
	PackageID     string `json:"packageId,omitempty"`
	Name          string `json:"name,omitempty"`
	Version       string `json:"version"`
	GeneratedAt   int64  `json:"generatedAt"`
	DefaultLocale string `json:"defaultLocale,omitempty"`
	SourceType    string `json:"sourceType,omitempty"`
}

type StudyMaterial struct {
	ID      string       `json:"id"`
	Title   string       `json:"title"`
	Type    MaterialType `json:"type,omitempty"`
	Tags    []string     `json:"tags,omitempty"`
	Summary string       `json:"summary,omitempty"`
	Content string       `json:"content,omitempty"`
	Source  string       `json:"source,omitempty"`
	Chunks  []string     `json:"chunks,omitempty"`
}

type StudyDeck struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Goal    string   `json:"goal,omitempty"`
	Tags    []string `json:"tags,omitempty"`
	CardIDs []string `json:"cardIds,omitempty"`
}

type StudyCard struct {
	ID                string   `json:"id"`
	DeckID            string   `json:"deckId"`
	Front             string   `json:"front"`
	Back              string   `json:"back"`
	Explanation       string   `json:"explanation,omitempty"`
	Tags              []string `json:"tags,omitempty"`
	Difficulty        int      `json:"difficulty,omitempty"`
	SourceMaterialIDs []string `json:"sourceMaterialIds,omitempty"`
}

type LearningBundle struct {
	Manifest       LearningManifest `json:"manifest"`
	MatchingConfig MatchingConfig   `json:"matchingConfig"`
	Materials      []StudyMaterial  `json:"materials"`
	Decks          []StudyDeck      `json:"decks,omitempty"`
	Cards          []StudyCard      `json:"cards,omitempty"`
}

type RankedKnowledgeItem struct {
	Material StudyMaterial `json:"material"`
	Score    float64       `json:"score"`
}

type KnowledgeSearchResponse struct {
	Query      string                `json:"query"`
	BestMatch  *StudyMaterial        `json:"bestMatch"`
	Candidates []RankedKnowledgeItem `json:"candidates"`
}

type learningCitation struct {
	ID    string  `json:"id"`
	Title string  `json:"title"`
	Score float64 `json:"score"`
}

type learningAnswerResponse struct {
	Query      string                `json:"query"`
	Answer     string                `json:"answer"`
	Citations  []learningCitation    `json:"citations"`
	Candidates []RankedKnowledgeItem `json:"candidates"`
	Mode       string                `json:"mode"`
	Notice     string                `json:"notice,omitempty"`
}

type GeneratedCardsResponse struct {
	MaterialIDs []string    `json:"materialIds"`
	Cards       []StudyCard `json:"cards"`
	Mode        string      `json:"mode"`
	Notice      string      `json:"notice,omitempty"`
}

type ReviewState struct {
	CardID          string  `json:"cardId"`
	EaseFactor      float64 `json:"easeFactor"`
	IntervalDays    int     `json:"intervalDays"`
	RepetitionCount int     `json:"repetitionCount"`
	DueAt           int64   `json:"dueAt"`
	LastReviewedAt  int64   `json:"lastReviewedAt,omitempty"`
	Lapses          int     `json:"lapses"`
}

type ReviewResult struct {
	CardID       string      `json:"cardId"`
	NextDueAt    int64       `json:"nextDueAt"`
	UpdatedState ReviewState `json:"updatedState"`
}

type cardsGenerateRequest struct {
	ContentVersion string          `json:"contentVersion,omitempty"`
	Bundle         *LearningBundle `json:"bundle,omitempty"`
	MaterialIDs    []string        `json:"materialIds"`
	Limit          int             `json:"limit,omitempty"`
}

type reviewScheduleRequest struct {
	State ReviewState `json:"state"`
	Grade string      `json:"grade"`
	Now   int64       `json:"now,omitempty"`
}

type learningContentStore struct {
	mu       sync.RWMutex
	current  *learningSnapshot
	versions map[string]*learningSnapshot
}

type learningSnapshot struct {
	version          string
	manifest         LearningManifest
	runtime          matchingRuntime
	entries          []indexedMaterial
	decks            []StudyDeck
	cards            []StudyCard
	indexedAt        time.Time
	validationReport ValidationReport
}

type indexedMaterial struct {
	material StudyMaterial
	index    materialIndex
}

func (store *learningContentStore) sync(bundle LearningBundle) (*learningSnapshot, error) {
	snapshot, err := newLearningSnapshot(bundle)
	if err != nil {
		return nil, err
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.versions == nil {
		store.versions = map[string]*learningSnapshot{}
	}
	store.current = snapshot
	store.versions[snapshot.version] = snapshot
	return snapshot, nil
}

func (store *learningContentStore) get(version string) (*learningSnapshot, bool) {
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

func (store *learningContentStore) has(version string) bool {
	if strings.TrimSpace(version) == "" {
		return false
	}
	_, ok := store.get(version)
	return ok
}

func newLearningSnapshot(bundle LearningBundle) (*learningSnapshot, error) {
	report := validateLearningBundle(bundle)
	if report.hasErrors() {
		return nil, validationError{report: report}
	}
	config := normalizeConfig(bundle.MatchingConfig)
	runtime := newMatchingRuntime(config)
	entries := make([]indexedMaterial, 0, len(bundle.Materials))
	for _, material := range bundle.Materials {
		entries = append(entries, indexedMaterial{material: material, index: newMaterialIndex(material)})
	}
	return &learningSnapshot{
		version:          learningContentVersion(bundle),
		manifest:         bundle.Manifest,
		runtime:          runtime,
		entries:          entries,
		decks:            bundle.Decks,
		cards:            bundle.Cards,
		indexedAt:        time.Now(),
		validationReport: report,
	}, nil
}

func validateLearningBundle(bundle LearningBundle) ValidationReport {
	report := ValidationReport{Errors: []ValidationIssue{}, Warnings: []ValidationIssue{}}
	if len(bundle.Materials) == 0 {
		report.addError("materials", "learning bundle must include at least one material")
		return report
	}
	if bundle.Manifest.SchemaVersion < 0 || bundle.Manifest.SchemaVersion > 2 {
		report.addError("manifest.schemaVersion", "unsupported learning bundle schema version")
	}
	materialIDs := map[string]bool{}
	for index, material := range bundle.Materials {
		path := fmt.Sprintf("materials[%d]", index)
		id := strings.TrimSpace(material.ID)
		if id == "" || strings.TrimSpace(material.Title) == "" {
			report.addError(path, "material must include non-empty id and title")
			continue
		}
		normalized := strings.ToLower(id)
		if materialIDs[normalized] {
			report.addError(path+".id", fmt.Sprintf("duplicate material id %q", id))
		}
		materialIDs[normalized] = true
		if strings.TrimSpace(material.Summary) == "" {
			report.addWarning(path+".summary", "study material should include a summary")
		}
		if strings.TrimSpace(material.Content) == "" && len(material.Chunks) == 0 {
			report.addWarning(path+".content", "study material should include content or chunks")
		}
	}
	deckIDs := map[string]bool{}
	for index, deck := range bundle.Decks {
		path := fmt.Sprintf("decks[%d]", index)
		id := strings.TrimSpace(deck.ID)
		if id == "" || strings.TrimSpace(deck.Title) == "" {
			report.addError(path, "deck must include non-empty id and title")
		}
		normalized := strings.ToLower(id)
		if deckIDs[normalized] {
			report.addError(path+".id", fmt.Sprintf("duplicate deck id %q", id))
		}
		deckIDs[normalized] = true
	}
	cardIDs := map[string]bool{}
	for index, card := range bundle.Cards {
		path := fmt.Sprintf("cards[%d]", index)
		id := strings.TrimSpace(card.ID)
		if id == "" || strings.TrimSpace(card.Front) == "" || strings.TrimSpace(card.Back) == "" {
			report.addError(path, "card must include non-empty id, front, and back")
			continue
		}
		normalized := strings.ToLower(id)
		if cardIDs[normalized] {
			report.addError(path+".id", fmt.Sprintf("duplicate card id %q", id))
		}
		cardIDs[normalized] = true
		if card.DeckID != "" && len(deckIDs) > 0 && !deckIDs[strings.ToLower(card.DeckID)] {
			report.addWarning(path+".deckId", "card references a missing deck")
		}
		for _, materialID := range card.SourceMaterialIDs {
			if !materialIDs[strings.ToLower(materialID)] {
				report.addWarning(path+".sourceMaterialIds", "card references a missing source material")
				break
			}
		}
	}
	return report
}

func learningContentVersion(bundle LearningBundle) string {
	encoded, err := json.Marshal(bundle)
	if err != nil {
		return strings.TrimSpace(bundle.Manifest.Version)
	}
	sum := sha256.Sum256(encoded)
	version := strings.TrimSpace(bundle.Manifest.Version)
	if version == "" {
		version = "learning"
	}
	return fmt.Sprintf("%s-%x", version, sum[:8])
}

type materialIndex struct {
	normalizedID    string
	normalizedTitle string
	idTokens        map[string]bool
	titleTokens     map[string]bool
	tagTokens       map[string]bool
	summaryTokens   map[string]bool
	contextTokens   map[string]bool
	primaryTokens   map[string]bool
	allTokens       map[string]bool
	documentText    string
}

func newMaterialIndex(material StudyMaterial) materialIndex {
	idTokens := tokenSet(material.ID)
	titleTokens := tokenSet(material.Title)
	tagTokens := tokenSetAll(append(material.Tags, string(material.Type)))
	summaryTokens := tokenSet(material.Summary)
	contextTokens := tokenSetAll(append([]string{material.Content, material.Source}, material.Chunks...))
	primaryTokens := mergeSets(titleTokens, tagTokens, summaryTokens)
	allTokens := mergeSets(idTokens, primaryTokens, contextTokens)
	documentParts := []string{material.ID, material.Title, string(material.Type), material.Summary, material.Content, material.Source}
	documentParts = append(documentParts, material.Tags...)
	documentParts = append(documentParts, material.Chunks...)
	return materialIndex{
		normalizedID:    normalize(material.ID),
		normalizedTitle: normalize(material.Title),
		idTokens:        idTokens,
		titleTokens:     titleTokens,
		tagTokens:       tagTokens,
		summaryTokens:   summaryTokens,
		contextTokens:   contextTokens,
		primaryTokens:   primaryTokens,
		allTokens:       allTokens,
		documentText:    normalize(strings.Join(documentParts, " ")),
	}
}

func searchLearningSnapshot(query string, snapshot *learningSnapshot) KnowledgeSearchResponse {
	normalizedQuery := normalize(query)
	queryTokens := tokenize(query)
	if len(queryTokens) == 0 || snapshot == nil {
		return KnowledgeSearchResponse{Query: query, Candidates: []RankedKnowledgeItem{}}
	}
	ranked := make([]RankedKnowledgeItem, 0, len(snapshot.entries))
	for _, entry := range snapshot.entries {
		score := scoreIndexedMaterial(normalizedQuery, queryTokens, entry.index, snapshot.runtime)
		if score < 0.12 {
			continue
		}
		ranked = append(ranked, RankedKnowledgeItem{Material: entry.material, Score: score})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].Score != ranked[j].Score {
			return ranked[i].Score > ranked[j].Score
		}
		return ranked[i].Material.Title < ranked[j].Material.Title
	})
	if len(ranked) > 5 {
		ranked = ranked[:5]
	}
	var best *StudyMaterial
	if len(ranked) > 0 {
		material := ranked[0].Material
		best = &material
	}
	return KnowledgeSearchResponse{Query: query, BestMatch: best, Candidates: ranked}
}

func scoreIndexedMaterial(normalizedQuery string, queryTokens []string, index materialIndex, runtime matchingRuntime) float64 {
	weights := runtime.config.Weights
	total := 0.0
	for _, token := range queryTokens {
		total += scoreMaterialToken(token, index, runtime)
	}
	score := ((total / float64(len(queryTokens))) * weights.TokenAverage) + (materialTagCoverage(queryTokens, index, runtime) * weights.KeywordCoverage)
	if index.normalizedID == normalizedQuery {
		return round(clamp(weights.ExactQueryID))
	}
	if index.normalizedTitle == normalizedQuery {
		score += weights.ExactTitleBoost
	} else if strings.Contains(index.normalizedTitle, normalizedQuery) || strings.Contains(normalizedQuery, index.normalizedTitle) {
		score += weights.PartialTitleBoost
	}
	if strings.Contains(index.normalizedID, normalizedQuery) || strings.Contains(normalizedQuery, index.normalizedID) {
		score += weights.PartialIDBoost
	}
	if len([]rune(normalizedQuery)) >= 2 && strings.Contains(index.documentText, normalizedQuery) {
		score += weights.PhraseBoost
	}
	return round(clamp(score))
}

func scoreMaterialToken(token string, index materialIndex, runtime matchingRuntime) float64 {
	weights := runtime.config.Weights
	if index.idTokens[token] {
		return weights.ExactIDToken
	}
	if index.titleTokens[token] {
		return weights.ExactTitleToken
	}
	if index.tagTokens[token] {
		return weights.ExactKeywordToken
	}
	if index.summaryTokens[token] {
		return weights.ExactSymptomToken
	}
	if index.contextTokens[token] {
		return weights.ExactContextToken
	}
	synonyms := runtime.synonymsByToken[token]
	if len(synonyms) > 0 {
		if hasOverlap(synonyms, index.tagTokens) {
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
	if hasPartialMatch(token, index.tagTokens, partialMinLength) {
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

func materialTagCoverage(queryTokens []string, index materialIndex, runtime matchingRuntime) float64 {
	if len(queryTokens) == 0 {
		return 0
	}
	matched := 0
	for _, token := range queryTokens {
		if index.tagTokens[token] {
			matched++
			continue
		}
		synonyms := runtime.synonymsByToken[token]
		if hasOverlap(synonyms, index.tagTokens) || hasPartialMatch(token, index.tagTokens, runtime.config.PartialMinLength) {
			matched++
		}
	}
	return float64(matched) / float64(len(queryTokens))
}

func buildLearningAnswer(query string, candidates []RankedKnowledgeItem) string {
	if len(candidates) == 0 {
		return "No matching material was found in the local learning library. Try a more specific concept, exam topic, project name, or error signal."
	}
	best := candidates[0].Material
	var builder strings.Builder
	fmt.Fprintf(&builder, "Start with %q because it is the strongest retrieved material for %q.\n\n", best.Title, strings.TrimSpace(query))
	if strings.TrimSpace(best.Summary) != "" {
		fmt.Fprintf(&builder, "Summary: %s\n", strings.TrimSpace(best.Summary))
	}
	chunks := best.Chunks
	if len(chunks) == 0 {
		chunks = splitLearningSentences(best.Content)
	}
	if len(chunks) > 0 {
		builder.WriteString("Key points:\n")
		for _, chunk := range takeStrings(chunks, 3) {
			fmt.Fprintf(&builder, "- %s\n", strings.TrimSpace(chunk))
		}
	}
	alternatives := []string{}
	for _, candidate := range candidates[1:] {
		alternatives = append(alternatives, candidate.Material.Title)
		if len(alternatives) >= 2 {
			break
		}
	}
	if len(alternatives) > 0 {
		fmt.Fprintf(&builder, "Also compare: %s.\n", strings.Join(alternatives, ", "))
	}
	return strings.TrimSpace(builder.String())
}

func generateLearningCards(materials []StudyMaterial, limit int) []StudyCard {
	cards := []StudyCard{}
	for _, material := range materials {
		if len(cards) >= limit {
			break
		}
		keyPoint := firstLearningText(append(material.Chunks, splitLearningSentences(material.Content)...))
		if keyPoint == "" {
			keyPoint = strings.TrimSpace(material.Summary)
		}
		if keyPoint == "" {
			continue
		}
		cards = append(cards, StudyCard{
			ID:                fmt.Sprintf("sidecar-%s-%d", material.ID, len(cards)+1),
			DeckID:            "generated",
			Front:             fmt.Sprintf("What is the key idea in %s?", material.Title),
			Back:              keyPoint,
			Explanation:       material.Summary,
			Tags:              append(takeStrings(material.Tags, 3), "generated"),
			Difficulty:        2,
			SourceMaterialIDs: []string{material.ID},
		})
	}
	return cards
}

func selectLearningMaterials(snapshot *learningSnapshot, ids []string) []StudyMaterial {
	if snapshot == nil {
		return nil
	}
	wanted := map[string]bool{}
	for _, id := range ids {
		normalized := strings.ToLower(strings.TrimSpace(id))
		if normalized != "" {
			wanted[normalized] = true
		}
	}
	selected := []StudyMaterial{}
	for _, entry := range snapshot.entries {
		if len(wanted) == 0 || wanted[strings.ToLower(entry.material.ID)] {
			selected = append(selected, entry.material)
		}
	}
	return selected
}

func learningMaterialIDs(materials []StudyMaterial) []string {
	ids := make([]string, 0, len(materials))
	for _, material := range materials {
		ids = append(ids, material.ID)
	}
	return ids
}

func scheduleLearningReview(state ReviewState, grade string, now time.Time) ReviewResult {
	if state.EaseFactor == 0 {
		state.EaseFactor = 2.5
	}
	reviewedAt := now.UnixMilli()
	next := state
	next.LastReviewedAt = reviewedAt
	switch grade {
	case "again":
		next.EaseFactor = clampLearningEase(state.EaseFactor - 0.2)
		next.IntervalDays = 0
		next.RepetitionCount = 0
		next.Lapses = state.Lapses + 1
		next.DueAt = now.Add(10 * time.Minute).UnixMilli()
	case "hard":
		interval := state.IntervalDays + 1
		if interval <= 0 {
			interval = 1
		}
		next.EaseFactor = clampLearningEase(state.EaseFactor - 0.15)
		next.IntervalDays = interval
		next.RepetitionCount = state.RepetitionCount + 1
		next.DueAt = now.AddDate(0, 0, interval).UnixMilli()
	case "good":
		interval := 1
		if state.RepetitionCount == 1 {
			interval = 3
		} else if state.RepetitionCount > 1 {
			interval = int(math.Round(float64(state.IntervalDays) * state.EaseFactor))
			interval = clampLearningInt(interval, 4, 3650)
		}
		next.IntervalDays = interval
		next.RepetitionCount = state.RepetitionCount + 1
		next.DueAt = now.AddDate(0, 0, interval).UnixMilli()
	case "easy":
		ease := clampLearningEase(state.EaseFactor + 0.15)
		interval := 3
		if state.RepetitionCount == 1 {
			interval = 7
		} else if state.RepetitionCount > 1 {
			interval = int(math.Round(float64(state.IntervalDays) * ease * 1.3))
			interval = clampLearningInt(interval, 7, 3650)
		}
		next.EaseFactor = ease
		next.IntervalDays = interval
		next.RepetitionCount = state.RepetitionCount + 1
		next.DueAt = now.AddDate(0, 0, interval).UnixMilli()
	}
	return ReviewResult{CardID: next.CardID, NextDueAt: next.DueAt, UpdatedState: next}
}

func clampLearningEase(value float64) float64 {
	if value < 1.3 {
		return 1.3
	}
	if value > 3.2 {
		return 3.2
	}
	return math.Round(value*100) / 100
}

func clampLearningInt(value int, min int, max int) int {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

func splitLearningSentences(value string) []string {
	parts := strings.FieldsFunc(value, func(r rune) bool {
		switch r {
		case '。', '.', '!', '?', '！', '？', '\n', '\r':
			return true
		default:
			return false
		}
	})
	result := []string{}
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if len([]rune(trimmed)) >= 8 {
			result = append(result, trimmed)
		}
	}
	return result
}

func firstLearningText(values []string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}
