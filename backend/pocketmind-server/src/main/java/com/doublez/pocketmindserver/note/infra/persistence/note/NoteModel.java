package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;


@Data
@TableName(value = "notes", autoResultMap = true)
public class NoteModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;

    private Long userId;

    private String title;

    private String content;

    private String sourceUrl;

    private Long categoryId;

    private Instant noteTime;

    private String previewTitle;

    private String previewDescription;

    private String previewContent;

    private NoteResourceStatus resourceStatus;

    private String summary;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;

    /** 服务端同步版本号（sync_change_log.id），null 表示未同步 */
    private Long serverVersion;
}
