package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Resource 检索降级服务。
 */
@Service
public class ResourceRetrievalFallbackService {

    private final ResourceRecordRepository resourceRecordRepository;

    public ResourceRetrievalFallbackService(ResourceRecordRepository resourceRecordRepository) {
        this.resourceRecordRepository = resourceRecordRepository;
    }

    public List<ContextSnippet> search(long userId, String queryText, int limit) {
        return resourceRecordRepository.searchByKeyword(userId, queryText, limit).stream()
                .map(this::toSnippet)
                .toList();
    }

    private ContextSnippet toSnippet(ResourceRecordEntity resource) {
        String abstractText = resource.getAbstractText() != null
                ? resource.getAbstractText()
                : resource.deriveDefaultAbstract();
        return new ContextSnippet(
                resource.getRootUri().value(),
                resource.getTitle(),
                abstractText,
                null,
                0.45,
                SnippetSource.RESOURCE
        );
    }
}
