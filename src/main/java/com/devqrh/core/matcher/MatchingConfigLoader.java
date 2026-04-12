package com.devqrh.core.matcher;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;

@Component
public class MatchingConfigLoader {

    private final ObjectMapper objectMapper;
    private final Path configPath;

    public MatchingConfigLoader(@Value("${devqrh.matcher-config-path:src/main/resources/matcher/matching-config.yaml}") String configPath) {
        this.objectMapper = new ObjectMapper(new YAMLFactory());
        this.objectMapper.setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE);
        this.configPath = Path.of(configPath);
    }

    public MatchingConfig loadConfig() {
        Resource resource = Files.exists(configPath)
                ? new FileSystemResource(configPath)
                : new ClassPathResource("matcher/matching-config.yaml");

        try (InputStream inputStream = resource.getInputStream()) {
            return objectMapper.readValue(inputStream, MatchingConfig.class);
        } catch (IOException exception) {
            throw new UncheckedIOException("Failed to load matching config", exception);
        }
    }

    public String sourceLocation() {
        return Files.exists(configPath)
                ? configPath.toAbsolutePath().normalize().toString()
                : "classpath:matcher/matching-config.yaml";
    }
}
