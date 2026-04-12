package com.devqrh.server;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardWatchEventKinds;
import java.nio.file.WatchEvent;
import java.nio.file.WatchKey;
import java.nio.file.WatchService;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

@Component
@ConditionalOnWebApplication
@ConditionalOnProperty(value = "devqrh.auto-reload.enabled", havingValue = "true", matchIfMissing = true)
public class AutoReloadWatcher {

    private static final Logger log = LoggerFactory.getLogger(AutoReloadWatcher.class);

    private final ReloadService reloadService;
    private final Path dataPath;
    private final Path matcherConfigPath;
    private final long debounceMs;
    private final AtomicBoolean running;
    private final ExecutorService executorService;
    private final Map<WatchKey, Path> watchRoots;

    private WatchService watchService;

    public AutoReloadWatcher(ReloadService reloadService,
                             @Value("${devqrh.data-path:data}") String dataPath,
                             @Value("${devqrh.matcher-config-path:src/main/resources/matcher/matching-config.yaml}") String matcherConfigPath,
                             @Value("${devqrh.auto-reload.debounce-ms:500}") long debounceMs) {
        this.reloadService = reloadService;
        this.dataPath = Path.of(dataPath).toAbsolutePath().normalize();
        this.matcherConfigPath = Path.of(matcherConfigPath).toAbsolutePath().normalize();
        this.debounceMs = debounceMs;
        this.running = new AtomicBoolean(false);
        this.executorService = Executors.newSingleThreadExecutor(runnable -> {
            Thread thread = new Thread(runnable, "devqrh-auto-reload");
            thread.setDaemon(true);
            return thread;
        });
        this.watchRoots = new HashMap<>();
    }

    @PostConstruct
    public void start() {
        try {
            this.watchService = FileSystems.getDefault().newWatchService();
            int registrations = registerWatchTargets();
            if (registrations == 0) {
                closeWatchService();
                log.info("Auto reload skipped: no local watch targets found");
                return;
            }

            running.set(true);
            executorService.submit(this::watchLoop);
            log.info("Auto reload enabled for {} target(s)", registrations);
        } catch (IOException exception) {
            throw new UncheckedIOException("Failed to start auto reload watcher", exception);
        }
    }

    @PreDestroy
    public void stop() {
        running.set(false);
        closeWatchService();
        executorService.shutdownNow();
        try {
            executorService.awaitTermination(3, TimeUnit.SECONDS);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
        }
    }

    private int registerWatchTargets() throws IOException {
        int count = 0;
        if (Files.isDirectory(dataPath)) {
            register(dataPath);
            count++;
        }

        Path configDirectory = matcherConfigPath.getParent();
        if (configDirectory != null && Files.isDirectory(configDirectory) && !configDirectory.equals(dataPath)) {
            register(configDirectory);
            count++;
        }
        return count;
    }

    private void register(Path directory) throws IOException {
        WatchKey watchKey = directory.register(
                watchService,
                StandardWatchEventKinds.ENTRY_CREATE,
                StandardWatchEventKinds.ENTRY_MODIFY,
                StandardWatchEventKinds.ENTRY_DELETE
        );
        watchRoots.put(watchKey, directory);
    }

    private void watchLoop() {
        while (running.get()) {
            WatchKey watchKey;
            try {
                watchKey = watchService.take();
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                return;
            } catch (Exception exception) {
                if (running.get()) {
                    log.warn("Auto reload watcher stopped unexpectedly", exception);
                }
                return;
            }

            Path root = watchRoots.get(watchKey);
            boolean shouldReload = false;
            if (root != null) {
                for (WatchEvent<?> event : watchKey.pollEvents()) {
                    if (event.kind() == StandardWatchEventKinds.OVERFLOW) {
                        continue;
                    }
                    Path changedPath = root.resolve((Path) event.context()).toAbsolutePath().normalize();
                    if (isRelevant(changedPath)) {
                        shouldReload = true;
                    }
                }
            }

            boolean valid = watchKey.reset();
            if (!valid) {
                watchRoots.remove(watchKey);
            }

            if (shouldReload) {
                triggerReload();
            }
        }
    }

    private boolean isRelevant(Path changedPath) {
        if (changedPath.startsWith(dataPath)) {
            String fileName = changedPath.getFileName().toString().toLowerCase();
            return fileName.endsWith(".yaml");
        }
        return changedPath.equals(matcherConfigPath);
    }

    private void triggerReload() {
        try {
            Thread.sleep(debounceMs);
            ReloadResponse response = reloadService.reload();
            log.info("Auto reload complete: {} checklists, {} synonym groups",
                    response.checklistCount(),
                    response.synonymGroupCount());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
        } catch (RuntimeException exception) {
            log.warn("Auto reload failed", exception);
        }
    }

    private void closeWatchService() {
        if (watchService == null) {
            return;
        }
        try {
            watchService.close();
        } catch (IOException exception) {
            log.debug("Failed to close watch service cleanly", exception);
        }
    }
}
