package com.doublez.pocketmindserver.auth.infra.persistence;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@TableName("users")
public class UserAccount {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;

    private String username;

    @TableField("password_hash")
    private String passwordHash;

    @TableField("created_at")
    private LocalDateTime createdAt;

    @TableField("updated_at")
    private Long updatedAt;

    @TableLogic
    @TableField("is_deleted")
    private Boolean isDeleted;
}
