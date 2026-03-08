package com.doublez.pocketmindserver.sync.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.Map;

/**
 * Push 请求中的单条变更 DTO，字段命名与 Flutter {@code SyncMutationDto.toJson} 严格对齐。
 * <p>
 * 规则：
 * <ul>
 *   <li>create / update：{@code payload} 包含实体完整字段快照</li>
 *   <li>delete：{@code payload} 为空 map {@code {}}</li>
 * </ul>
 * </p>
 */
public record SyncMutationDto(
        /** 客户端幂等键（UUID v4），后端以此去重防止重试风暴 */
        @NotBlank String mutationId,
        /** 实体类型：'note' | 'category' */
        @NotBlank String entityType,
        /** 业务实体 UUID 字符串 */
        @NotBlank String entityUuid,
        /** 操作类型：'create' | 'update' | 'delete' */
        @NotBlank String operation,
        /** 客户端写入时刻毫秒时间戳，作为 LWW 裁决依据 */
        @PositiveOrZero long updatedAt,
        /** 实体完整字段 map；delete 时为 {} */
        @NotNull Map<String, Object> payload
) {}
