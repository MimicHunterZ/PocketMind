package com.doublez.pocketmindserver.resource.application;

import java.util.UUID;

/**
 * 聊天转录 Resource 同步服务。
 */
public interface ChatTranscriptResourceSyncService {

    void syncSessionTranscript(long userId, UUID sessionUuid);

    void softDeleteBySession(long userId, UUID sessionUuid);
}
