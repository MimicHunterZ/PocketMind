package com.doublez.pocketmindserver.memory.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

import java.util.UUID;

/**
 * memory_records Mapper。
 */
@Mapper
public interface MemoryRecordMapper extends BaseMapper<MemoryRecordModel> {

    /**
     * 原子递增 active_count。
     */
    @Update("UPDATE memory_records SET active_count = active_count + 1 WHERE uuid = #{uuid} AND is_deleted = false")
    int incrementActiveCount(@Param("uuid") UUID uuid);
}
