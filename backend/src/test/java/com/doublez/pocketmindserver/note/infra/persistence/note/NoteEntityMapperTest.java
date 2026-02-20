package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus;
import com.doublez.pocketmindserver.note.domain.note.NoteTag;
import org.mapstruct.factory.Mappers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * NoteStructMapper（MapStruct 生成）双向转换单元测试
 */
class NoteEntityMapperTest {

    private NoteStructMapper mapper;

    @BeforeEach
    void setUp() {
        mapper = Mappers.getMapper(NoteStructMapper.class);
    }

    @Test
    void roundTrip_shouldPreserveAllFields() {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        long ts = System.currentTimeMillis();

        // 通过 create + setter 构造（不再有 rehydrate）
        NoteEntity original = NoteEntity.create(id, 42L);
        original.updateContent("标题", "内容");
        original.attachSourceUrl("https://example.com");
        original.changeCategory(3L);
        original.changeNoteTime(now);
        original.completeFetch("预览标题", "预览摘要", "预览内容");
        original.updateMemoryPath("/memory/path");
        original.updateSummary("总结");
        original.addTag(100L);
        original.addTag(200L);
        original.overrideUpdatedAtForSync(ts);

        List<NoteTag> tags = List.copyOf(original.getTags());

        NoteModel model = mapper.toModel(original);
        NoteEntity restored = mapper.toDomain(model, tags);

        assertEquals(original.getUuid(), restored.getUuid());
        assertEquals(original.getUserId(), restored.getUserId());
        assertEquals(original.getTitle(), restored.getTitle());
        assertEquals(original.getContent(), restored.getContent());
        assertEquals(original.getSourceUrl(), restored.getSourceUrl());
        assertEquals(original.getCategoryId(), restored.getCategoryId());
        assertEquals(original.getNoteTime(), restored.getNoteTime());
        assertEquals(original.getPreviewTitle(), restored.getPreviewTitle());
        assertEquals(original.getPreviewDescription(), restored.getPreviewDescription());
        assertEquals(original.getPreviewContent(), restored.getPreviewContent());
        assertEquals(NoteResourceStatus.DONE, restored.getResourceStatus());
        assertEquals(original.getSummary(), restored.getSummary());
        assertEquals(original.getMemoryPath(), restored.getMemoryPath());
        assertEquals(original.getUpdatedAt(), restored.getUpdatedAt());
        assertEquals(original.isDeleted(), restored.isDeleted());
        assertEquals(tags, restored.getTags());
    }

    @Test
    void toDomain_withNullOptionalFields_shouldUseDefaults() {
        NoteModel model = new NoteModel();
        model.setUuid(UUID.randomUUID());
        model.setUserId(1L);
        // 其他字段均为 null

        NoteEntity entity = mapper.toDomain(model, List.of());

        assertNotNull(entity);
        assertEquals(1L, entity.getCategoryId()); // 默认值
        assertEquals(NoteResourceStatus.NONE, entity.getResourceStatus()); // null → NONE
        assertEquals(0L, entity.getUpdatedAt());
        assertFalse(entity.isDeleted());
    }

    @Test
    void toModel_deletedEntity_shouldSetIsDeletedTrue() {
        NoteEntity note = NoteEntity.create(UUID.randomUUID(), 1L);
        note.softDelete();

        NoteModel model = mapper.toModel(note);

        assertTrue(model.getIsDeleted());
    }
}
