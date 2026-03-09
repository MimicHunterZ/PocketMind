package com.doublez.pocketmindserver.memory.infra.persistence;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 长期记忆仓储 MyBatis-Plus 实现。
 */
@Slf4j
@Repository
public class MybatisMemoryRecordRepository implements MemoryRecordRepository {

    private final MemoryRecordMapper mapper;
    private final MemoryRecordStructMapper structMapper;

    public MybatisMemoryRecordRepository(MemoryRecordMapper mapper,
                                         MemoryRecordStructMapper structMapper) {
        this.mapper = mapper;
        this.structMapper = structMapper;
    }

    @Override
    public void save(MemoryRecordEntity entity) {
        MemoryRecordModel model = structMapper.toModel(entity);
        mapper.insert(model);
        log.debug("[memory-repo] 保存记忆: uuid={}, type={}", entity.getUuid(), entity.getMemoryType());
    }

    @Override
    public void update(MemoryRecordEntity entity) {
        MemoryRecordModel existing = findModelByUuid(entity.getUuid());
        if (existing == null) {
            log.warn("[memory-repo] 更新失败，记忆不存在: uuid={}", entity.getUuid());
            return;
        }
        MemoryRecordModel model = structMapper.toModel(entity);
        model.setId(existing.getId());
        mapper.updateById(model);
        log.debug("[memory-repo] 更新记忆: uuid={}", entity.getUuid());
    }

    @Override
    public Optional<MemoryRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUuid, uuid)
                .eq(MemoryRecordModel::getUserId, userId);
        MemoryRecordModel model = mapper.selectOne(wrapper);
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public List<MemoryRecordEntity> findByUserIdAndType(long userId, MemoryType memoryType, int limit) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUserId, userId)
                .eq(MemoryRecordModel::getMemoryType, memoryType.name())
                .orderByDesc(MemoryRecordModel::getActiveCount)
                .orderByDesc(MemoryRecordModel::getUpdatedAt)
                .last("LIMIT " + limit);
        return mapper.selectList(wrapper).stream()
                .map(structMapper::toDomain)
                .toList();
    }

    @Override
    public List<MemoryRecordEntity> findActiveByUserId(long userId, int limit) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUserId, userId)
                .eq(MemoryRecordModel::getStatus, "ACTIVE")
                .orderByDesc(MemoryRecordModel::getActiveCount)
                .orderByDesc(MemoryRecordModel::getUpdatedAt)
                .last("LIMIT " + limit);
        return mapper.selectList(wrapper).stream()
                .map(structMapper::toDomain)
                .toList();
    }

    @Override
    public Optional<MemoryRecordEntity> findByMergeKey(long userId, MemoryType memoryType, String mergeKey) {
        if (mergeKey == null || mergeKey.isBlank()) {
            return Optional.empty();
        }
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUserId, userId)
                .eq(MemoryRecordModel::getMemoryType, memoryType.name())
                .eq(MemoryRecordModel::getMergeKey, mergeKey);
        MemoryRecordModel model = mapper.selectOne(wrapper);
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public List<MemoryRecordEntity> searchByKeyword(long userId, String keyword, MemoryType memoryType, int limit) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUserId, userId)
                .eq(MemoryRecordModel::getStatus, "ACTIVE");

        if (memoryType != null) {
            wrapper.eq(MemoryRecordModel::getMemoryType, memoryType.name());
        }

        if (keyword != null && !keyword.isBlank()) {
            String likePattern = "%" + keyword.trim() + "%";
            wrapper.and(w -> w
                    .like(MemoryRecordModel::getTitle, likePattern)
                    .or().like(MemoryRecordModel::getAbstractText, likePattern)
                    .or().like(MemoryRecordModel::getContent, likePattern));
        }

        wrapper.orderByDesc(MemoryRecordModel::getActiveCount)
                .orderByDesc(MemoryRecordModel::getUpdatedAt)
                .last("LIMIT " + limit);

        return mapper.selectList(wrapper).stream()
                .map(structMapper::toDomain)
                .toList();
    }

    @Override
    public void incrementActiveCount(UUID uuid) {
        mapper.incrementActiveCount(uuid);
    }

    @Override
    public List<MemoryTypeStat> countByUserGroupByType(long userId) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUserId, userId)
                .eq(MemoryRecordModel::getStatus, "ACTIVE")
                .select(MemoryRecordModel::getMemoryType)
                .groupBy(MemoryRecordModel::getMemoryType);

        // MyBatis-Plus 不直接支持 COUNT + GROUP BY 的 LambdaQuery，
        // 用 selectList 后 Java 层统计
        List<MemoryRecordModel> allActive = mapper.selectList(
                new LambdaQueryWrapper<MemoryRecordModel>()
                        .eq(MemoryRecordModel::getUserId, userId)
                        .eq(MemoryRecordModel::getStatus, "ACTIVE")
                        .select(MemoryRecordModel::getMemoryType));

        return allActive.stream()
                .collect(java.util.stream.Collectors.groupingBy(
                        MemoryRecordModel::getMemoryType,
                        java.util.stream.Collectors.counting()))
                .entrySet().stream()
                .map(e -> new MemoryTypeStat(MemoryType.valueOf(e.getKey()), e.getValue()))
                .toList();
    }

    // ─── 内部方法 ──────────────────────────────────────────────

    private MemoryRecordModel findModelByUuid(UUID uuid) {
        LambdaQueryWrapper<MemoryRecordModel> wrapper = new LambdaQueryWrapper<MemoryRecordModel>()
                .eq(MemoryRecordModel::getUuid, uuid);
        return mapper.selectOne(wrapper);
    }
}
