package com.doublez.pocketmindserver.asset.infra;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.asset.domain.NoteAttachment;
import com.doublez.pocketmindserver.asset.domain.NoteAttachmentMapper;
import com.doublez.pocketmindserver.asset.domain.NoteAttachmentRepository;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * NoteAttachmentRepository 的 MyBatis-Plus 实现。
 */
@Repository
public class NoteAttachmentDBRepository implements NoteAttachmentRepository {

    private final NoteAttachmentMapper mapper;

    public NoteAttachmentDBRepository(NoteAttachmentMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void save(NoteAttachment attachment) {
        int rows = mapper.insert(attachment);
        if (rows != 1) {
            throw new BusinessException(
                    ApiCode.ATTACHMENT_SAVE_FAILED,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + attachment.getUuid());
        }
    }

    @Override
    public Optional<NoteAttachment> findByUuidAndUserId(UUID uuid, long userId) {
        NoteAttachment model = mapper.selectOne(
                new LambdaQueryWrapper<NoteAttachment>()
                        .eq(NoteAttachment::getUuid, uuid)
                        .eq(NoteAttachment::getUserId, userId)
        );
        return Optional.ofNullable(model);
    }
}
