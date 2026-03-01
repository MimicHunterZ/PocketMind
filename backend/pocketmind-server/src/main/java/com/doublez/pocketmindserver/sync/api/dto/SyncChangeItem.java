package com.doublez.pocketmindserver.sync.api.dto;

import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 单条同步变更条目
 * payload 为动态字段，不同 entityType 有不同结构
 */
@Data
public class SyncChangeItem {

    @NotBlank
    private String entityType;

    @NotNull
    private UUID uuid;

    /** upsert | delete */
    @NotBlank
    private String op;

    /** 毫秒时间戳 */
    private long updatedAt;

    /** 动态 payload（根据 entityType 结构不同） */
    private Map<String, Object> payload = new HashMap<>();

    @JsonAnyGetter
    public Map<String, Object> getPayload() { return payload; }

    @JsonAnySetter
    public void setPayload(String key, Object value) {
        if (!"entityType".equals(key) && !"uuid".equals(key)
                && !"op".equals(key) && !"updatedAt".equals(key)) {
            this.payload.put(key, value);
        }
    }
}
