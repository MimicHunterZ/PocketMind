package com.doublez.pocketmindserver.sync.application;

import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushRequest;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushResult;

import java.util.List;
import java.util.UUID;

/**
 * 同步服务接口。
 *
 * <p>三个方法组成完整的增量同步协议：
 * <ol>
 *   <li>{@link #pull} — 客户端拉取服务端变更（游标分页）</li>
 *   <li>{@link #push} — 客户端推送本地变更（LWW + 幂等）</li>
 *   <li>{@link #persistAiResult} — AI 管线回调，写入权威字段并追加变更日志</li>
 * </ol>
 * </p>
 */
public interface SyncService {

    /**
     * 拉取 sinceVersion 之后的服务端变更。
     *
     * @param userId       当前用户 ID
     * @param sinceVersion 客户端游标（上次返回的 serverVersion），首次传 0
     * @param pageSize     每页最大条目数（建议 200，上限 500）
     * @return 增量变更列表及下一游标
     */
    SyncPullResponse pull(long userId, long sinceVersion, int pageSize);

    /**
     * 推送客户端本地变更批次，按顺序处理每条 mutation。
     *
     * @param userId  当前用户 ID
     * @param request 包含有序 mutation 列表的请求体
     * @return 每条 mutation 对应的处理结果（长度与请求列表一致）
     */
    List<SyncPushResult> push(long userId, SyncPushRequest request);

    /**
     * AI 管线结果回写：将 AI 权威字段落库，并追加一条 change_log。
     * <p>
     * 此方法运行在独立事务中，不修改 {@code updatedAt}，保证 LWW 语义正确。
     * </p>
     *
     * @param noteUuid           目标笔记 UUID
     * @param userId             笔记归属用户 ID
     * @param aiSummary          AI 生成摘要
     * @param resourceStatus     资源状态（DONE / FAILED）
     * @param previewTitle       预览标题
     * @param previewDescription 预览描述
     * @param previewContent     预览正文
     */
    void persistAiResult(UUID noteUuid,
                         long userId,
                         String aiSummary,
                         String resourceStatus,
                         String previewTitle,
                         String previewDescription,
                         String previewContent);
}
