package com.doublez.pocketmindserver.asset.domain;

import java.util.Optional;
import java.util.UUID;

/**
 * 图片资产持久化仓储接口。
 */
public interface NoteAttachmentRepository {

    /**
     * 新建附件记录。
     *
     * @param attachment 附件实体（uuid 已由调用方生成）
     */
    void save(NoteAttachment attachment);

    /**
     * 按 UUID 和 userId 查询附件，同时校验归属权。
     *
     * @param uuid   附件业务 UUID
     * @param userId 当前登录用户 ID
     * @return 若存在且归属匹配则返回 Optional.of(entity)，否则 Optional.empty()
     */
    Optional<NoteAttachment> findByUuidAndUserId(UUID uuid, long userId);
}
