package com.doublez.pocketmindserver.resource.infra.persistence;

import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ResourceIndexOutboxRepository 持久化测试。
 */
@ExtendWith(MockitoExtension.class)
class ResourceIndexOutboxRepositoryTest {

    @Mock
    private ResourceIndexOutboxMapper mapper;

    @Test
    void shouldAppendPendingEvent() {
        ResourceIndexOutboxRepository repository = new ResourceIndexOutboxRepositoryImpl(mapper);
        UUID eventUuid = UUID.randomUUID();

        repository.appendPending(eventUuid, 99L, UUID.randomUUID(), ResourceIndexOutboxConstants.OPERATION_UPSERT);

        ArgumentCaptor<ResourceIndexOutboxModel> captor = ArgumentCaptor.forClass(ResourceIndexOutboxModel.class);
        verify(mapper).insert(captor.capture());
        ResourceIndexOutboxModel model = captor.getValue();
        assertEquals(eventUuid, model.getUuid());
        assertEquals(ResourceIndexOutboxConstants.STATUS_PENDING, model.getStatus());
        assertEquals(ResourceIndexOutboxConstants.OPERATION_UPSERT, model.getOperation());
        assertEquals(99L, model.getUserId());
    }

    @Test
    void shouldPollPendingByRetryTime() {
        ResourceIndexOutboxRepository repository = new ResourceIndexOutboxRepositoryImpl(mapper);
        ResourceIndexOutboxModel pending = new ResourceIndexOutboxModel()
                .setUuid(UUID.randomUUID())
                .setStatus(ResourceIndexOutboxConstants.STATUS_PENDING)
                .setRetryCount(0)
                .setRetryAfter(0L);

        when(mapper.findRunnable(eq(123456L), eq(20))).thenReturn(List.of(pending));

        List<ResourceIndexOutboxEntity> events = repository.pollRunnable(123456L, 20);

        assertEquals(1, events.size());
        assertEquals(pending.getUuid(), events.getFirst().getUuid());
    }

    @Test
    void shouldMarkCompletedAndFailed() {
        ResourceIndexOutboxRepository repository = new ResourceIndexOutboxRepositoryImpl(mapper);
        UUID uuid = UUID.randomUUID();

        repository.markCompleted(uuid);
        verify(mapper).markCompleted(uuid);

        repository.markFailed(uuid, 5000L, "boom");
        verify(mapper).markFailed(eq(uuid), eq(5000L), eq("boom"));
    }

    @Test
    void shouldClaimRunnableAndMarkProcessing() {
        ResourceIndexOutboxRepository repository = new ResourceIndexOutboxRepositoryImpl(mapper);
        ResourceIndexOutboxModel pending = new ResourceIndexOutboxModel()
                .setId(9L)
                .setUuid(UUID.randomUUID())
                .setStatus(ResourceIndexOutboxConstants.STATUS_PENDING)
                .setRetryCount(0)
                .setRetryAfter(0L);

        when(mapper.claimRunnableForUpdate(eq(123456L), eq(20))).thenReturn(List.of(pending));
        when(mapper.markProcessingById(eq(9L))).thenReturn(1);

        List<ResourceIndexOutboxEntity> events = repository.claimRunnable(123456L, 20);

        assertEquals(1, events.size());
        assertEquals(pending.getUuid(), events.getFirst().getUuid());
        assertEquals(ResourceIndexOutboxConstants.STATUS_PROCESSING, events.getFirst().getStatus());
        verify(mapper).markProcessingById(9L);
    }

    @Test
    void shouldRecoverStaleProcessingByLeaseWindow() {
        ResourceIndexOutboxRepository repository = new ResourceIndexOutboxRepositoryImpl(mapper);

        when(mapper.recoverStaleProcessing(eq(190000L))).thenReturn(2);

        int recovered = repository.recoverStaleProcessing(200000L, 10000L);

        assertEquals(2, recovered);
        verify(mapper).recoverStaleProcessing(190000L);
    }
}
