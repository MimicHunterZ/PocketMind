package com.doublez.pocketmindserver.note.infra.persistence.tag;

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
 * 标签持久化模型（对应 tags 表）
 */
@Data
@TableName("tags")
public class TagModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;

    private Long userId;

    private String name;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
