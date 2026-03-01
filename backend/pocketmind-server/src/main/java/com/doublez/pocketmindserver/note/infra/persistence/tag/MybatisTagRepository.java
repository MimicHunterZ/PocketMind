package com.doublez.pocketmindserver.note.infra.persistence.tag;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.note.domain.tag.TagEntity;
import com.doublez.pocketmindserver.note.domain.tag.TagRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * TagRepository 的 MyBatis-Plus 实现
 */
@Repository
public class MybatisTagRepository implements TagRepository {

    private final TagMapper tagMapper;
    private final TagStructMapper structMapper;

    public MybatisTagRepository(TagMapper tagMapper, TagStructMapper structMapper) {
        this.tagMapper = tagMapper;
        this.structMapper = structMapper;
    }

    @Override
    public TagEntity findOrCreate(long userId, String name) {
        // INSERT ... ON CONFLICT DO NOTHING → 保证记录存在
        tagMapper.insertIgnoreConflict(UUID.randomUUID(), userId, name, System.currentTimeMillis());
        // 回查（此时记录一定存在）
        TagModel model = tagMapper.selectOne(new LambdaQueryWrapper<TagModel>()
                .eq(TagModel::getUserId, userId)
            .eq(TagModel::getName, name));
        return structMapper.toEntity(model);
    }

    @Override
    public List<TagEntity> findByUserId(long userId) {
        return tagMapper.selectList(new LambdaQueryWrapper<TagModel>()
                .eq(TagModel::getUserId, userId)
                .orderByAsc(TagModel::getName))
                .stream().map(structMapper::toEntity).toList();
    }
}
