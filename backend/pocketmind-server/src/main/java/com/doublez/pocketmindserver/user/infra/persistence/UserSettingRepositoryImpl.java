package com.doublez.pocketmindserver.user.infra.persistence;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.doublez.pocketmindserver.user.domain.UserSettingEntity;
import org.springframework.stereotype.Repository;

@Repository
public class UserSettingRepositoryImpl extends ServiceImpl<UserSettingMapper, UserSettingEntity> implements UserSettingRepository {
}
