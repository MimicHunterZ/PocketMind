package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * ChatTranscriptResourceSyncService 同步测试。
 */
class ChatTranscriptResourceSyncServiceTest {

    private final InMemoryChatMessageRepository chatMessageRepository = new InMemoryChatMessageRepository();
    private final InMemoryChatSessionRepository chatSessionRepository = new InMemoryChatSessionRepository();
    private final InMemoryResourceRecordRepository resourceRecordRepository = new InMemoryResourceRecordRepository();
    private final ChatTranscriptResourceSyncService service = new ChatTranscriptResourceSyncServiceImpl(
            chatMessageRepository,
            chatSessionRepository,
            resourceRecordRepository,
            new ResourceContextServiceImpl()
    );

    @Test
    void shouldCreateTranscriptResourceFromMessages() {
        UUID sessionUuid = UUID.randomUUID();
        chatSessionRepository.session = ChatSessionEntity.create(sessionUuid, 7L, null, "聊天标题");
        chatMessageRepository.storage.add(ChatMessageEntity.create(UUID.randomUUID(), 7L, sessionUuid, ChatRole.USER, "你好", List.of()));
        chatMessageRepository.storage.add(ChatMessageEntity.create(UUID.randomUUID(), 7L, sessionUuid, ChatRole.ASSISTANT, "你好，我在", List.of()));

        service.syncSessionTranscript(7L, sessionUuid);

        List<ResourceRecordEntity> resources = resourceRecordRepository.findBySessionUuid(7L, sessionUuid);
        assertEquals(1, resources.size());
        assertEquals(ResourceSourceType.CHAT_TRANSCRIPT, resources.getFirst().getSourceType());
        assertTrue(resources.getFirst().getContent().contains("用户：你好"));
        assertTrue(resources.getFirst().getContent().contains("助手：你好，我在"));
    }

    @Test
    void shouldSoftDeleteTranscriptWhenSessionBecomesEmpty() {
        UUID sessionUuid = UUID.randomUUID();
        chatSessionRepository.session = ChatSessionEntity.create(sessionUuid, 8L, null, "聊天标题");
        ChatMessageEntity user = ChatMessageEntity.create(UUID.randomUUID(), 8L, sessionUuid, ChatRole.USER, "你好", List.of());
        chatMessageRepository.storage.add(user);
        service.syncSessionTranscript(8L, sessionUuid);

        user.softDelete();
        service.syncSessionTranscript(8L, sessionUuid);

        assertTrue(resourceRecordRepository.storage.stream().allMatch(ResourceRecordEntity::isDeleted));
    }

    private static final class InMemoryChatMessageRepository implements ChatMessageRepository {
        private final List<ChatMessageEntity> storage = new ArrayList<>();

        @Override
        public void save(ChatMessageEntity message) {
            storage.add(message);
        }

        @Override
        public void appendContent(UUID messageUuid, long userId, String delta, long updatedAt) {
        }

        @Override
        public Optional<ChatMessageEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(message -> message.getUuid().equals(uuid) && message.getUserId() == userId).findFirst();
        }

        @Override
        public List<ChatMessageEntity> findBySessionUuid(long userId, UUID sessionUuid, PageQuery pageQuery) {
            return storage.stream()
                    .filter(message -> message.getUserId() == userId)
                    .filter(message -> message.getSessionUuid().equals(sessionUuid))
                    .sorted(Comparator.comparingLong(ChatMessageEntity::getUpdatedAt))
                    .toList();
        }

        @Override
        public List<ChatMessageEntity> findChangedSince(long userId, SyncCursorQuery query) {
            return List.of();
        }

        @Override
        public List<ChatMessageEntity> findChain(UUID leafUuid, long userId) {
            return List.of();
        }

        @Override
        public List<ChatMessageEntity> findChildrenByParentUuid(UUID parentUuid, long userId) {
            return List.of();
        }

        @Override
        public void updateRating(UUID uuid, long userId, int rating) {
        }

        @Override
        public void updateContent(UUID uuid, long userId, String content) {
        }

        @Override
        public void updateBranchAlias(UUID uuid, long userId, String alias) {
        }

        @Override
        public void softDeleteByUuids(List<UUID> uuids, long userId) {
        }

        @Override
        public void softDeleteAssistantChildren(UUID parentUuid, long userId) {
        }
    }

    private static final class InMemoryChatSessionRepository implements ChatSessionRepository {
        private ChatSessionEntity session;

        @Override
        public void save(ChatSessionEntity session) {
            this.session = session;
        }

        @Override
        public void update(ChatSessionEntity session) {
            this.session = session;
        }

        @Override
        public Optional<ChatSessionEntity> findByUuidAndUserId(UUID uuid, long userId) {
            if (session != null && session.getUuid().equals(uuid) && session.getUserId() == userId) {
                return Optional.of(session);
            }
            return Optional.empty();
        }

        @Override
        public List<ChatSessionEntity> findByUserId(long userId, PageQuery pageQuery) {
            return List.of();
        }

        @Override
        public List<ChatSessionEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return List.of();
        }

        @Override
        public List<ChatSessionEntity> findChangedSince(long userId, SyncCursorQuery query) {
            return List.of();
        }

        @Override
        public void updateTitleByUuidAndUserId(UUID uuid, long userId, String title) {
        }

        @Override
        public void deleteByUuidAndUserId(UUID uuid, long userId) {
        }
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        private final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override
        public void save(ResourceRecordEntity resourceRecord) {
            storage.add(resourceRecord);
        }

        @Override
        public void update(ResourceRecordEntity resourceRecord) {
            for (int i = 0; i < storage.size(); i++) {
                if (storage.get(i).getUuid().equals(resourceRecord.getUuid())) {
                    storage.set(i, resourceRecord);
                    return;
                }
            }
            storage.add(resourceRecord);
        }

        @Override
        public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(resource -> resource.getUuid().equals(uuid) && resource.getUserId() == userId).findFirst();
        }

        @Override
        public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return List.of();
        }

        @Override
        public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) {
            return storage.stream()
                    .filter(resource -> resource.getUserId() == userId)
                    .filter(resource -> sessionUuid.equals(resource.getSessionUuid()))
                    .filter(resource -> !resource.isDeleted())
                    .toList();
        }

        @Override
        public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) {
            return List.of();
        }
    }
}
