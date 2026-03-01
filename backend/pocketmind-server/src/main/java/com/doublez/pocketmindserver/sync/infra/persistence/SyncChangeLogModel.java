package com.doublez.pocketmindserver.sync.infra.persistence;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.util.UUID;

/**
 * sync_change_log 表的 MyBatis-Plus 模型
 * 记录数据变更事件，用于客户端增量 pull
 */
@Data
@TableName("sync_change_log")
public class SyncChangeLogModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** 实体类型: note | attachment | vision | chat_message | chat_session */
    private String entityType;

    private UUID entityUuid;

    /** 操作: upsert | delete */
    private String op;

    /** 毫秒时间戳，客户端以此作为 cursor */
    private Long updatedAt;
}
