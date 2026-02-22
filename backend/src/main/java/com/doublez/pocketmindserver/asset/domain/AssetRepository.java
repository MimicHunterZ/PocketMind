package com.doublez.pocketmindserver.asset.domain;

import java.util.Optional;
import java.util.UUID;

/**
 * 物理资产持久化仓储接口。
 */
public interface AssetRepository {

    /**
     * 新建 asset 记录。
     *
     * @param asset 资产实体（uuid 已由调用方生成）
     */
    void save(Asset asset);

    /**
     * 按 UUID 和 userId 查询 asset，同时校验归属权。
     *
     * @param uuid   asset 业务 UUID
     * @param userId 当前登录用户 ID
     * @return 若存在且归属匹配则返回 Optional.of(entity)，否则 Optional.empty()
     */
    Optional<Asset> findByUuidAndUserId(UUID uuid, long userId);
}
