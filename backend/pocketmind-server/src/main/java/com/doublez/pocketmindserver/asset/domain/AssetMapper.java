package com.doublez.pocketmindserver.asset.domain;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

/**
 * Asset MyBatis-Plus Mapper，提供 assets 表的 CRUD。
 */
@Mapper
public interface AssetMapper extends BaseMapper<Asset> {
}
