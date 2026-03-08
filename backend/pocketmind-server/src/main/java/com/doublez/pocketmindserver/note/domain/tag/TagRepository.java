package com.doublez.pocketmindserver.note.domain.tag;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 标签仓储接口（领域层）
 * <p>
 * 只负责管理标签字典（tags 表）。
 */
public interface TagRepository {

    /**
     * 查找已有标签，不存在则创建。
     * 保证幂等：同一 (userId, name) 只有一条记录。
     */
    TagEntity findOrCreate(long userId, String name);

    /** 按 UUID 查询标签 */
    Optional<TagEntity> findByUuidAndUserId(UUID uuid, long userId);

}
