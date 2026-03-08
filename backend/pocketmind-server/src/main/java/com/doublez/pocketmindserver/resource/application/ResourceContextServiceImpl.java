package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * 默认 Resource 上下文路径服务实现。
 */
@Service
public class ResourceContextServiceImpl implements ResourceContextService {

    @Override
    public ContextUri noteTextResource(long userId, UUID noteUuid) {
        return ContextUri.userResourcesRoot(userId)
                .child("notes")
                .child(noteUuid.toString())
                .child("source")
                .child("note-text");
    }

    @Override
    public ContextUri webClipResource(long userId, UUID noteUuid) {
        return ContextUri.userResourcesRoot(userId)
                .child("notes")
                .child(noteUuid.toString())
                .child("source")
                .child("web-clip");
    }

    @Override
    public ContextUri assetTextResource(long userId, UUID assetUuid) {
        return ContextUri.userResourcesRoot(userId)
                .child("assets")
                .child(assetUuid.toString())
                .child("source")
                .child("text");
    }

    @Override
    public ContextUri chatTranscriptResource(long userId, UUID sessionUuid) {
        return ContextUri.userResourcesRoot(userId)
                .child("chats")
                .child(sessionUuid.toString())
                .child("transcript");
    }
}
