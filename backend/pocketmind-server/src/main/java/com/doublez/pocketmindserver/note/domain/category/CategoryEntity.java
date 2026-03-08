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
    /** 分类描述 */
    private String description;
    /** 图标路径（对应客户端 category.iconPath） */
    private String iconPath;

    private long updatedAt;
    private boolean deleted;
    /** 服务端分配的单调递增版本号；null 表示尚未同步至服务端 */
    private Long serverVersion;

    @ConstructorProperties({"id", "uuid", "userId", "name", "description", "iconPath", "updatedAt", "deleted", "serverVersion"})
    public CategoryEntity(long id, UUID uuid, long userId, String name,
                          String description, String iconPath,
                          long updatedAt, boolean deleted, Long serverVersion) {
        this.id = id;
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.name = Objects.requireNonNull(name, "name 不能为空");
        this.description = description;
        this.iconPath = iconPath;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
        this.serverVersion = serverVersion;
    }

    /**
     * 创建新分类
     */
    public static CategoryEntity create(long userId, String name) {
        return new CategoryEntity(0L, UUID.randomUUID(), userId, name, null, null, System.currentTimeMillis(), false, null);
    }

    public void rename(String name) {
        this.name = Objects.requireNonNull(name, "name 不能为空");
        this.updatedAt = System.currentTimeMillis();
    }

    /** 同步专用：更新描述和图标 */
    public void updateMeta(String description, String iconPath) {
        this.description = description;
        this.iconPath = iconPath;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 同步专用：覆盖 updatedAt，不使用 System.currentTimeMillis() */
    public void overrideUpdatedAt(long updatedAt) {
        this.updatedAt = updatedAt;
    }

    /** 同步专用：回填服务端版本号 */
    public void assignServerVersion(long serverVersion) {
        this.serverVersion = serverVersion;
    }

    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
