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
 * context_catalog 表 MyBatis-Plus 持久化模型。
 */
@Data
@TableName("context_catalog")
public class ContextCatalogModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private String contextType;
    private String subType;
    private String uri;
    private String parentUri;
    private String name;
    private String description;
    private String layer;
    private String status;
    private Boolean isLeaf;
    private Long activeCount;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
