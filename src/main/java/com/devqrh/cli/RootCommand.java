package com.devqrh.cli;

import org.springframework.stereotype.Component;
import picocli.CommandLine.Command;
import picocli.CommandLine.Spec;
import picocli.CommandLine.Model.CommandSpec;

@Component
@Command(
        name = "devqrh",
        mixinStandardHelpOptions = true,
        description = "Developer Quick Reference Handbook",
        synopsisSubcommandLabel = "COMMAND",
        commandListHeading = "%nCommands:%n"
)
public class RootCommand implements Runnable {

    @Spec
    private CommandSpec spec;

    @Override
    public void run() {
        spec.commandLine().usage(spec.commandLine().getOut());
    }
}
