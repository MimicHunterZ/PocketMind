package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import java.util.UUID;

/**
 * Resource 上下文路径服务。
 */
public interface ResourceContextService {

    ContextUri noteTextResource(long userId, UUID noteUuid);

    ContextUri webClipResource(long userId, UUID noteUuid);

    ContextUri assetTextResource(long userId, UUID assetUuid);

    ContextUri chatTranscriptResource(long userId, UUID sessionUuid);

    ContextUri chatStageSummaryResource(long userId, UUID sessionUuid);
}
