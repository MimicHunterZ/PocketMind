package com.doublez.pocketmindserver.note.domain.category;

import java.util.List;
import java.util.Optional;

/**
 * 分类仓储接口（领域层）
 */
public interface CategoryRepository {

    /** 保存新分类，返回填充了 id 的实体 */
    CategoryEntity save(CategoryEntity category);

    /** 按 id + userId 查询（防止越权） */
    Optional<CategoryEntity> findByIdAndUserId(long id, long userId);

    /** 查询用户的全部分类 */
    List<CategoryEntity> findByUserId(long userId);

    /** 删除分类（仅删除记录，不级联处理笔记的 categoryId） */
    void deleteByIdAndUserId(long id, long userId);
}
