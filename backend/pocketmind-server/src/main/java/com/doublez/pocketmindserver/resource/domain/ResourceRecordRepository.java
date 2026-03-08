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

    List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid);

    List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid);

    List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid);
}
