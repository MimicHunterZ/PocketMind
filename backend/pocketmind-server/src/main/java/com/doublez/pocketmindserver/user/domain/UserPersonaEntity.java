package com.doublez.pocketmindserver.user.domain;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.experimental.Accessors;

import java.time.OffsetDateTime;

@Data
@Accessors(chain = true)
@TableName("user_personas")
public class UserPersonaEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private String name;

    private String systemPrompt;

    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}