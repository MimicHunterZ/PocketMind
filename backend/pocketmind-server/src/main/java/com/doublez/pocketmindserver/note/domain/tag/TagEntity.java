package com.doublez.pocketmindserver.note.domain.tag;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.UUID;
import java.util.Objects;

/**
 * 标签领域实体（标签字典，可由用户或 AI 生成）
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class TagEntity {

    private final long id;
    private final UUID uuid;
    private final long userId;
    private String name;

    private long updatedAt;
    private boolean deleted;

    @ConstructorProperties({"id", "uuid", "userId", "name", "updatedAt", "deleted"})
    public TagEntity(long id, UUID uuid, long userId, String name, long updatedAt, boolean deleted) {
        this.id = id;
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.name = Objects.requireNonNull(name, "name 不能为空");
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    public static TagEntity create(long userId, String name) {
        return new TagEntity(0L, UUID.randomUUID(), userId, name, System.currentTimeMillis(), false);
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
