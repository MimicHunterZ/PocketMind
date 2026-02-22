package com.doublez.pocketmindserver.asset.domain;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.shared.mybatis.JsonbTypeHandler;
import lombok.Data;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * assets 表映射（物理资产事实表）。
 *
 * <p>统一存储图片、PDF、视频、音频等任意格式的物理文件元数据。
 * 与业务含义解耦：type/source 字段记录格式与来源，metadata JSONB 存放
 * 格式相关的物理属性（宽高/页数/时长等），business_metadata 预留排版字段。</p>
 *
 * <p>主键策略：{@code uuid UUID}（IdType.INPUT，由 Java 侧生成后写入），
 * 数据库自增 {@code id BIGSERIAL} 不在此模型中声明。</p>
 */
@Data
@TableName(value = "assets", autoResultMap = true)
public class Asset {

    /** 业务主键（UUID），由上传服务在 Java 侧生成。 */
    @TableId(value = "uuid", type = IdType.INPUT)
    private UUID uuid;

    /** 所属用户 ID */
    private Long userId;

    /** 归属笔记 UUID，允许为 NULL（独立上传时先不绑定） */
    private UUID noteUuid;

    /**
     * 格式分类：'image' | 'pdf' | 'video' | 'audio' | 'file'
     * 决定前端用什么组件渲染。
     */
    private String type;

    /**
     * 来源：'user'（用户主动上传）| 'scrape'（爬虫抓取）| 'system_gen'（系统生成）
     */
    private String source;

    /** MIME 类型，如 image/jpeg、application/pdf */
    private String mime;

    /** 文件字节数 */
    private Long size;

    /** 上传时的原始文件名（用于 Content-Disposition 等） */
    private String fileName;

    /** 内容 SHA-256 指纹，存储层去重（相同 sha256 复用 storageKey） */
    private String sha256;

    /**
     * 存储路径键，格式：YYYY/MM/DD/{uuid}.{ext}
     * 物理路径 = rootDir/{userId}/{storageKey}
     */
    private String storageKey;

    /** 存储类型：'local' | 'server' | 'oss' */
    private String storageType;

    /**
     * 物理元数据（JSONB），存放格式相关属性：
     * 图片/视频：{"width": 1920, "height": 1080}
     * 视频：{"duration_seconds": 120}
     * PDF：{"page_count": 50}
     */
    @TableField(value = "metadata", typeHandler = JsonbTypeHandler.class)
    private Map<String, Object> metadata;

    /**
     * 业务/排版元数据（JSONB），预留接口，当前为空：
     * 示例：{"caption": "今天抓拍的小猫", "layout": "full-width"}
     */
    @TableField(value = "business_metadata", typeHandler = JsonbTypeHandler.class)
    private Map<String, Object> businessMetadata;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
