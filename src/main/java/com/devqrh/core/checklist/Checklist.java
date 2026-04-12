package com.devqrh.core.checklist;

import java.util.ArrayList;
import java.util.List;

public class Checklist {

    private String id;
    private String title;
    private List<String> keywords = new ArrayList<>();
    private List<String> symptoms = new ArrayList<>();
    private List<ChecklistStep> immediateActions = new ArrayList<>();
    private List<ChecklistBranch> decisionTree = new ArrayList<>();
    private List<String> rootCause = new ArrayList<>();
    private List<String> longTermFix = new ArrayList<>();

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public List<String> getKeywords() {
        return keywords;
    }

    public void setKeywords(List<String> keywords) {
        this.keywords = keywords;
    }

    public List<String> getSymptoms() {
        return symptoms;
    }

    public void setSymptoms(List<String> symptoms) {
        this.symptoms = symptoms;
    }

    public List<ChecklistStep> getImmediateActions() {
        return immediateActions;
    }

    public void setImmediateActions(List<ChecklistStep> immediateActions) {
        this.immediateActions = immediateActions;
    }

    public List<ChecklistBranch> getDecisionTree() {
        return decisionTree;
    }

    public void setDecisionTree(List<ChecklistBranch> decisionTree) {
        this.decisionTree = decisionTree;
    }

    public List<String> getRootCause() {
        return rootCause;
    }

    public void setRootCause(List<String> rootCause) {
        this.rootCause = rootCause;
    }

    public List<String> getLongTermFix() {
        return longTermFix;
    }

    public void setLongTermFix(List<String> longTermFix) {
        this.longTermFix = longTermFix;
    }
}
