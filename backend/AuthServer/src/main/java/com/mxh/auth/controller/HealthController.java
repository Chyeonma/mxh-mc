package com.mxh.auth.controller;

import com.mxh.auth.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/health")
public class HealthController {

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkHealth() {
        Map<String, Object> status = new HashMap<>();
        status.put("service", "auth-service");
        status.put("status", "UP");
        status.put("timestamp", System.currentTimeMillis());

        return ResponseEntity.ok(ApiResponse.success("Dịch vụ AuthServer hoạt động bình thường", status));
    }
}
