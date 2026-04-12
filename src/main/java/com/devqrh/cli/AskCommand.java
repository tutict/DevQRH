package com.devqrh.cli;

import com.devqrh.core.checklist.ChecklistBranch;
import com.devqrh.core.checklist.ChecklistStep;
import com.devqrh.core.engine.LookupResult;
import com.devqrh.core.engine.LookupService;
import com.devqrh.core.matcher.MatchResult;
import org.springframework.stereotype.Component;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;
import picocli.CommandLine.Spec;
import picocli.CommandLine.Model.CommandSpec;

import java.util.List;

@Component
@Command(name = "ask", mixinStandardHelpOptions = true, description = "Find the best checklist")
public class AskCommand implements Runnable {

    private final LookupService lookupService;

    @Parameters(index = "0", description = "Symptom query")
    private String query;

    @Option(names = "--top", defaultValue = "3", description = "Candidate count")
    private int top;

    @Spec
    private CommandSpec spec;

    public AskCommand(LookupService lookupService) {
        this.lookupService = lookupService;
    }

    @Override
    public void run() {
        LookupResult result = lookupService.lookup(query, top);
        if (result.bestMatch() == null) {
            spec.commandLine().getOut().println("NO_MATCH");
            return;
        }

        MatchResult best = result.candidates().get(0);
        spec.commandLine().getOut().printf("BEST %s | %s | %.2f%n",
                best.checklist().getId(),
                best.checklist().getTitle(),
                best.score());
        printList("SYMPTOMS", best.checklist().getSymptoms());
        printSteps("IMMEDIATE_ACTIONS", best.checklist().getImmediateActions());
        printDecisionTree("DECISION_TREE", best.checklist().getDecisionTree());
        printList("ROOT_CAUSE", best.checklist().getRootCause());
        printList("LONG_TERM_FIX", best.checklist().getLongTermFix());
        printCandidates(result.candidates());
    }

    private void printList(String label, List<String> items) {
        spec.commandLine().getOut().println(label);
        for (String item : items) {
            spec.commandLine().getOut().printf("- %s%n", item);
        }
    }

    private void printSteps(String label, List<ChecklistStep> items) {
        spec.commandLine().getOut().println(label);
        for (ChecklistStep item : items) {
            spec.commandLine().getOut().printf("%d. %s%n", item.getStep(), item.getAction());
        }
    }

    private void printDecisionTree(String label, List<ChecklistBranch> items) {
        spec.commandLine().getOut().println(label);
        for (ChecklistBranch item : items) {
            spec.commandLine().getOut().printf("- if %s -> %s%n", item.getCondition(), item.getAction());
        }
    }

    private void printCandidates(List<MatchResult> candidates) {
        spec.commandLine().getOut().println("CANDIDATES");
        for (int i = 0; i < candidates.size(); i++) {
            MatchResult match = candidates.get(i);
            spec.commandLine().getOut().printf("%d. %s | %s | %.2f%n",
                    i + 1,
                    match.checklist().getId(),
                    match.checklist().getTitle(),
                    match.score());
        }
    }
}
