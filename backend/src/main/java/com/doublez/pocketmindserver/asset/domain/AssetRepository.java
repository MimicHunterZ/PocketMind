package com.doublez.pocketmindserver.asset.domain;

import java.util.List;
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

    /**
     * 按 noteUuid 和 userId 查询该笔记下所有资产（未删除）。
     *
     * @param noteUuid 笔记业务 UUID
     * @param userId   当前登录用户 ID
     * @return 资产列表，不存在时返回空列表
     */
    List<Asset> findByNoteUuidAndUserId(UUID noteUuid, long userId);

    /**
     * 将孤立资产绑定到指定笔记。
     *
     * @param assetUuid asset 业务 UUID
     * @param userId    当前登录用户 ID（权限校验）
     * @param noteUuid  目标笔记 UUID
     * @return 更新成功返回 true，未找到记录返回 false
     */
    boolean bindNoteUuid(UUID assetUuid, long userId, UUID noteUuid);
}
