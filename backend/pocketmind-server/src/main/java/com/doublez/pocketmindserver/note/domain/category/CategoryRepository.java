package com.doublez.pocketmindserver.note.domain.category;

import java.util.List;
import java.util.Optional;

/**
 * 分类仓储接口（领域层）
 */
public interface CategoryRepository {

    /** 保存新分类，返回填充了 id 的实体 */
    CategoryEntity save(CategoryEntity category);

    /** 更新已有分类 */
    void update(CategoryEntity category);

    /** 按 uuid + userId 查询（同步识别实体） */
    Optional<CategoryEntity> findByUuidAndUserId(java.util.UUID uuid, long userId);

    /** 查询用户的全部分类 */
    List<CategoryEntity> findByUserId(long userId);


    /** 按 UUID 软删除分类（同步专用，绕过 @TableLogic 直接执行 UPDATE SET is_deleted=TRUE） */
    void softDeleteByUuidAndUserId(java.util.UUID uuid, long userId, long updatedAt);

    /** 同步回填 server_version（不修改 updatedAt） */
    void updateServerVersion(java.util.UUID uuid, long userId, long serverVersion);
}
