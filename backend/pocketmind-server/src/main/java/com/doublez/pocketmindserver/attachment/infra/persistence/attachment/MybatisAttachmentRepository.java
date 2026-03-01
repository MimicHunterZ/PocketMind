package com.doublez.pocketmindserver.attachment.infra.persistence.attachment;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.doublez.pocketmindserver.attachment.domain.attachment.AttachmentEntity;
import com.doublez.pocketmindserver.attachment.domain.attachment.AttachmentRepository;
import com.doublez.pocketmindserver.attachment.infra.persistence.common.AttachmentStructMapper;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class MybatisAttachmentRepository implements AttachmentRepository {

    private final AttachmentMapper mapper;
    private final AttachmentStructMapper structMapper;

    public MybatisAttachmentRepository(AttachmentMapper mapper, AttachmentStructMapper structMapper) {
        this.mapper = mapper;
        this.structMapper = structMapper;
    }

    @Override
    public void save(AttachmentEntity attachment) {
        AttachmentModel model = structMapper.toModel(attachment);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.ATTACHMENT_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + attachment.getUuid());
        }
    }

    @Override
    public void update(AttachmentEntity attachment) {
        AttachmentModel model = structMapper.toModel(attachment);
        mapper.update(model,
                new LambdaQueryWrapper<AttachmentModel>()
                        .eq(AttachmentModel::getUuid, attachment.getUuid())
                        .eq(AttachmentModel::getUserId, attachment.getUserId())
        );
    }

    @Override
    public Optional<AttachmentEntity> findByUuidAndUserId(UUID uuid, long userId) {
        AttachmentModel model = mapper.selectOne(
                new LambdaQueryWrapper<AttachmentModel>()
                        .eq(AttachmentModel::getUuid, uuid)
                        .eq(AttachmentModel::getUserId, userId)
        );
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public List<AttachmentEntity> findByNoteUuid(long userId, UUID noteUuid) {
        return mapper.selectList(
                new LambdaQueryWrapper<AttachmentModel>()
                        .eq(AttachmentModel::getUserId, userId)
                        .eq(AttachmentModel::getNoteUuid, noteUuid)
                        .eq(AttachmentModel::getIsDeleted, false)
        ).stream().map(structMapper::toDomain).toList();
    }

    @Override
    public Optional<AttachmentEntity> findBySha256AndUserId(String sha256, long userId) {
        Page<AttachmentModel> page = new Page<>(1L, 1L);
        AttachmentModel model = mapper.selectPage(
                page,
                new LambdaQueryWrapper<AttachmentModel>()
                    .eq(AttachmentModel::getSha256, sha256)
                    .eq(AttachmentModel::getUserId, userId)
                    .eq(AttachmentModel::getIsDeleted, false)
                    .orderByDesc(AttachmentModel::getUpdatedAt)
            )
            .getRecords()
            .stream()
            .findFirst()
            .orElse(null);
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public List<AttachmentEntity> findChangedSince(long userId, SyncCursorQuery query) {
        return mapper.findChangedSince(userId, query.cursor(), query.limit())
                .stream().map(structMapper::toDomain).toList();
    }
}

