package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import com.doublez.pocketmindserver.shared.infra.mybatis.VectorTypeHandler;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

/**
 * context_catalog 表 MyBatis-Plus 持久化模型。
 */
@Data
@TableName(value = "context_catalog", autoResultMap = true)
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
    private String abstractText;
    private String layer;
    private String status;
    private Boolean isLeaf;
    private Long activeCount;

    @TableField(typeHandler = VectorTypeHandler.class)
    private float[] embedding;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
