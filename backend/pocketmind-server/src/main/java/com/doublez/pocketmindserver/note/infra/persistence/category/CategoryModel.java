package com.doublez.pocketmindserver.note.infra.persistence.category;

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
 * 分类持久化模型（对应 categories 表）
 */
@Data
@TableName("categories")
public class CategoryModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;

    private Long userId;

    private String name;

    /** 分类描述 */
    private String description;

    /** 图标路径 */
    private String iconPath;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;

    /** 服务端同步版本号（sync_change_log.id） */
    private Long serverVersion;
}
