package com.doublez.pocketmindserver.user.application;

import com.doublez.pocketmindserver.user.api.dto.UserSettingDto;

public interface UserSettingService {
    
    /**
     * 获取用户设置
     */
    UserSettingDto getSettings(long userId);

    /**
     * 设置当前生效的人格
     */
    void setActivePersona(long userId, Long personaId);

    /**
     * 获取用户当前生效的人格 Prompt(内部调用, 带有缓存等优化)
     */
    String getActivePersonaPrompt(long userId);
}
