package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.context.application.SessionCommitResult;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.domain.MemoryEvidence;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.ResponseFormat;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 记忆抽取器实现 — 使用 LLM 从对话摘要中提取用户长期记忆。
 *
 * <p>流程：
 * <ol>
 *   <li>加载 summary resource 获取摘要文本</li>
 *   <li>查询已有记忆供 LLM 去重参考</li>
 *   <li>调用 LLM 抽取记忆候选</li>
 *   <li>对每条候选检查 mergeKey 去重</li>
 *   <li>保存新记忆或更新已有记忆</li>
 * </ol>
 */
@Slf4j
@Service
public class MemoryExtractorServiceImpl implements MemoryExtractorService {

    private final MemoryRecordRepository memoryRecordRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final MemoryContextService memoryContextService;
    private final AiFailoverRouter aiFailoverRouter;

    @Value("classpath:prompts/compression/memory_extraction_system.md")
    private Resource extractionSystemTemplate;

    @Value("classpath:prompts/compression/memory_extraction_user.md")
    private Resource extractionUserTemplate;

    public MemoryExtractorServiceImpl(MemoryRecordRepository memoryRecordRepository,
                                      ResourceRecordRepository resourceRecordRepository,
                                      MemoryContextService memoryContextService,
                                      AiFailoverRouter aiFailoverRouter) {
        this.memoryRecordRepository = memoryRecordRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.memoryContextService = memoryContextService;
        this.aiFailoverRouter = aiFailoverRouter;
    }

    @Override
    public int extractFromCommit(long userId, UUID sessionUuid, SessionCommitResult commitResult) {
        log.info("[memory-extractor] 开始抽取记忆: userId={}, sessionUuid={}", userId, sessionUuid);

        // 1. 获取摘要文本
        String summary = loadSummaryText(userId, commitResult.summaryResourceUuid());
        if (summary == null || summary.isBlank()) {
            log.info("[memory-extractor] 摘要为空，跳过记忆抽取");
            return 0;
        }

        // 2. 查询已有记忆（用于 LLM 去重参考）
        List<MemoryRecordEntity> existingMemories = memoryRecordRepository.findActiveByUserId(userId, 50);
        String existingMemoriesText = renderExistingMemories(existingMemories);

        // 3. 调用 LLM 抽取
        MemoryExtractionResult result;
        try {
            result = callLlmExtraction(
                    commitResult.abstractText() != null ? commitResult.abstractText() : "未命名对话",
                    summary,
                    existingMemoriesText
            );
        } catch (Exception e) {
            log.error("[memory-extractor] LLM 抽取失败: userId={}, error={}", userId, e.getMessage(), e);
            return 0;
        }

        if (result == null || result.memories() == null || result.memories().isEmpty()) {
            log.info("[memory-extractor] LLM 未抽取到有效记忆");
            return 0;
        }

        // 4. 去重并保存
        String sourceContextUri = "pm://sessions/" + sessionUuid;
        int savedCount = 0;
        for (MemoryExtractionResult.MemoryCandidate candidate : result.memories()) {
            MemoryType memoryType = candidate.resolveMemoryType();
            if (memoryType == null) {
                log.warn("[memory-extractor] 未知记忆类型: {}", candidate.memoryType());
                continue;
            }

            // 构建 URI
            ContextUri rootUri = memoryContextService.userMemoryByType(userId, memoryType);

            // 检查 mergeKey 是否已存在同类记忆
            if (candidate.mergeKey() != null && !candidate.mergeKey().isBlank()) {
                Optional<MemoryRecordEntity> existing =
                        memoryRecordRepository.findByMergeKey(userId, memoryType, candidate.mergeKey());
                if (existing.isPresent()) {
                    // 更新已有记忆
                    MemoryRecordEntity record = existing.get();
                    record.updateContent(candidate.title(), candidate.abstractText(), candidate.content());
                    record.addEvidence(MemoryEvidence.of(sourceContextUri, candidate.title()));
                    memoryRecordRepository.update(record);
                    log.debug("[memory-extractor] 合并已有记忆: mergeKey={}", candidate.mergeKey());
                    savedCount++;
                    continue;
                }
            }

            // 新建记忆
            MemoryRecordEntity newRecord = MemoryRecordEntity.createFromExtraction(
                    userId,
                    memoryType,
                    rootUri,
                    candidate.title(),
                    candidate.abstractText(),
                    candidate.content(),
                    sourceContextUri,
                    List.of(MemoryEvidence.of(sourceContextUri, candidate.title())),
                    candidate.mergeKey()
            );
            memoryRecordRepository.save(newRecord);
            savedCount++;
            log.debug("[memory-extractor] 保存新记忆: type={}, title={}", memoryType, candidate.title());
        }

        log.info("[memory-extractor] 记忆抽取完成: userId={}, extracted={}, saved={}",
                userId, result.memories().size(), savedCount);
        return savedCount;
    }

    // ─── 内部方法 ──────────────────────────────────────────────

    private String loadSummaryText(long userId, UUID summaryResourceUuid) {
        if (summaryResourceUuid == null) {
            return null;
        }
        return resourceRecordRepository.findByUuidAndUserId(summaryResourceUuid, userId)
                .map(ResourceRecordEntity::getContent)
                .orElse(null);
    }

    private String renderExistingMemories(List<MemoryRecordEntity> memories) {
        if (memories.isEmpty()) {
            return "（暂无已有记忆）";
        }
        StringBuilder sb = new StringBuilder();
        for (MemoryRecordEntity m : memories) {
            sb.append("- [").append(m.getMemoryType().name()).append("] ")
                    .append(m.getTitle())
                    .append(" (mergeKey=").append(m.getMergeKey()).append(")")
                    .append("\n");
        }
        return sb.toString();
    }

    private MemoryExtractionResult callLlmExtraction(String sessionTitle, String summary, String existingMemories) {
        BeanOutputConverter<MemoryExtractionResult> outputConverter =
                new BeanOutputConverter<>(MemoryExtractionResult.class);

        OpenAiChatOptions options = OpenAiChatOptions.builder()
                .responseFormat(new ResponseFormat(
                        ResponseFormat.Type.JSON_OBJECT,
                        outputConverter.getJsonSchema()))
                .build();

        try {
            Prompt prompt = PromptBuilder.build(
                    extractionSystemTemplate,
                    extractionUserTemplate,
                    Map.of(
                            "sessionTitle", sessionTitle,
                            "summary", summary,
                            "existingMemories", existingMemories,
                            "format", outputConverter.getFormat()
                    ),
                    options
            );

            return aiFailoverRouter.executeChat("memoryExtraction", client -> {
                String raw = client.prompt(prompt).call().content();
                return outputConverter.convert(raw);
            });
        } catch (IOException e) {
            throw new RuntimeException("加载记忆抽取提示词模板失败", e);
        }
    }
}
