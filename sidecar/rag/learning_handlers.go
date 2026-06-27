package main

import (
	"errors"
	"net/http"
	"os"
	"strings"
	"time"
)

func (s *server) syncLearningContent(w http.ResponseWriter, bundle LearningBundle) {
	snapshot, err := s.learning.sync(bundle)
	if err != nil {
		var validation validationError
		if errors.As(err, &validation) {
			s.writeValidationError(w, http.StatusBadRequest, validation.report)
			return
		}
		s.writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	s.metrics.contentSyncs.Add(1)
	s.metrics.lastContentSet.Store(time.Now().UnixMilli())
	writeJSON(w, contentSyncResponse{
		ContentVersion: snapshot.version,
		MaterialCount:  len(snapshot.entries),
		CardCount:      len(snapshot.cards),
		IndexedAt:      snapshot.indexedAt.UnixMilli(),
		Validation:     snapshot.validationReport,
	})
}

func (s *server) resolveLearningContent(
	w http.ResponseWriter,
	version string,
	bundle *LearningBundle,
) (*learningSnapshot, bool) {
	if version != "" {
		if snapshot, ok := s.learning.get(version); ok {
			return snapshot, true
		}
		if bundle == nil {
			s.writeError(w, http.StatusConflict, "contentVersion is not synced")
			return nil, false
		}
	}
	if bundle != nil {
		snapshot, err := s.learning.sync(*bundle)
		if err != nil {
			var validation validationError
			if errors.As(err, &validation) {
				s.writeValidationError(w, http.StatusBadRequest, validation.report)
				return nil, false
			}
			s.writeError(w, http.StatusBadRequest, err.Error())
			return nil, false
		}
		s.metrics.contentSyncs.Add(1)
		s.metrics.lastContentSet.Store(time.Now().UnixMilli())
		return snapshot, true
	}
	s.writeError(w, http.StatusBadRequest, "contentVersion or bundle is required")
	return nil, false
}

func (s *server) resolveRunbookContent(
	w http.ResponseWriter,
	request lookupRequest,
) (*contentSnapshot, bool) {
	if request.ContentVersion != "" {
		if snapshot, ok := s.store.get(request.ContentVersion); ok {
			return snapshot, true
		}
		if request.Bootstrap == nil {
			s.writeError(w, http.StatusConflict, "contentVersion is not synced")
			return nil, false
		}
	}
	if request.Bootstrap != nil {
		snapshot, err := s.store.sync(*request.Bootstrap)
		if err != nil {
			s.writeError(w, http.StatusBadRequest, err.Error())
			return nil, false
		}
		s.metrics.contentSyncs.Add(1)
		s.metrics.lastContentSet.Store(time.Now().UnixMilli())
		return snapshot, true
	}
	s.writeError(w, http.StatusBadRequest, "contentVersion or bootstrap is required")
	return nil, false
}

func (s *server) cardsGenerate(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var request cardsGenerateRequest
	if !s.decodeJSON(w, r, maxContentSyncBytes, &request) {
		return
	}
	snapshot, ok := s.resolveLearningContent(
		w,
		request.ContentVersion,
		request.Bundle,
	)
	if !ok {
		return
	}
	materials := selectLearningMaterials(snapshot, request.MaterialIDs)
	if len(materials) == 0 {
		s.writeError(w, http.StatusBadRequest, "no source materials were found for card generation")
		return
	}
	if strings.TrimSpace(os.Getenv("DEVQRH_LLM_API_KEY")) == "" {
		s.writeError(w, http.StatusServiceUnavailable, "LLM provider is not configured; card generation is unavailable")
		return
	}
	limit := request.Limit
	if limit <= 0 || limit > 20 {
		limit = 6
	}
	writeJSON(w, GeneratedCardsResponse{
		MaterialIDs: learningMaterialIDs(materials),
		Cards:       generateLearningCards(materials, limit),
		Mode:        "llm",
		Notice:      "Generated with sidecar local heuristics; no remote model call was made in this build.",
	})
}

func (s *server) reviewSchedule(w http.ResponseWriter, r *http.Request) {
	s.metrics.requests.Add(1)
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var request reviewScheduleRequest
	if !s.decodeJSON(w, r, 1<<20, &request) {
		return
	}
	grade := strings.ToLower(strings.TrimSpace(request.Grade))
	switch grade {
	case "again", "hard", "good", "easy":
	default:
		s.writeError(w, http.StatusBadRequest, "grade must be one of again, hard, good, easy")
		return
	}
	now := time.Now()
	if request.Now > 0 {
		now = time.UnixMilli(request.Now)
	}
	writeJSON(w, scheduleLearningReview(request.State, grade, now))
}
