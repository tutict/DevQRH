package com.devqrh.server;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = "devqrh.health.include-source-locations=false")
@AutoConfigureMockMvc
class HealthControllerProdViewTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void hidesSourceLocationsWhenDisabled() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"))
                .andExpect(jsonPath("$.checklistSource").doesNotExist())
                .andExpect(jsonPath("$.matcherConfigSource").doesNotExist());
    }
}
