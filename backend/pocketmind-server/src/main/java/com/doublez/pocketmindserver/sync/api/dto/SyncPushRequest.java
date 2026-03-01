package com.doublez.pocketmindserver.sync.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * 客户端 push 请求体
 */
public record SyncPushRequest(
        @NotNull @Valid List<SyncChangeItem> changes
) {
}
