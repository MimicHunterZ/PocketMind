package com.doublez.pocketmindserver.note.domain.category;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.UUID;
import java.util.Objects;

/**
 * 笔记分类领域实体
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class CategoryEntity {

    private final long id;
    private final UUID uuid;
    private final long userId;
    private String name;

    private long updatedAt;
    private boolean deleted;

    @ConstructorProperties({"id", "uuid", "userId", "name", "updatedAt", "deleted"})
    public CategoryEntity(long id, UUID uuid, long userId, String name, long updatedAt, boolean deleted) {
        this.id = id;
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.name = Objects.requireNonNull(name, "name 不能为空");
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    /**
     * 创建新分类
     */
    public static CategoryEntity create(long userId, String name) {
        return new CategoryEntity(0L, UUID.randomUUID(), userId, name, System.currentTimeMillis(), false);
    }

    public void rename(String name) {
        this.name = Objects.requireNonNull(name, "name 不能为空");
        this.updatedAt = System.currentTimeMillis();
    }

    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
