package com.doublez.pocketmindserver.resource.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Resource 仓库接口。
 */
public interface ResourceRecordRepository {

    void save(ResourceRecordEntity resourceRecord);

    void update(ResourceRecordEntity resourceRecord);

    Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId);

    default Optional<ResourceRecordEntity> findByUuidAndUserIdIncludingDeleted(UUID uuid, long userId) {
        return findByUuidAndUserId(uuid, userId);
    }

    Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId);

    List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid);

    List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid);

    List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid);

    /**
     * 关键字检索资源，用于 catalog 未命中时的降级召回。
     */
    default List<ResourceRecordEntity> searchByKeyword(long userId, String keyword, int limit) {
        return List.of();
    }
}
