package com.doublez.pocketmindserver.sync.api.dto;

import java.util.Map;

/**
 * Push 接口响应中单条变更结果，字段命名与 Flutter {@code SyncPushResult.fromJson} 严格对齐。
 *
 * <ul>
 *   <li>{@code accepted=true}：LWW 客户端胜出或新建，已写入，携带 {@code serverVersion}</li>
 *   <li>{@code accepted=false + conflictEntity!=null}：LWW 服务端胜出（409 语义），
 *       客户端以 {@code conflictEntity} 覆盖本地并删除该 MutationEntry</li>
 *   <li>{@code accepted=false + rejectReason!=null}：永久性拒绝（如数据非法），
 *       客户端将 MutationEntry 置 failed</li>
 * </ul>
 */
public record SyncPushResult(
        String mutationId,
        boolean accepted,
        Long serverVersion,
    boolean retryable,
        String rejectReason,
        Map<String, Object> conflictEntity
) {

    /** 构建"接受"结果 */
    public static SyncPushResult accepted(String mutationId, long serverVersion) {
        return new SyncPushResult(mutationId, true, serverVersion, false, null, null);
    }

    /**
     * 构建"冲突"结果（LWW 服务端胜出）。
     * 客户端收到后以 {@code conflictEntity} 覆盖本地，丢弃该 mutation。
     */
    public static SyncPushResult conflict(String mutationId, Map<String, Object> serverEntity) {
        return new SyncPushResult(mutationId, false, null, false, "CONFLICT_SERVER_WINS", serverEntity);
    }

    /** 构建"永久拒绝"结果（4xx 语义，非冲突） */
    public static SyncPushResult rejected(String mutationId, String reason) {
        return new SyncPushResult(mutationId, false, null, false, reason, null);
    }

    /** 构建"可重试拒绝"结果（5xx / 瞬时故障语义） */
    public static SyncPushResult retryableRejected(String mutationId, String reason) {
        return new SyncPushResult(mutationId, false, null, true, reason, null);
    }
}
