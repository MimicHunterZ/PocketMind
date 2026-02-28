package com.doublez.pocketmindserver.attachment.infra.persistence.vision;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.attachment.infra.persistence.common.AttachmentStructMapper;
import com.doublez.pocketmindserver.shared.domain.LimitQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class MybatisAttachmentVisionRepository implements AttachmentVisionRepository {

    private final AttachmentVisionMapper mapper;
    private final AttachmentStructMapper structMapper;

    public MybatisAttachmentVisionRepository(AttachmentVisionMapper mapper, AttachmentStructMapper structMapper) {
        this.mapper = mapper;
        this.structMapper = structMapper;
    }

    @Override
    public void save(AttachmentVisionEntity vision) {
        AttachmentVisionModel model = structMapper.toVisionModel(vision);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.VISION_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + vision.getUuid());
        }
    }

    @Override
    public void update(AttachmentVisionEntity vision) {
        AttachmentVisionModel model = structMapper.toVisionModel(vision);
        mapper.update(model,
                new LambdaQueryWrapper<AttachmentVisionModel>()
                .eq(AttachmentVisionModel::getUuid, vision.getUuid())
                .eq(AttachmentVisionModel::getUserId, vision.getUserId())
        );
    }

    @Override
    public Optional<AttachmentVisionEntity> findByUuidAndUserId(UUID uuid, long userId) {
        AttachmentVisionModel model = mapper.selectOne(
                new LambdaQueryWrapper<AttachmentVisionModel>()
                        .eq(AttachmentVisionModel::getUuid, uuid)
                        .eq(AttachmentVisionModel::getUserId, userId)
        );
        return Optional.ofNullable(model).map(structMapper::toVisionDomain);
    }

    @Override
    public List<AttachmentVisionEntity> findByAttachmentUuid(long userId, UUID attachmentUuid) {
        return mapper.selectList(
                new LambdaQueryWrapper<AttachmentVisionModel>()
                        .eq(AttachmentVisionModel::getUserId, userId)
                        .eq(AttachmentVisionModel::getAssetUuid, attachmentUuid)
                        .eq(AttachmentVisionModel::getIsDeleted, false)
        ).stream().map(structMapper::toVisionDomain).toList();
    }

    @Override
    public List<AttachmentVisionEntity> findPendingByUserId(long userId, LimitQuery query) {
        return mapper.findPendingByUserId(userId, query.limit())
                .stream().map(structMapper::toVisionDomain).toList();
    }

    @Override
    public List<AttachmentVisionEntity> findChangedSince(long userId, SyncCursorQuery query) {
        return mapper.findChangedSince(userId, query.cursor(), query.limit())
                .stream().map(structMapper::toVisionDomain).toList();
    }

    @Override
    public List<AttachmentVisionEntity> findDoneByNoteUuid(long userId, UUID noteUuid) {
        return mapper.findDoneByNoteUuid(userId, noteUuid)
                .stream().map(structMapper::toVisionDomain).toList();
    }
}
