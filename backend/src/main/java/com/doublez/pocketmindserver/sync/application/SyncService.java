package com.doublez.pocketmindserver.sync.application;

import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.sync.api.dto.SyncChangeItem;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogMapper;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogModel;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 同步服务
 * 当前仅同步笔记（note）。用户在离线状态下只会新增/修改笔记（含客户端爬取的 note）。
 * LWW （Last Write Wins）冲突解决：以 updatedAt 毫秒时间戳较大者为准。
 */
@Service
public class SyncService {

    private static final Logger log = LoggerFactory.getLogger(SyncService.class);
    private static final int DEFAULT_PULL_LIMIT = 200;

    private final NoteRepository noteRepository;
    private final SyncChangeLogMapper syncChangeLogMapper;
    private final ObjectMapper objectMapper;

    public SyncService(
            NoteRepository noteRepository,
            SyncChangeLogMapper syncChangeLogMapper,
            ObjectMapper objectMapper) {
        this.noteRepository = noteRepository;
        this.syncChangeLogMapper = syncChangeLogMapper;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public void push(long userId, List<SyncChangeItem> changes) {
        log.info("sync push: userId={}, changeCount={}", userId, changes.size());
        for (SyncChangeItem item : changes) {
            try {
                processChange(userId, item);
            } catch (Exception e) {
                log.error("sync push failed: userId={}, entityType={}, uuid={}, error={}",
                        userId, item.getEntityType(), item.getUuid(), e.getMessage(), e);
            }
        }
    }

    private void processChange(long userId, SyncChangeItem item) {
        String entityType = item.getEntityType();
        UUID uuid = item.getUuid();
        String op = item.getOp();
        long clientUpdatedAt = item.getUpdatedAt();
        log.debug("processing change: entityType={}, uuid={}, op={}, updatedAt={}", entityType, uuid, op, clientUpdatedAt);
        switch (entityType) {
            case "note" -> processNoteChange(userId, uuid, op, clientUpdatedAt, item.getPayload());
            default -> log.warn("unknown entityType, skipping: {}", entityType);
        }
    }

    private void processNoteChange(long userId, UUID uuid, String op, long clientUpdatedAt, Map<String, Object> payload) {
        var existing = noteRepository.findByUuidAndUserId(uuid, userId);

        if ("delete".equals(op)) {
            if (existing.isPresent() && existing.get().getUpdatedAt() <= clientUpdatedAt) {
                var note = existing.get();
                note.softDelete();
                note.overrideUpdatedAtForSync(clientUpdatedAt);
                noteRepository.update(note);
                appendChangeLog(userId, "note", uuid, "delete", clientUpdatedAt);
                log.debug("note soft deleted: uuid={}", uuid);
            } else {
                log.debug("note delete skipped (server is newer): uuid={}", uuid);
            }
            return;
        }

        if (existing.isEmpty()) {
            var note = com.doublez.pocketmindserver.note.domain.note.NoteEntity.create(uuid, userId);
            applyPayloadToNote(note, payload, clientUpdatedAt);
            noteRepository.save(note);
            appendChangeLog(userId, "note", uuid, "upsert", clientUpdatedAt);
            log.debug("note created: uuid={}", uuid);
        } else {
            var note = existing.get();
            if (clientUpdatedAt > note.getUpdatedAt()) {
                applyPayloadToNote(note, payload, clientUpdatedAt);
                noteRepository.update(note);
                appendChangeLog(userId, "note", uuid, "upsert", clientUpdatedAt);
                log.debug("note updated: uuid={}, newUpdatedAt={}", uuid, clientUpdatedAt);
            } else {
                log.debug("note update skipped (server is newer): uuid={}, serverUpdatedAt={}, clientUpdatedAt={}",
                        uuid, note.getUpdatedAt(), clientUpdatedAt);
            }
        }
    }

    private void applyPayloadToNote(
            com.doublez.pocketmindserver.note.domain.note.NoteEntity note,
            Map<String, Object> payload,
            long updatedAt) {
        if (payload == null) return;

        if (payload.containsKey("title") || payload.containsKey("content")) {
            String title = payload.containsKey("title") ? (String) payload.get("title") : note.getTitle();
            String content = payload.containsKey("content") ? (String) payload.get("content") : note.getContent();
            note.updateContent(title, content);
        }
        if (payload.containsKey("sourceUrl")) {
            note.attachSourceUrl((String) payload.get("sourceUrl"));
        }
        if (payload.containsKey("categoryId")) {
            Object catId = payload.get("categoryId");
            if (catId instanceof Number num) {
                note.changeCategory(num.longValue());
            }
        }
        note.overrideUpdatedAtForSync(updatedAt);
    }

    private void appendChangeLog(long userId, String entityType, UUID uuid, String op, long updatedAt) {
        SyncChangeLogModel entry = new SyncChangeLogModel();
        entry.setUserId(userId);
        entry.setEntityType(entityType);
        entry.setEntityUuid(uuid);
        entry.setOp(op);
        entry.setUpdatedAt(updatedAt);
        syncChangeLogMapper.insert(entry);
    }

    public SyncPullResponse pull(long userId, long cursor, int limit) {
        int safeLimit = limit > 0 ? Math.min(limit, 1000) : DEFAULT_PULL_LIMIT;
        log.info("sync pull: userId={}, cursor={}, limit={}", userId, cursor, safeLimit);

        List<SyncChangeLogModel> logs = syncChangeLogMapper.findSince(userId, cursor, safeLimit + 1);
        boolean hasMore = logs.size() > safeLimit;
        if (hasMore) {
            logs = logs.subList(0, safeLimit);
        }

        List<SyncChangeItem> changes = new ArrayList<>();
        for (SyncChangeLogModel entry : logs) {
            try {
                SyncChangeItem item = buildChangeItem(userId, entry);
                if (item != null) changes.add(item);
            } catch (Exception e) {
                log.error("failed to build pull item: entryId={}, error={}", entry.getId(), e.getMessage(), e);
            }
        }

        long newCursor = logs.isEmpty() ? cursor : logs.get(logs.size() - 1).getUpdatedAt();
        log.info("sync pull result: userId={}, changeCount={}, hasMore={}, newCursor={}", userId, changes.size(), hasMore, newCursor);
        return new SyncPullResponse(newCursor, hasMore, changes);
    }

    private SyncChangeItem buildChangeItem(long userId, SyncChangeLogModel entry) {
        SyncChangeItem item = new SyncChangeItem();
        item.setEntityType(entry.getEntityType());
        item.setUuid(entry.getEntityUuid());
        item.setOp(entry.getOp());
        item.setUpdatedAt(entry.getUpdatedAt());

        if ("delete".equals(entry.getOp())) return item;

        Map<String, Object> payload = loadPayload(userId, entry.getEntityType(), entry.getEntityUuid());
        if (payload == null) {
            log.warn("entity not found, skipping: entityType={}, uuid={}", entry.getEntityType(), entry.getEntityUuid());
            return null;
        }
        payload.forEach((k, v) -> item.setPayload(k, v));
        return item;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> loadPayload(long userId, String entityType, UUID uuid) {
        return switch (entityType) {
            case "note" -> noteRepository.findByUuidAndUserId(uuid, userId)
                    .map(e -> (Map<String, Object>) objectMapper.convertValue(e, Map.class))
                    .orElse(null);
            default -> {
                log.warn("unsupported entityType for pull payload: {}", entityType);
                yield null;
            }
        };
    }
}