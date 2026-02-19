package com.doublez.pocketmindserver.sync.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface SyncChangeLogMapper extends BaseMapper<SyncChangeLogModel> {

    /**
     * 拉取 updatedAt > cursor 的变更事件，按时间升序
     */
    @Select("""
            SELECT * FROM sync_change_log
            WHERE user_id = #{userId}
              AND updated_at > #{cursor}
            ORDER BY updated_at ASC
            LIMIT #{limit}
            """)
    List<SyncChangeLogModel> findSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);
}
