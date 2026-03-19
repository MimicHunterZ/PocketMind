package com.doublez.pocketmindserver.user.application;

import com.doublez.pocketmindserver.user.api.dto.CreatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UpdatePersonaReq;
import com.doublez.pocketmindserver.user.api.dto.UserPersonaDto;

import java.util.List;

public interface UserPersonaService {
    
    UserPersonaDto createPersona(long userId, CreatePersonaReq req);

    UserPersonaDto updatePersona(long userId, long id, UpdatePersonaReq req);

    void deletePersona(long userId, long id);

    List<UserPersonaDto> listPersonas(long userId);

    void setActivePersona(long userId, long id);
}