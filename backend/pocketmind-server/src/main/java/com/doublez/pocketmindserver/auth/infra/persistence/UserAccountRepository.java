package com.doublez.pocketmindserver.auth.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserAccountRepository extends BaseMapper<UserAccount> {
}
