package com.doublez.pocketmindserver.sync.application;

import com.doublez.pocketmindserver.note.domain.category.CategoryEntity;
import com.doublez.pocketmindserver.note.domain.category.CategoryRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.application.NoteResourceSyncService;
import com.doublez.pocketmindserver.sync.api.dto.SyncChangeItem;
import com.doublez.pocketmindserver.sync.api.dto.SyncMutationDto;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushRequest;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushResult;
import com.doublez.pocketmindserver.sync.domain.SyncChangeLogRepository;
import com.doublez.pocketmindserver.sync.event.NoteAiPipelineEvent;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogModel;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.*;

/**
 * 同步服务实现。
 *
 * <h3>设计要点</h3>
 * <ul>
 *   <li>使用 {@link TransactionTemplate} 做每条 mutation 的独立小事务，避免大事务锁争抢</li>
 *   <li>LWW（Last Write Wins）：{@code clientUpdatedAt >= serverUpdatedAt} 客户端胜出</li>
 *   <li>幂等键：{@code client_mutation_id UNIQUE} 约束，重试时返回已有结果</li>
 *   <li>{@code sync_change_log.id} 即为 serverVersion，单调递增</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SyncServiceImpl implements SyncService {

    private final NoteRepository noteRepository;
    private final CategoryRepository categoryRepository;
    private final SyncChangeLogRepository changeLogRepository;
    private final TransactionTemplate transactionTemplate;
    private final ApplicationEventPublisher eventPublisher;
    private final ObjectMapper objectMapper;
    private final NoteResourceSyncService noteResourceSyncService;

    // ─── Pull ────────────────────────────────────────────────────────────────

    @Override
    public SyncPullResponse pull(long userId, long sinceVersion, int pageSize) {
        // 多取一条，用于判断 hasMore
        List<SyncChangeLogModel> rows = changeLogRepository.findSince(userId, sinceVersion, pageSize + 1);

        boolean hasMore = rows.size() > pageSize;
        List<SyncChangeLogModel> page = hasMore ? rows.subList(0, pageSize) : rows;

        if (page.isEmpty()) {
            return new SyncPullResponse(sinceVersion, false, Collections.emptyList());
        }

        List<SyncChangeItem> changes = page.stream()
                .map(this::toChangeItem)
                .toList();

        // 游标推进到本页最大 serverVersion
        long nextCursor = page.get(page.size() - 1).getId();
        return new SyncPullResponse(nextCursor, hasMore, changes);
    }

    /** 将 change_log 持久化模型转换为 Pull 响应条目 */
    private SyncChangeItem toChangeItem(SyncChangeLogModel row) {
        Map<String, Object> payload = parsePayloadJson(row.getPayload());
        return new SyncChangeItem(
                row.getEntityType(),
                row.getEntityUuid().toString(),
                row.getOperation(),
                row.getId(),
                row.getUpdatedAt(),
                payload
        );
    }

    // ─── Push ────────────────────────────────────────────────────────────────

    @Override
    public List<SyncPushResult> push(long userId, SyncPushRequest request) {
        List<SyncPushResult> results = new ArrayList<>(request.mutations().size());
        for (SyncMutationDto mutation : request.mutations()) {
            try {
                SyncPushResult result = switch (mutation.entityType()) {
                    case "note" -> processNoteMutation(userId, mutation);
                    case "category" -> processCategoryMutation(userId, mutation);
                    default -> SyncPushResult.rejected(
                            mutation.mutationId(),
                            "UNKNOWN_ENTITY_TYPE:" + mutation.entityType()
                    );
                };
                results.add(result);
            } catch (Exception e) {
                SyncPushResult recovered = tryRecoverDuplicateKeyAsIdempotent(mutation, e);
                if (recovered != null) {
                    results.add(recovered);
                    continue;
                }

                if (e instanceof DuplicateKeyException) {
                    log.warn("[Sync] mutation 写入发生唯一键冲突, mutationId={}, error={}", mutation.mutationId(), e.getMessage());
                } else {
                    log.error("[Sync] 处理 mutation 出现异常, mutationId={}", mutation.mutationId(), e);
                }
                results.add(SyncPushResult.retryableRejected(mutation.mutationId(), "SERVER_ERROR"));
            }
        }
        return results;
    }

    /**
     * 并发重试场景下，若唯一键冲突对应的 mutation 已成功落库，则按幂等接受返回。
     */
    private SyncPushResult tryRecoverDuplicateKeyAsIdempotent(SyncMutationDto mutation, Exception e) {
        if (!(e instanceof DuplicateKeyException)) {
            return null;
        }
        Optional<Long> cached = changeLogRepository.findVersionByMutationId(mutation.mutationId());
        if (cached.isEmpty()) {
            return null;
        }
        log.info("[Sync] 唯一键冲突按幂等恢复, mutationId={}, sv={}", mutation.mutationId(), cached.get());
        return SyncPushResult.accepted(mutation.mutationId(), cached.get());
    }

    // ─── 笔记 Mutation 处理 ───────────────────────────────────────────────────

    private SyncPushResult processNoteMutation(long userId, SyncMutationDto mutation) {
        // 幂等检查：同一 mutationId 已处理过，直接返回历史结果
        Optional<Long> cached = changeLogRepository.findVersionByMutationId(mutation.mutationId());
        if (cached.isPresent()) {
            log.debug("[Sync] 幂等命中 mutationId={}, sv={}", mutation.mutationId(), cached.get());
            return SyncPushResult.accepted(mutation.mutationId(), cached.get());
        }

        UUID entityUuid = UUID.fromString(mutation.entityUuid());
        return transactionTemplate.execute(status -> switch (mutation.operation()) {
            case "delete" -> deleteNote(userId, entityUuid, mutation);
            case "create" -> createNote(userId, entityUuid, mutation);
            case "update" -> updateNote(userId, entityUuid, mutation);
            default -> SyncPushResult.rejected(
                    mutation.mutationId(), "UNKNOWN_OPERATION:" + mutation.operation());
        });
    }

    private SyncPushResult deleteNote(long userId, UUID entityUuid, SyncMutationDto mutation) {
        Optional<NoteEntity> opt = noteRepository.findByUuidAndUserId(entityUuid, userId);
        if (opt.isEmpty()) {
            // 客户端删除了服务端不存在的笔记，幂等接受（写入 change_log）
            long sv = changeLogRepository.insert(
                    userId, "note", entityUuid, "delete",
                    mutation.updatedAt(), mutation.mutationId(), null);
            return SyncPushResult.accepted(mutation.mutationId(), sv);
        }

        NoteEntity note = opt.get();
        // 注意：不能调用 noteRepository.update(note) —— @TableLogic 可能导致 is_deleted
        // 被 MyBatis-Plus 从 UPDATE SET 中排除。这里必须使用显式 SQL 软删除。
        noteRepository.softDeleteByUuidAndUserId(entityUuid, userId, mutation.updatedAt());
        note.softDelete();
        note.overrideUpdatedAtForSync(mutation.updatedAt());
        noteResourceSyncService.softDeleteByNote(note);

        long sv = changeLogRepository.insert(
                userId, "note", entityUuid, "delete",
            mutation.updatedAt(), mutation.mutationId(), null);
        noteRepository.updateServerVersion(entityUuid, userId, sv);
        return SyncPushResult.accepted(mutation.mutationId(), sv);
    }

    private SyncPushResult createNote(long userId, UUID entityUuid, SyncMutationDto mutation) {
        // 防止重复 UUID（客户端重试且 mutationId 超出去重窗口时的极端情况）
        if (noteRepository.findByUuidAndUserId(entityUuid, userId).isPresent()) {
            return updateNote(userId, entityUuid, mutation);
        }

        NoteEntity note = NoteEntity.create(entityUuid, userId);
        boolean urlChanged = applyPayloadToNote(note, mutation.payload());
        note.overrideUpdatedAtForSync(mutation.updatedAt());
        noteRepository.save(note);
        noteResourceSyncService.syncProjectedResources(note);

        // Tags 必须在 noteRepository.save() 之后写入，否则 persistTagRelations() 会清除本次写入
        List<String> clientTagsCreate = extractTagNames(mutation.payload());
        if (!clientTagsCreate.isEmpty()) {
            noteRepository.replaceTagNames(entityUuid, userId, clientTagsCreate);
        }

        List<String> tagNames = noteRepository.findTagNamesByUuid(entityUuid, userId);
        String payloadJson = toJson(buildNotePayloadMap(note, tagNames));
        long sv = changeLogRepository.insert(
                userId, "note", entityUuid, "create",
                note.getUpdatedAt(), mutation.mutationId(), payloadJson);
        noteRepository.updateServerVersion(entityUuid, userId, sv);

        if (urlChanged) {
            eventPublisher.publishEvent(new NoteAiPipelineEvent(entityUuid, userId));
        }
        return SyncPushResult.accepted(mutation.mutationId(), sv);
    }

    private SyncPushResult updateNote(long userId, UUID entityUuid, SyncMutationDto mutation) {
        Optional<NoteEntity> opt = noteRepository.findByUuidAndUserId(entityUuid, userId);
        if (opt.isEmpty()) {
            // 服务端没有此笔记，退化为 create
            return createNote(userId, entityUuid, mutation);
        }

        NoteEntity serverNote = opt.get();

        // LWW 裁决：客户端 updatedAt >= 服务端 updatedAt → 客户端胜出
        if (mutation.updatedAt() >= serverNote.getUpdatedAt()) {
            boolean urlChanged = applyPayloadToNote(serverNote, mutation.payload());
            serverNote.overrideUpdatedAtForSync(mutation.updatedAt());
            noteRepository.update(serverNote);
            noteResourceSyncService.syncProjectedResources(serverNote);

            // Tags 必须在 noteRepository.update() 之后写入，否则 persistTagRelations() 会清除本次写入
            List<String> clientTagsUpdate = extractTagNames(mutation.payload());
            if (!clientTagsUpdate.isEmpty()) {
                noteRepository.replaceTagNames(entityUuid, userId, clientTagsUpdate);
            }

            List<String> tagNames = noteRepository.findTagNamesByUuid(entityUuid, userId);
            String payloadJson = toJson(buildNotePayloadMap(serverNote, tagNames));
            long sv = changeLogRepository.insert(
                    userId, "note", entityUuid, "update",
                    serverNote.getUpdatedAt(), mutation.mutationId(), payloadJson);
            noteRepository.updateServerVersion(entityUuid, userId, sv);

            if (urlChanged) {
                eventPublisher.publishEvent(new NoteAiPipelineEvent(entityUuid, userId));
            }
            return SyncPushResult.accepted(mutation.mutationId(), sv);
        }

        // 服务端胜出（LWW 409 冲突语义）：返回服务端当前实体，客户端以此覆盖本地
        List<String> tagNames = noteRepository.findTagNamesByUuid(entityUuid, userId);
        return SyncPushResult.conflict(
                mutation.mutationId(), buildNotePayloadMap(serverNote, tagNames));
    }

    // ─── 分类 Mutation 处理 ───────────────────────────────────────────────────

    private SyncPushResult processCategoryMutation(long userId, SyncMutationDto mutation) {
        // 幂等检查
        Optional<Long> cached = changeLogRepository.findVersionByMutationId(mutation.mutationId());
        if (cached.isPresent()) {
            return SyncPushResult.accepted(mutation.mutationId(), cached.get());
        }

        UUID entityUuid = UUID.fromString(mutation.entityUuid());
        return transactionTemplate.execute(status -> switch (mutation.operation()) {
            case "delete" -> deleteCategory(userId, entityUuid, mutation);
            case "create" -> createCategory(userId, entityUuid, mutation);
            case "update" -> updateCategory(userId, entityUuid, mutation);
            default -> SyncPushResult.rejected(
                    mutation.mutationId(), "UNKNOWN_OPERATION:" + mutation.operation());
        });
    }

    private SyncPushResult deleteCategory(long userId, UUID entityUuid, SyncMutationDto mutation) {
        Optional<CategoryEntity> opt = categoryRepository.findByUuidAndUserId(entityUuid, userId);
        if (opt.isEmpty()) {
            long sv = changeLogRepository.insert(
                    userId, "category", entityUuid, "delete",
                    mutation.updatedAt(), mutation.mutationId(), null);
            return SyncPushResult.accepted(mutation.mutationId(), sv);
        }

        CategoryEntity cat = opt.get();
        // 注意：不能调用 categoryRepository.update(cat) —— @TableLogic 会导致 is_deleted 被 MyBatis-Plus 从 UPDATE SET 中排除。
        // 必须使用显式 SQL 方法直接操作 is_deleted 字段。
        categoryRepository.softDeleteByUuidAndUserId(entityUuid, userId, mutation.updatedAt());

        long sv = changeLogRepository.insert(
                userId, "category", entityUuid, "delete",
            mutation.updatedAt(), mutation.mutationId(), null);
        categoryRepository.updateServerVersion(entityUuid, userId, sv);
        return SyncPushResult.accepted(mutation.mutationId(), sv);
    }

    private SyncPushResult createCategory(long userId, UUID entityUuid, SyncMutationDto mutation) {
        if (categoryRepository.findByUuidAndUserId(entityUuid, userId).isPresent()) {
            return updateCategory(userId, entityUuid, mutation);
        }

        Map<String, Object> payload = mutation.payload();
        String name = (String) payload.get("name");
        String description = (String) payload.get("description");
        String iconPath = (String) payload.get("iconPath");

        // 使用客户端提供的 UUID，不能调用 CategoryEntity.create(userId, name)（会生成随机 UUID）
        CategoryEntity cat = new CategoryEntity(
                0L, entityUuid, userId, name, description, iconPath,
                mutation.updatedAt(), false, null);
        categoryRepository.save(cat);

        String payloadJson = toJson(buildCategoryPayloadMap(cat));
        long sv = changeLogRepository.insert(
                userId, "category", entityUuid, "create",
                cat.getUpdatedAt(), mutation.mutationId(), payloadJson);
        categoryRepository.updateServerVersion(entityUuid, userId, sv);
        return SyncPushResult.accepted(mutation.mutationId(), sv);
    }

    private SyncPushResult updateCategory(long userId, UUID entityUuid, SyncMutationDto mutation) {
        Optional<CategoryEntity> opt = categoryRepository.findByUuidAndUserId(entityUuid, userId);
        if (opt.isEmpty()) {
            return createCategory(userId, entityUuid, mutation);
        }

        CategoryEntity serverCat = opt.get();

        if (mutation.updatedAt() >= serverCat.getUpdatedAt()) {
            applyPayloadToCategory(serverCat, mutation.payload());
            serverCat.overrideUpdatedAt(mutation.updatedAt());
            categoryRepository.update(serverCat);

            String payloadJson = toJson(buildCategoryPayloadMap(serverCat));
            long sv = changeLogRepository.insert(
                    userId, "category", entityUuid, "update",
                    serverCat.getUpdatedAt(), mutation.mutationId(), payloadJson);
            categoryRepository.updateServerVersion(entityUuid, userId, sv);
            return SyncPushResult.accepted(mutation.mutationId(), sv);
        }

        return SyncPushResult.conflict(mutation.mutationId(), buildCategoryPayloadMap(serverCat));
    }

    // ─── AI 管线回写 ──────────────────────────────────────────────────────────

    @Override
    public void persistAiResult(UUID noteUuid, long userId,
                                String aiSummary, String resourceStatus,
                                String previewTitle, String previewDescription, String previewContent) {
        transactionTemplate.execute(status -> {
            noteRepository.updateAiFields(
                    noteUuid, userId, aiSummary, resourceStatus,
                    previewTitle, previewDescription, previewContent);

            Optional<NoteEntity> opt = noteRepository.findByUuidAndUserId(noteUuid, userId);
            if (opt.isEmpty()) {
                log.warn("[Sync-AI] 笔记不存在，跳过 change_log 写入, uuid={}", noteUuid);
                return null;
            }

            NoteEntity note = opt.get();
            noteResourceSyncService.syncProjectedResources(note);
            List<String> tagNames = noteRepository.findTagNamesByUuid(noteUuid, userId);
            String payloadJson = toJson(buildNotePayloadMap(note, tagNames));

            // clientMutationId = null 表示非客户端发起的变更（如 AI 回填）
            long sv = changeLogRepository.insert(
                    userId, "note", noteUuid, "update",
                    note.getUpdatedAt(), null, payloadJson);
            noteRepository.updateServerVersion(noteUuid, userId, sv);
            return null;
        });
    }

    // ─── Payload 构建（服务端 → Flutter 字段映射）────────────────────────────

    /**
     * 构建笔记 payload Map，字段名与 Flutter {@code _noteFromPayload} 严格对齐。
     *
     * <p>关键字段名差异：
     * <ul>
     *   <li>后端 {@code sourceUrl} → Flutter {@code url}</li>
     *   <li>后端 {@code noteTime} (Instant) → Flutter {@code time} (毫秒时间戳)</li>
     *   <li>后端 {@code summary} → Flutter {@code aiSummary}</li>
     * </ul>
     * </p>
     */
    private Map<String, Object> buildNotePayloadMap(NoteEntity note, List<String> tagNames) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("uuid", note.getUuid().toString());
        map.put("title", note.getTitle());
        map.put("content", note.getContent());
        map.put("url", note.getSourceUrl());
        map.put("time", note.getNoteTime() != null ? note.getNoteTime().toEpochMilli() : null);
        map.put("updatedAt", note.getUpdatedAt());
        map.put("isDeleted", note.isDeleted());
        map.put("categoryId", note.getCategoryId());
        map.put("tags", tagNames);
        map.put("previewTitle", note.getPreviewTitle());
        map.put("previewDescription", note.getPreviewDescription());
        map.put("previewContent", note.getPreviewContent());
        map.put("resourceStatus", note.getResourceStatus().name());
        map.put("aiSummary", note.getSummary());
        map.put("serverVersion", note.getServerVersion());
        return map;
    }

    /**
     * 构建分类 payload Map，字段名与 Flutter {@code _categoryFromPayload} 严格对齐。
     */
    private Map<String, Object> buildCategoryPayloadMap(CategoryEntity cat) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("uuid", cat.getUuid().toString());
        map.put("name", cat.getName());
        map.put("description", cat.getDescription());
        map.put("iconPath", cat.getIconPath());
        map.put("updatedAt", cat.getUpdatedAt());
        map.put("isDeleted", cat.isDeleted());
        map.put("serverVersion", cat.getServerVersion());
        return map;
    }

    // ─── Payload 应用（Flutter → 服务端实体）─────────────────────────────────

    /**
     * 将客户端 payload 应用到 NoteEntity，返回来源 URL 是否发生有效变更。
     *
     * <p>注意：entity 各业务方法内部会修改 {@code updatedAt}，
     * 调用方须在之后统一调用 {@code note.overrideUpdatedAtForSync()} 覆盖。</p>
     */
    private boolean applyPayloadToNote(NoteEntity note, Map<String, Object> payload) {
        String title = (String) payload.get("title");
        String content = (String) payload.get("content");
        note.updateContent(title, content);

        Object catIdRaw = payload.get("categoryId");
        if (catIdRaw instanceof Number num) {
            long catId = num.longValue();
            if (catId > 0) note.changeCategory(catId);
        }

        Object timeRaw = payload.get("time");
        if (timeRaw instanceof Number num) {
            note.changeNoteTime(Instant.ofEpochMilli(num.longValue()));
        }

        // 同步专用 URL setter：不自动重置 resourceStatus
        String url = (String) payload.get("url");
        return note.syncSourceUrl(url);
    }

    private List<String> extractTagNames(Map<String, Object> payload) {
        Object rawTags = payload.get("tags");
        if (!(rawTags instanceof List<?> tags)) {
            return List.of();
        }

        return tags.stream()
                .filter(Objects::nonNull)
                .map(Object::toString)
                .map(String::strip)
                .filter(tag -> !tag.isEmpty())
                .distinct()
                .toList();
    }

    /** 将客户端 payload 应用到 CategoryEntity */
    private void applyPayloadToCategory(CategoryEntity cat, Map<String, Object> payload) {
        String name = (String) payload.get("name");
        if (name != null && !name.isBlank()) {
            cat.rename(name);
        }
        String description = (String) payload.get("description");
        String iconPath = (String) payload.get("iconPath");
        cat.updateMeta(description, iconPath);
    }

    // ─── JSON 工具 ────────────────────────────────────────────────────────────

    private String toJson(Map<String, Object> map) {
        try {
            return objectMapper.writeValueAsString(map);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Payload 序列化失败", e);
        }
    }

    private Map<String, Object> parsePayloadJson(String json) {
        if (json == null || json.isBlank()) return Collections.emptyMap();
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (JsonProcessingException e) {
            log.warn("[Sync] 解析 change_log payload JSON 失败: {}", e.getMessage());
            return Collections.emptyMap();
        }
    }
}
