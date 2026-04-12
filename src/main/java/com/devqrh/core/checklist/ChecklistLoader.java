package com.devqrh.core.checklist;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

@Component
public class ChecklistLoader {

    private final ObjectMapper objectMapper;
    private final Path dataPath;

    public ChecklistLoader(@Value("${devqrh.data-path:data}") String dataPath) {
        this.objectMapper = new ObjectMapper(new YAMLFactory());
        this.objectMapper.setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE);
        this.dataPath = Path.of(dataPath);
    }

    public List<Checklist> loadAll() {
        if (Files.isDirectory(dataPath)) {
            return loadFromFileSystem();
        }
        return loadFromClasspath();
    }

    public String sourceLocation() {
        return Files.isDirectory(dataPath)
                ? dataPath.toAbsolutePath().normalize().toString()
                : "classpath:data";
    }

    private List<Checklist> loadFromFileSystem() {
        try (Stream<Path> pathStream = Files.list(dataPath)) {
            List<Checklist> loaded = new ArrayList<>();
            pathStream
                    .filter(path -> path.getFileName().toString().endsWith(".yaml"))
                    .sorted()
                    .forEach(path -> loaded.add(readResource(new FileSystemResource(path))));
            loaded.sort(Comparator.comparing(Checklist::getId));
            return List.copyOf(loaded);
        } catch (IOException exception) {
            throw new UncheckedIOException("Failed to load checklists from " + dataPath, exception);
        }
    }

    private List<Checklist> loadFromClasspath() {
        try {
            Resource[] resources = new PathMatchingResourcePatternResolver().getResources("classpath:data/*.yaml");
            List<Checklist> loaded = new ArrayList<>();
            for (Resource resource : resources) {
                loaded.add(readResource(resource));
            }
            loaded.sort(Comparator.comparing(Checklist::getId));
            return List.copyOf(loaded);
        } catch (IOException exception) {
            throw new UncheckedIOException("Failed to load checklists", exception);
        }
    }

    private Checklist readResource(Resource resource) {
        try (InputStream inputStream = resource.getInputStream()) {
            return objectMapper.readValue(inputStream, Checklist.class);
        } catch (IOException exception) {
            throw new UncheckedIOException("Failed to read checklist resource", exception);
        }
    }
}
