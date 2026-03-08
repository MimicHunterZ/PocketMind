package com.doublez.pocketmindserver.sync.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Push 接口请求体，字段命名与 Flutter {@code SyncPushRequest.toJson} 严格对齐。
 */
public record SyncPushRequest(
        @NotNull @NotEmpty List<@Valid SyncMutationDto> mutations
) {}
