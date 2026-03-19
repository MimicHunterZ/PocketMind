package com.doublez.pocketmindserver.user.infra.persistence;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.doublez.pocketmindserver.user.domain.UserPersonaEntity;
import org.springframework.stereotype.Repository;

@Repository
public class UserPersonaRepositoryImpl extends ServiceImpl<UserPersonaMapper, UserPersonaEntity> implements UserPersonaRepository {
}