package com.doublez.pocketmindserver.sync.infra.persistence;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.experimental.Accessors;

import java.time.Instant;
import java.util.UUID;

/**
 * sync_change_log 持久化模型。
 * <p>
 * 每条记录代表一次业务实体的变更事件；{@code id} 即为服务端单调递增版本号（serverVersion）。
 * </p>
 */
@Data
@Accessors(chain = true)
@TableName("sync_change_log")
public class SyncChangeLogModel {

    /**
     * 服务端版本号，AUTO_INCREMENT 严格单调递增，直接作为 Pull 游标。
     */
    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** 实体类型：'note' | 'category' */
    private String entityType;

    /** 业务实体 UUID */
    private UUID entityUuid;

    /** 操作类型：'create' | 'update' | 'delete' */
    private String operation;

    /**
     * 业务实体 updatedAt 毫秒时间戳，作为 LWW 裁决依据。
     * AI 回调触发的写入使用写入时刻，不修改原始 note.updatedAt。
     */
    private Long updatedAt;

    /**
     * 客户端幂等键（UUID v4）；AI 或后端系统触发的写入为 NULL。
     * 数据库层面具有 UNIQUE 约束，保证同一 mutationId 只记录一次。
     */
    private String clientMutationId;

    /**
     * 实体完整 JSON 快照；delete 操作时为 NULL。
     * 字段名与 Flutter Pull DTO 保持对齐，便于客户端直接反序列化。
     */
    private String payload;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;
}
