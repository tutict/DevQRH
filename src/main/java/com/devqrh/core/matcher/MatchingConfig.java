package com.devqrh.core.matcher;

import java.util.ArrayList;
import java.util.List;

public class MatchingConfig {

    private int partialMinLength = 3;
    private List<List<String>> synonymGroups = new ArrayList<>();
    private Weights weights = new Weights();

    public int getPartialMinLength() {
        return partialMinLength;
    }

    public void setPartialMinLength(int partialMinLength) {
        this.partialMinLength = partialMinLength;
    }

    public List<List<String>> getSynonymGroups() {
        return synonymGroups;
    }

    public void setSynonymGroups(List<List<String>> synonymGroups) {
        this.synonymGroups = synonymGroups;
    }

    public Weights getWeights() {
        return weights;
    }

    public void setWeights(Weights weights) {
        this.weights = weights;
    }

    public static class Weights {

        private double exactQueryId = 1.0;
        private double exactIdToken = 1.0;
        private double exactTitleToken = 0.95;
        private double exactKeywordToken = 0.90;
        private double exactSymptomToken = 0.78;
        private double exactContextToken = 0.60;
        private double synonymKeyword = 0.72;
        private double synonymPrimary = 0.62;
        private double synonymAny = 0.50;
        private double partialKeyword = 0.48;
        private double partialPrimary = 0.40;
        private double partialAny = 0.28;
        private double tokenAverage = 0.88;
        private double keywordCoverage = 0.12;
        private double exactTitleBoost = 0.12;
        private double partialTitleBoost = 0.07;
        private double partialIdBoost = 0.07;
        private double phraseBoost = 0.04;

        public double getExactQueryId() {
            return exactQueryId;
        }

        public void setExactQueryId(double exactQueryId) {
            this.exactQueryId = exactQueryId;
        }

        public double getExactIdToken() {
            return exactIdToken;
        }

        public void setExactIdToken(double exactIdToken) {
            this.exactIdToken = exactIdToken;
        }

        public double getExactTitleToken() {
            return exactTitleToken;
        }

        public void setExactTitleToken(double exactTitleToken) {
            this.exactTitleToken = exactTitleToken;
        }

        public double getExactKeywordToken() {
            return exactKeywordToken;
        }

        public void setExactKeywordToken(double exactKeywordToken) {
            this.exactKeywordToken = exactKeywordToken;
        }

        public double getExactSymptomToken() {
            return exactSymptomToken;
        }

        public void setExactSymptomToken(double exactSymptomToken) {
            this.exactSymptomToken = exactSymptomToken;
        }

        public double getExactContextToken() {
            return exactContextToken;
        }

        public void setExactContextToken(double exactContextToken) {
            this.exactContextToken = exactContextToken;
        }

        public double getSynonymKeyword() {
            return synonymKeyword;
        }

        public void setSynonymKeyword(double synonymKeyword) {
            this.synonymKeyword = synonymKeyword;
        }

        public double getSynonymPrimary() {
            return synonymPrimary;
        }

        public void setSynonymPrimary(double synonymPrimary) {
            this.synonymPrimary = synonymPrimary;
        }

        public double getSynonymAny() {
            return synonymAny;
        }

        public void setSynonymAny(double synonymAny) {
            this.synonymAny = synonymAny;
        }

        public double getPartialKeyword() {
            return partialKeyword;
        }

        public void setPartialKeyword(double partialKeyword) {
            this.partialKeyword = partialKeyword;
        }

        public double getPartialPrimary() {
            return partialPrimary;
        }

        public void setPartialPrimary(double partialPrimary) {
            this.partialPrimary = partialPrimary;
        }

        public double getPartialAny() {
            return partialAny;
        }

        public void setPartialAny(double partialAny) {
            this.partialAny = partialAny;
        }

        public double getTokenAverage() {
            return tokenAverage;
        }

        public void setTokenAverage(double tokenAverage) {
            this.tokenAverage = tokenAverage;
        }

        public double getKeywordCoverage() {
            return keywordCoverage;
        }

        public void setKeywordCoverage(double keywordCoverage) {
            this.keywordCoverage = keywordCoverage;
        }

        public double getExactTitleBoost() {
            return exactTitleBoost;
        }

        public void setExactTitleBoost(double exactTitleBoost) {
            this.exactTitleBoost = exactTitleBoost;
        }

        public double getPartialTitleBoost() {
            return partialTitleBoost;
        }

        public void setPartialTitleBoost(double partialTitleBoost) {
            this.partialTitleBoost = partialTitleBoost;
        }

        public double getPartialIdBoost() {
            return partialIdBoost;
        }

        public void setPartialIdBoost(double partialIdBoost) {
            this.partialIdBoost = partialIdBoost;
        }

        public double getPhraseBoost() {
            return phraseBoost;
        }

        public void setPhraseBoost(double phraseBoost) {
            this.phraseBoost = phraseBoost;
        }
    }
}
