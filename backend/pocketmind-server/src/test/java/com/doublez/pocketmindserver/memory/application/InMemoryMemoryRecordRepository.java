package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryType;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 内存实现的 MemoryRecordRepository — 供测试使用。
 */
public class InMemoryMemoryRecordRepository implements MemoryRecordRepository {

    public final List<MemoryRecordEntity> records = new ArrayList<>();

    @Override
    public void save(MemoryRecordEntity entity) {
        records.add(entity);
    }

    @Override
    public void update(MemoryRecordEntity entity) {
        records.removeIf(r -> r.getUuid().equals(entity.getUuid()));
        records.add(entity);
    }

    @Override
    public Optional<MemoryRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
        return records.stream()
                .filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId && !r.isDeleted())
                .findFirst();
    }

    @Override
    public List<MemoryRecordEntity> findByUserIdAndType(long userId, MemoryType memoryType, int limit) {
        return records.stream()
                .filter(r -> r.getUserId() == userId && r.getMemoryType() == memoryType && !r.isDeleted())
                .limit(limit)
                .toList();
    }

    @Override
    public List<MemoryRecordEntity> findActiveByUserId(long userId, int limit) {
        return records.stream()
                .filter(r -> r.getUserId() == userId && !r.isDeleted())
                .limit(limit)
                .toList();
    }

    @Override
    public Optional<MemoryRecordEntity> findByMergeKey(long userId, MemoryType memoryType, String mergeKey) {
        return records.stream()
                .filter(r -> r.getUserId() == userId
                        && r.getMemoryType() == memoryType
                        && mergeKey.equals(r.getMergeKey())
                        && !r.isDeleted())
                .findFirst();
    }

    @Override
    public List<MemoryRecordEntity> searchByKeyword(long userId, String keyword, MemoryType memoryType, int limit) {
        return records.stream()
                .filter(r -> r.getUserId() == userId && !r.isDeleted())
                .filter(r -> memoryType == null || r.getMemoryType() == memoryType)
                .filter(r -> keyword == null || keyword.isBlank()
                        || (r.getTitle() != null && r.getTitle().contains(keyword))
                        || (r.getContent() != null && r.getContent().contains(keyword)))
                .limit(limit)
                .toList();
    }

    @Override
    public void incrementActiveCount(UUID uuid) {
        findByUuid(uuid).ifPresent(MemoryRecordEntity::incrementActiveCount);
    }

    @Override
    public List<MemoryTypeStat> countByUserGroupByType(long userId) {
        return records.stream()
                .filter(r -> r.getUserId() == userId && !r.isDeleted())
                .collect(Collectors.groupingBy(MemoryRecordEntity::getMemoryType, Collectors.counting()))
                .entrySet().stream()
                .map(e -> new MemoryTypeStat(e.getKey(), e.getValue()))
                .toList();
    }

    private Optional<MemoryRecordEntity> findByUuid(UUID uuid) {
        return records.stream()
                .filter(r -> r.getUuid().equals(uuid))
                .findFirst();
    }
}
