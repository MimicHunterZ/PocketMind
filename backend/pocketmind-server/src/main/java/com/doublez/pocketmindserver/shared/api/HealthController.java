package com.doublez.pocketmindserver.shared.api;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/health")
@RestController
public class HealthController {

    @RequestMapping("/check")
    public String checkHealth() {
        return "OK";
    }
}
