package com.devqrh.server;

import com.devqrh.agent.NavigatorResponse;
import com.devqrh.agent.NavigatorService;
import com.devqrh.core.checklist.Checklist;
import com.devqrh.core.engine.LookupResult;
import com.devqrh.core.engine.LookupService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class LookupController {

    private final LookupService lookupService;
    private final NavigatorService navigatorService;
    private final ReloadService reloadService;
    private final ContentSyncService contentSyncService;

    public LookupController(LookupService lookupService,
                            NavigatorService navigatorService,
                            ReloadService reloadService,
                            ContentSyncService contentSyncService) {
        this.lookupService = lookupService;
        this.navigatorService = navigatorService;
        this.reloadService = reloadService;
        this.contentSyncService = contentSyncService;
    }

    @GetMapping("/lookup")
    public LookupResult lookup(@RequestParam("q") String query,
                               @RequestParam(name = "top", defaultValue = "3") int top) {
        return lookupService.lookup(query, top);
    }

    @GetMapping("/agent/navigate")
    public NavigatorResponse navigate(@RequestParam("q") String query) {
        return navigatorService.navigate(query);
    }

    @GetMapping("/checklists/{id}")
    public Checklist checklist(@PathVariable String id) {
        return lookupService.getChecklist(id);
    }

    @GetMapping("/mobile/manifest")
    public ContentManifestResponse manifest() {
        return contentSyncService.manifest();
    }

    @GetMapping("/mobile/bootstrap")
    public ContentBootstrapResponse bootstrap() {
        return contentSyncService.bootstrap();
    }

    @PostMapping("/admin/reload")
    public ReloadResponse reload() {
        return reloadService.reload();
    }
}
