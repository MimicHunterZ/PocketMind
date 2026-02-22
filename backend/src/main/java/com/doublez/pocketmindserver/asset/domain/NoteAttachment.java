package com.doublez.pocketmindserver.asset.domain;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

/**
 * note_attachments 表映射（新版）。
 *
 * <p>与旧版 AttachmentModel 共用同一张表，但新增了 size（文件字节数）
 * 和 originalFileName（原始文件名）字段，专用于图片资产上传管线。</p>
 *
 * <p>主键策略：使用 {@code uuid UUID} 作为业务主键（IdType.INPUT：由 Java 生成后写入），
 * 数据库侧的自增 {@code id BIGSERIAL} 列不在此模型中声明，由 DB 自动填充。</p>
 */
@Data
@TableName("note_attachments")
public class NoteAttachment {

    /**
     * 业务主键（UUID），由上传服务在 Java 侧生成后回写。
     * IdType.INPUT 表示值由应用提供，不依赖数据库自增。
     */
    @TableId(value = "uuid", type = IdType.INPUT)
    private UUID uuid;

    /** 所属用户 ID（Long），与 note_attachments.user_id 映射 */
    private Long userId;

    /** 关联笔记 UUID，允许为 NULL（独立上传时为空，后续关联到笔记时补填） */
    private UUID noteUuid;

    /** 附件类型，本次固定为 "image" */
    private String type;

    /** MIME 类型，如 image/jpeg、image/png */
    private String mime;

    /**
     * 文件大小（字节数）。
     * 新增列：对应 ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS size BIGINT。
     */
    private Long size;

    /**
     * 原始文件名（客户端上传时的文件名称，用于 Content-Disposition 等）。
     * 新增列：对应 ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS original_file_name TEXT。
     */
    private String originalFileName;

    /**
     * 存储相对键，格式为 YYYY/MM/DD/{uuid}.{ext}。
     * 物理路径 = rootDir/{userId}/{storageKey}。
     */
    private String storageKey;

    /** 存储类型，本次固定为 "local"，未来扩展 "s3"、"oss" 等 */
    private String storageType;

    /** 内容 SHA-256 指纹（可选，用于去重） */
    private String sha256;

    /** 图片宽度（px），仅 image 类型有值 */
    private Integer width;

    /** 图片高度（px），仅 image 类型有值 */
    private Integer height;

    /**
     * 附件来源：user（用户主动上传）、scrape（爬虫抓取）。
     * 本次上传管线固定为 "user"。
     */
    private String source;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
