package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteTag;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;


@Repository
public class MybatisNoteRepository implements NoteRepository {

    private final NoteMapper noteMapper;
    private final NoteStructMapper noteConverter;
    private final NoteTagRelationMapper relationMapper;

    public MybatisNoteRepository(NoteMapper noteMapper,
                                NoteStructMapper noteConverter,
                                NoteTagRelationMapper relationMapper) {
        this.noteMapper = noteMapper;
        this.noteConverter = noteConverter;
        this.relationMapper = relationMapper;
    }

    @Override
    public void save(NoteEntity note) {
        NoteModel model = noteConverter.toModel(note);
        int rows = noteMapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.NOTE_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + note.getUuid());
        }

        // 保存标签关联（作为 Note 聚合的一部分）
        persistTagRelations(note);
    }

    @Override
    public void update(NoteEntity note) {
        NoteModel model = noteConverter.toModel(note);
        int rows = noteMapper.update(model, new LambdaQueryWrapper<NoteModel>()
                .eq(NoteModel::getUuid, note.getUuid())
                .eq(NoteModel::getUserId, note.getUserId()));
        if (rows != 1) {
            throw new BusinessException(ApiCode.NOTE_UPDATE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + note.getUuid());
        }

        // 简化策略：重建标签关联
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
    public List<NoteEntity> findByUserId(long userId, PageQuery pageQuery) {
        Page<NoteModel> page = new Page<>(pageQuery.pageIndex() + 1L, pageQuery.pageSize());
        return noteMapper.selectPage(page, new LambdaQueryWrapper<NoteModel>()
                .eq(NoteModel::getUserId, userId)
            .orderByDesc(NoteModel::getUpdatedAt))
            .getRecords()
            .stream()
            .map(this::toDomainWithTags)
            .toList();
    }

    @Override
    public List<NoteEntity> searchByText(long userId, String query, PageQuery pageQuery) {
        return noteMapper.fullTextSearch(userId, query, pageQuery.limit(), pageQuery.offset())
                .stream().map(this::toDomainWithTags).toList();
    }

    @Override
    public List<NoteEntity> findChangedSince(long userId, SyncCursorQuery query) {
        return noteMapper.findChangedSince(userId, query.cursor(), query.limit())
                .stream().map(this::toDomainWithTags).toList();
    }

    @Override
    public List<NoteEntity> findByUuids(long userId, List<UUID> uuids) {
        if (uuids == null || uuids.isEmpty()) return List.of();
        return noteMapper.selectList(new LambdaQueryWrapper<NoteModel>()
                .eq(NoteModel::getUserId, userId)
                .in(NoteModel::getUuid, uuids))
                .stream().map(this::toDomainWithTags).toList();
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