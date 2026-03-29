package com.doublez.pocketmindserver.resource.infra.persistence;

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
 * resource_index_outbox 持久化模型。
 */
@Data
@Accessors(chain = true)
@TableName("resource_index_outbox")
public class ResourceIndexOutboxModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID resourceUuid;
    private String operation;
    private String status;
    private Integer retryCount;
    private Long retryAfter;
    private String lastError;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;
}
