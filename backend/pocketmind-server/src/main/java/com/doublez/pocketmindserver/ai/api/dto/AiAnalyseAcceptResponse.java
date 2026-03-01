package com.doublez.pocketmindserver.ai.api.dto;

import java.util.UUID;

public record AiAnalyseAcceptResponse(
        UUID uuid,
        String url
) {
}
