package com.javacourse.controller;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 健康检查
 */
@RestController
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> m = new HashMap<>();
        m.put("status", "UP");
        m.put("service", "javacourse-server");
        try {
            jdbc.queryForObject("select 1", Integer.class);
            m.put("database", "UP");
        } catch (Exception e) {
            m.put("database", "DOWN: " + e.getMessage());
        }
        return m;
    }
}
