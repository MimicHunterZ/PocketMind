package com.doublez.pocketmindserver.user.application;

import com.doublez.pocketmindserver.user.api.dto.UserSettingDto;
import com.doublez.pocketmindserver.user.domain.UserSettingEntity;
import com.doublez.pocketmindserver.user.infra.persistence.UserSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserSettingServiceImpl implements UserSettingService {

    private final UserSettingRepository userSettingRepository;

    @Override
    public UserSettingDto getSettings(long userId) {
        UserSettingEntity entity = userSettingRepository.getById(userId);
        UserSettingDto dto = new UserSettingDto();
        if (entity != null) {
            dto.setCustomSystemPrompt(entity.getCustomSystemPrompt());
        }
        return dto;
    }

    @Override
    @CacheEvict(value = "user_settings_cache", key = "#userId")
    public void updateCustomSystemPrompt(long userId, String customSystemPrompt) {
        UserSettingEntity entity = userSettingRepository.getById(userId);
        if (entity == null) {
            entity = new UserSettingEntity();
            entity.setUserId(userId);
            entity.setCustomSystemPrompt(customSystemPrompt);
            userSettingRepository.save(entity);
        } else {
            entity.setCustomSystemPrompt(customSystemPrompt);
            userSettingRepository.updateById(entity);
        }
    }

    @Override
    @Cacheable(value = "user_settings_cache", key = "#userId")
    public String getCustomSystemPrompt(long userId) {
        return Optional.ofNullable(userSettingRepository.getById(userId))
                .map(UserSettingEntity::getCustomSystemPrompt)
                .orElse(null);
    }
}
