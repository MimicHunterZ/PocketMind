package com.doublez.pocketmindserver.attachment.domain.vision;

import com.doublez.pocketmindserver.shared.domain.LimitQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AttachmentVisionRepository {

    void save(AttachmentVisionEntity vision);

    void update(AttachmentVisionEntity vision);

    /**
     * 必须带 userId，防止仅凭 uuid 越权读取
     */
    Optional<AttachmentVisionEntity> findByUuidAndUserId(UUID uuid, long userId);

    /**
     * 查询某个附件的识别结果（通常 1:1，但允许多次识别）
     */
    List<AttachmentVisionEntity> findByAttachmentUuid(long userId, UUID attachmentUuid);

    /**
     * 查询用户待处理的 Vision 任务
     */
    List<AttachmentVisionEntity> findPendingByUserId(long userId, LimitQuery query);

    List<AttachmentVisionEntity> findChangedSince(long userId, SyncCursorQuery query);

    /**
     * 查询指定笔记下已完成识别的图片结果
     */
    List<AttachmentVisionEntity> findDoneByNoteUuid(long userId, UUID noteUuid);
}
