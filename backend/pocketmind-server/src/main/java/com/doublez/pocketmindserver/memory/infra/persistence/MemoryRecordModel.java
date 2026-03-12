package com.doublez.pocketmindserver.memory.infra.persistence;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import com.doublez.pocketmindserver.memory.domain.MemoryEvidence;
import com.doublez.pocketmindserver.shared.infra.mybatis.VectorTypeHandler;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * memory_records 表的 MyBatis-Plus 持久化模型。
 */
@Data
@TableName(value = "memory_records", autoResultMap = true)
public class MemoryRecordModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private Long tenantId;

    /** 空间类型：USER / AGENT / TENANT 等 */
    private String spaceType;

    /** 记忆类型：PROFILE / PREFERENCES / ENTITIES / EVENTS 等 */
    private String memoryType;

    /** 上下文 URI */
    private String rootUri;

    private String title;

    /** L0 摘要 */
    private String abstractText;

    /** L1 结构化概览 */
    private String summaryText;

    /** L2 完整内容 */
    private String content;

    /** 来源上下文 URI */
    private String sourceContextUri;

    /** 证据引用列表（JSONB） */
    @TableField(value = "evidence_refs", typeHandler = MemoryEvidenceJsonbTypeHandler.class)
    private List<MemoryEvidence> evidenceRefs;

    /** 去重合并键 */
    private String mergeKey;

    /** 置信度 */
    private BigDecimal confidenceScore;

    /** 引用热度 */
    private Long activeCount;

    /** 最后验证时间 */
    private Long lastValidatedAt;

    /** pgvector 语义向量 */
    @TableField(typeHandler = VectorTypeHandler.class)
    private float[] embedding;

    /** 状态 */
    private String status;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
