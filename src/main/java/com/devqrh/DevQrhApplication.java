package com.devqrh;

import com.devqrh.cli.AgentCommand;
import com.devqrh.cli.AskCommand;
import com.devqrh.cli.RootCommand;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import picocli.CommandLine;

import java.util.Arrays;
import java.util.Map;

@SpringBootApplication
public class DevQrhApplication {

    public static void main(String[] args) {
        if (args.length > 0 && "serve".equalsIgnoreCase(args[0])) {
            SpringApplication.run(DevQrhApplication.class, Arrays.copyOfRange(args, 1, args.length));
            return;
        }

        SpringApplication application = new SpringApplication(DevQrhApplication.class);
        application.setWebApplicationType(WebApplicationType.NONE);
        application.setLogStartupInfo(false);
        application.setDefaultProperties(Map.of(
                "spring.main.banner-mode", "off",
                "logging.level.root", "ERROR"
        ));

        try (ConfigurableApplicationContext context = application.run()) {
            CommandLine commandLine = new CommandLine(context.getBean(RootCommand.class));
            commandLine.addSubcommand("ask", context.getBean(AskCommand.class));
            commandLine.addSubcommand("agent", context.getBean(AgentCommand.class));
            int exitCode = commandLine.execute(args);
            System.exit(exitCode);
        }
    }
}
