package com.doublez.pocketmindserver.user.application;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.doublez.pocketmindserver.user.api.dto.CreatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UpdatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UserPersonaDto;
import com.doublez.pocketmindserver.user.domain.UserPersonaEntity;
import com.doublez.pocketmindserver.user.domain.UserSettingEntity;
import com.doublez.pocketmindserver.user.infra.persistence.UserPersonaRepository;
import com.doublez.pocketmindserver.user.infra.persistence.UserSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserPersonaServiceImpl implements UserPersonaService {

    private final UserPersonaRepository userPersonaRepository;
    private final UserSettingService userSettingService;
    private final UserSettingRepository userSettingRepository;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public UserPersonaDto createPersona(long userId, CreatePersonaReq req) {
        UserPersonaEntity entity = new UserPersonaEntity();
        entity.setUserId(userId);
        entity.setName(req.getName());
        entity.setSystemPrompt(req.getSystemPrompt());
        entity.setUpdatedAt(Instant.now().toEpochMilli());
        
        userPersonaRepository.save(entity);

        // 如果目前没有 active 的 persona，默认激活它
        UserSettingEntity setting = userSettingRepository.getById(userId);
        if (setting == null || setting.getActivePersonaId() == null) {
            userSettingService.setActivePersona(userId, entity.getId());
        }

        return toDto(entity);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public UserPersonaDto updatePersona(long userId, long id, UpdatePersonaReq req) {
        UserPersonaEntity entity = getPersonaAndCheckOwner(userId, id);
        entity.setName(req.getName());
        entity.setSystemPrompt(req.getSystemPrompt());
        entity.setUpdatedAt(Instant.now().toEpochMilli());
        userPersonaRepository.updateById(entity);
        
        // 清除可能缓存
        userSettingService.setActivePersona(userId, userSettingRepository.getById(userId).getActivePersonaId());
        return toDto(entity);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void deletePersona(long userId, long id) {
        UserPersonaEntity entity = getPersonaAndCheckOwner(userId, id);
        userPersonaRepository.removeById(id);

        UserSettingEntity setting = userSettingRepository.getById(userId);
        if (setting != null && id == setting.getActivePersonaId()) {
            userSettingService.setActivePersona(userId, null);
        }
    }

    @Override
    public List<UserPersonaDto> listPersonas(long userId) {
        LambdaQueryWrapper<UserPersonaEntity> query = Wrappers.<UserPersonaEntity>lambdaQuery()
                .eq(UserPersonaEntity::getUserId, userId)
                .orderByDesc(UserPersonaEntity::getUpdatedAt);
        
        return userPersonaRepository.list(query).stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void setActivePersona(long userId, long id) {
        getPersonaAndCheckOwner(userId, id);
        userSettingService.setActivePersona(userId, id);
    }

    private UserPersonaEntity getPersonaAndCheckOwner(long userId, long id) {
        UserPersonaEntity entity = userPersonaRepository.getById(id);
        if (entity == null || !entity.getUserId().equals(userId)) {
            throw new IllegalArgumentException("Persona not found or permission denied");
        }
        return entity;
    }

    private UserPersonaDto toDto(UserPersonaEntity entity) {
        UserPersonaDto dto = new UserPersonaDto();
        dto.setId(entity.getId());
        dto.setName(entity.getName());
        dto.setSystemPrompt(entity.getSystemPrompt());
        dto.setUpdatedAt(entity.getUpdatedAt());
        return dto;
    }
}