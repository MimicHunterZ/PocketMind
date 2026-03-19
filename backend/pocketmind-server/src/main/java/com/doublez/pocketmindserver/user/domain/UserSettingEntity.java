package com.doublez.pocketmindserver.user.domain;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.experimental.Accessors;

import java.time.OffsetDateTime;

@Data
@Accessors(chain = true)
@TableName("user_settings")
public class UserSettingEntity {

    /**
     * 用户ID (主键)
     */
    @TableId(type = IdType.INPUT)
    private Long userId;

    /**
     * 用户自定义的 AI 系统提示词
     */
    private String customSystemPrompt;

    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private OffsetDateTime updatedAt;
}
