package com.doublez.pocketmindserver.chat.application;

import java.util.UUID;

/**
 * ChatPersistenceContext 的 ThreadLocal 容器。
 */
public final class ChatPersistenceContextHolder {

    private static final ThreadLocal<ChatPersistenceContext> HOLDER = new ThreadLocal<>();

    private ChatPersistenceContextHolder() {
    }

    public static void set(long userId, UUID sessionUuid, UUID parentUuid) {
        HOLDER.set(new ChatPersistenceContext(userId, sessionUuid, parentUuid));
    }

    public static ChatPersistenceContext get() {
        return HOLDER.get();
    }

    public static UUID getParentUuid() {
        ChatPersistenceContext ctx = HOLDER.get();
        return ctx == null ? null : ctx.parentUuid();
    }

    public static void updateParentUuid(UUID parentUuid) {
        ChatPersistenceContext ctx = HOLDER.get();
        if (ctx == null) {
            return;
        }
        HOLDER.set(new ChatPersistenceContext(ctx.userId(), ctx.sessionUuid(), parentUuid));
    }

    public static void clear() {
        HOLDER.remove();
    }
}
