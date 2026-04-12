package com.devqrh.cli;

import com.devqrh.agent.NavigatorResponse;
import com.devqrh.agent.NavigatorService;
import com.devqrh.core.matcher.MatchResult;
import org.springframework.stereotype.Component;
import picocli.CommandLine.Command;
import picocli.CommandLine.Parameters;
import picocli.CommandLine.Spec;
import picocli.CommandLine.Model.CommandSpec;

@Component
@Command(name = "agent", mixinStandardHelpOptions = true, description = "Clarify intent and suggest checklist")
public class AgentCommand implements Runnable {

    private final NavigatorService navigatorService;

    @Parameters(index = "0", description = "Symptom query")
    private String query;

    @Spec
    private CommandSpec spec;

    public AgentCommand(NavigatorService navigatorService) {
        this.navigatorService = navigatorService;
    }

    @Override
    public void run() {
        NavigatorResponse response = navigatorService.navigate(query);
        spec.commandLine().getOut().printf("QUERY %s%n", response.query());
        if (response.bestMatch() != null) {
            spec.commandLine().getOut().printf("BEST %s | %s | %.2f%n",
                    response.bestMatch().checklist().getId(),
                    response.bestMatch().checklist().getTitle(),
                    response.bestMatch().score());
        }
        spec.commandLine().getOut().println("CANDIDATES");
        for (int i = 0; i < response.candidates().size(); i++) {
            MatchResult match = response.candidates().get(i);
            spec.commandLine().getOut().printf("%d. %s | %s | %.2f%n",
                    i + 1,
                    match.checklist().getId(),
                    match.checklist().getTitle(),
                    match.score());
        }
        spec.commandLine().getOut().println("CLARIFY");
        for (String clarify : response.clarifiers()) {
            spec.commandLine().getOut().printf("- %s%n", clarify);
        }
    }
}
