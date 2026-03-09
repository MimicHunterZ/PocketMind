package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

/**
 * context_ref 表 MyBatis-Plus 持久化模型。
 */
@Data
@TableName("context_ref")
public class ContextRefModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private String contextUri;
    private String bizType;
    private String bizId;
    private UUID noteUuid;
    private UUID sessionUuid;
    private UUID messageUuid;
    private UUID assetUuid;
    private String sourceUrl;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
