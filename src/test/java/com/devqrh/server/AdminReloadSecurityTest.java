package com.devqrh.server;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "devqrh.admin.reload.require-token=true",
        "devqrh.admin.reload.token=test-secret"
})
@AutoConfigureMockMvc
class AdminReloadSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void rejectsReloadWithoutAdminToken() throws Exception {
        mockMvc.perform(post("/api/admin/reload"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("unauthorized"))
                .andExpect(jsonPath("$.message").value("Admin token required"));
    }

    @Test
    void allowsReloadWithAdminToken() throws Exception {
        mockMvc.perform(post("/api/admin/reload").header("X-Admin-Token", "test-secret"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.checklistCount").isNumber())
                .andExpect(jsonPath("$.synonymGroupCount").isNumber());
    }
}
