package com.doublez.pocketmindserver.user.application;

import com.doublez.pocketmindserver.user.api.dto.UserSettingDto;

public interface UserSettingService {
    
    /**
     * 获取用户设置
     */
    UserSettingDto getSettings(long userId);

    /**
     * 更新用户的自定义提示词
     */
    void updateCustomSystemPrompt(long userId, String customSystemPrompt);

    /**
     * 获取用户的自定义提示词(内部调用, 带有缓存等优化)
     */
    String getCustomSystemPrompt(long userId);
}
