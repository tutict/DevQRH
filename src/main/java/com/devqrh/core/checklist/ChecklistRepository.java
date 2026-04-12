package com.devqrh.core.checklist;

import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

@Repository
public class ChecklistRepository {

    private final ChecklistLoader loader;
    private final AtomicReference<List<Checklist>> checklists;

    public ChecklistRepository(ChecklistLoader loader) {
        this.loader = loader;
        this.checklists = new AtomicReference<>(loader.loadAll());
    }

    public List<Checklist> findAll() {
        return checklists.get();
    }

    public Optional<Checklist> findById(String id) {
        return checklists.get().stream()
                .filter(checklist -> checklist.getId().equalsIgnoreCase(id))
                .findFirst();
    }

    public int reload() {
        List<Checklist> reloaded = loader.loadAll();
        checklists.set(reloaded);
        return reloaded.size();
    }

    public String sourceLocation() {
        return loader.sourceLocation();
    }
}
