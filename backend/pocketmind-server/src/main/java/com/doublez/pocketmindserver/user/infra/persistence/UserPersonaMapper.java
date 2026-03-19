package com.doublez.pocketmindserver.user.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.doublez.pocketmindserver.user.domain.UserPersonaEntity;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserPersonaMapper extends BaseMapper<UserPersonaEntity> {
}