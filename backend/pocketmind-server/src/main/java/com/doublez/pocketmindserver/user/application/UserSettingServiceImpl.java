package com.doublez.pocketmindserver.user.application;

import com.doublez.pocketmindserver.user.api.dto.UserSettingDto;
import com.doublez.pocketmindserver.user.domain.UserPersonaEntity;
import com.doublez.pocketmindserver.user.domain.UserSettingEntity;
import com.doublez.pocketmindserver.user.infra.persistence.UserPersonaRepository;
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
    private final UserPersonaRepository userPersonaRepository;

    @Override
    public UserSettingDto getSettings(long userId) {
        UserSettingEntity entity = userSettingRepository.getById(userId);
        UserSettingDto dto = new UserSettingDto();
        if (entity != null) {
            dto.setActivePersonaId(entity.getActivePersonaId());
        }
        return dto;
    }

    @Override
    @CacheEvict(value = "user_settings_cache", key = "#userId")
    public void setActivePersona(long userId, Long personaId) {
        UserSettingEntity entity = userSettingRepository.getById(userId);
        if (entity == null) {
            entity = new UserSettingEntity();
            entity.setUserId(userId);
            entity.setActivePersonaId(personaId);
            userSettingRepository.save(entity);
        } else {
            entity.setActivePersonaId(personaId);
            userSettingRepository.updateById(entity);
        }
    }

    @Override
    @Cacheable(value = "user_settings_cache", key = "#userId")
    public String getActivePersonaPrompt(long userId) {
        Long personaId = Optional.ofNullable(userSettingRepository.getById(userId))
                .map(UserSettingEntity::getActivePersonaId)
                .orElse(null);
        if (personaId == null) {
            return null;
        }
        return Optional.ofNullable(userPersonaRepository.getById(personaId))
                .map(UserPersonaEntity::getSystemPrompt)
                .orElse(null);
    }
}
