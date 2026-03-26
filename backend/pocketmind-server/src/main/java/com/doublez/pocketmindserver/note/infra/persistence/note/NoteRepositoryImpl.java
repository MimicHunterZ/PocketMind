package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteTag;
import com.doublez.pocketmindserver.note.domain.tag.TagRepository;
import com.doublez.pocketmindserver.note.infra.persistence.tag.TagModel;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Repository
public class NoteRepositoryImpl implements NoteRepository {

    private final NoteMapper noteMapper;
    private final NoteStructMapper noteConverter;
    private final NoteTagRelationMapper relationMapper;
    private final TagRepository tagRepository;

    public NoteRepositoryImpl(NoteMapper noteMapper,
                              NoteStructMapper noteConverter,
                              NoteTagRelationMapper relationMapper,
                              TagRepository tagRepository) {
        this.noteMapper = noteMapper;
        this.noteConverter = noteConverter;
        this.relationMapper = relationMapper;
        this.tagRepository = tagRepository;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void save(NoteEntity note) {
        NoteModel model = noteConverter.toModel(note);
        int rows = noteMapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.NOTE_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR, "uuid=" + note.getUuid());
        }
        persistTagRelations(note);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(NoteEntity note) {
        NoteModel model = noteConverter.toModel(note);
        int rows = noteMapper.update(model, new LambdaQueryWrapper<NoteModel>()
                .eq(NoteModel::getUuid, note.getUuid())
                .eq(NoteModel::getUserId, note.getUserId()));
        if (rows != 1) {
            throw new BusinessException(ApiCode.NOTE_UPDATE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR, "uuid=" + note.getUuid());
        }

        relationMapper.deleteByNoteUuid(note.getUuid());
        persistTagRelations(note);
    }

    @Override
    public Optional<NoteEntity> findByUuidAndUserId(UUID uuid, long userId) {
        NoteModel model = noteMapper.selectOne(new LambdaQueryWrapper<NoteModel>()
                .eq(NoteModel::getUuid, uuid)
                .eq(NoteModel::getUserId, userId));
        return Optional.ofNullable(model).map(this::toDomainWithTags);
    }

    @Override
    public List<NoteEntity> findChangedSince(long userId, SyncCursorQuery query) {
        List<NoteModel> models = noteMapper.findChangedSince(userId, query.cursor(), query.limit());
        if (models.isEmpty()) {
            return List.of();
        }

        List<UUID> noteUuids = models.stream().map(NoteModel::getUuid).toList();
        List<NoteTagIdTuple> tagTuples = relationMapper.findTagIdsByNoteUuids(userId, noteUuids);

        Map<UUID, List<NoteTag>> tagsByNote = new HashMap<>();
        for (NoteTagIdTuple tuple : tagTuples) {
            tagsByNote.computeIfAbsent(tuple.getNoteUuid(), k -> new ArrayList<>())
                      .add(new NoteTag(tuple.getTagId()));
        }

        return models.stream()
                .map(m -> noteConverter.toDomain(m, tagsByNote.getOrDefault(m.getUuid(), List.of())))
                .toList();
    }

    @Override
    public void updateServerVersion(UUID uuid, long userId, long serverVersion) {
        noteMapper.updateServerVersion(uuid, userId, serverVersion);
    }

    @Override
    public void softDeleteByUuidAndUserId(UUID uuid, long userId, long updatedAt) {
        noteMapper.softDeleteByUuidAndUserId(uuid, userId, updatedAt);
    }

    @Override
    public void updateAiFields(UUID uuid, long userId, String aiSummary, String resourceStatus,
                               String previewTitle, String previewDescription, String previewContent) {
        noteMapper.updateAiFields(uuid, userId, aiSummary, resourceStatus, previewTitle, previewDescription, previewContent);
    }

    @Override
    public List<String> findTagNamesByUuid(UUID noteUuid, long userId) {
        return relationMapper.findTagsByNoteUuid(userId, noteUuid)
                .stream()
                .map(t -> t.getName())
                .toList();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void replaceTagNames(UUID noteUuid, long userId, List<String> tagNames) {
        List<TagModel> existingTags = relationMapper.findTagsByNoteUuid(userId, noteUuid);

        Map<String, Long> existingNameToId = new HashMap<>();
        for (TagModel existingTag : existingTags) {
            if (existingTag.getName() == null || existingTag.getName().isBlank()) {
                continue;
            }
            existingNameToId.put(existingTag.getName().strip(), existingTag.getId());
        }

        Set<String> desiredNames = new LinkedHashSet<>();
        if (tagNames != null) {
            for (String tagName : tagNames) {
                if (tagName == null || tagName.isBlank()) {
                    continue;
                }
                desiredNames.add(tagName.strip());
            }
        }

        Set<String> existingNames = existingNameToId.keySet();
        if (existingNames.equals(desiredNames)) {
            return;
        }

        Set<String> toRemove = new HashSet<>(existingNames);
        toRemove.removeAll(desiredNames);
        for (String tagName : toRemove) {
            Long tagId = existingNameToId.get(tagName);
            if (tagId != null) {
                relationMapper.delete(noteUuid, tagId);
            }
        }

        Set<String> toAdd = new LinkedHashSet<>(desiredNames);
        toAdd.removeAll(existingNames);
        for (String tagName : toAdd) {
            var tagEntity = tagRepository.findOrCreate(userId, tagName);
            relationMapper.insert(noteUuid, tagEntity.getId());
        }
    }

    private NoteEntity toDomainWithTags(NoteModel model) {
        List<Long> tagIds = relationMapper.findTagIdsByNoteUuid(model.getUserId(), model.getUuid());
        List<NoteTag> tags = tagIds.stream().map(NoteTag::new).toList();
        return noteConverter.toDomain(model, tags);
    }

    private void persistTagRelations(NoteEntity note) {
        if (note.getTags() == null || note.getTags().isEmpty()) {
            return;
        }
        for (NoteTag tag : note.getTags()) {
            relationMapper.insert(note.getUuid(), tag.tagId());
        }
    }
}

