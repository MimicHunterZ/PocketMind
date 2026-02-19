package com.doublez.pocketmindserver.attachment.domain.attachment;

import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AttachmentRepository {

    void save(AttachmentEntity attachment);

    void update(AttachmentEntity attachment);

    Optional<AttachmentEntity> findByUuidAndUserId(UUID uuid, long userId);

    List<AttachmentEntity> findByNoteUuid(long userId, UUID noteUuid);

    /**
     * sha256 去重查询（相同内容复用已有 storage_key）
     */
    Optional<AttachmentEntity> findBySha256AndUserId(String sha256, long userId);

    List<AttachmentEntity> findChangedSince(long userId, SyncCursorQuery query);
}
