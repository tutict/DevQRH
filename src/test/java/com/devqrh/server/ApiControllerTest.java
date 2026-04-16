package com.devqrh.server;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ApiControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void exposesHealthEndpoint() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"))
                .andExpect(jsonPath("$.checklistCount", greaterThan(0)))
                .andExpect(jsonPath("$.synonymGroupCount", greaterThan(0)))
                .andExpect(jsonPath("$.partialMinLength").value(3));
    }

    @Test
    void returnsStructuredNotFoundForMissingChecklist() throws Exception {
        mockMvc.perform(get("/api/checklists/missing_checklist"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("not_found"))
                .andExpect(jsonPath("$.message").value("Checklist not found: missing_checklist"))
                .andExpect(jsonPath("$.path").value("/api/checklists/missing_checklist"))
                .andExpect(jsonPath("$.timestamp").value(notNullValue()));
    }
}
