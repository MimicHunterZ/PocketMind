package com.doublez.pocketmindserver.resource.application.tool;

import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Map;
import java.util.Optional;

/**
 * 用户资源（文章/网页/记录等）工具集 — 供 AI 在对话中按需获取完整详情。
 *
 * <p>因为需要 userId 上下文，本类每次请求创建实例（非单例 Bean），
 * 通过 {@link ResourceToolSetFactory} 获取。
 */
@Slf4j
public class ResourceToolSet {

    private final long userId;
    private final ResourceRecordRepository resourceRecordRepository;
    private final Resource resourceDetailTemplate;

    public ResourceToolSet(long userId,
                           ResourceRecordRepository resourceRecordRepository,
                           Resource resourceDetailTemplate) {
        this.userId = userId;
        this.resourceRecordRepository = resourceRecordRepository;
        this.resourceDetailTemplate = resourceDetailTemplate;
    }

    @Tool(description = "获取资源的完整详情全文。当从概要信息中判断需要该资源的详细内容（事实参考）时应当调用此工具。")
    public String getResourceDetail(
            @ToolParam(description = "资源的 URI") String rootUri) {

        Optional<ResourceRecordEntity> opt = resourceRecordRepository.findByRootUriAndUserId(rootUri, userId);
        if (opt.isEmpty()) {
            return "未找到 URI 为 " + rootUri + " 的资源信息。";
        }

        ResourceRecordEntity r = opt.get();

        try {
            return PromptBuilder.render(resourceDetailTemplate, Map.of(
                    "title", r.getTitle() != null ? r.getTitle() : "未知标题",
                    "sourceUrl", r.getSourceUrl() != null ? r.getSourceUrl() : "无",
                    "content", r.getContent() != null && !r.getContent().isBlank() ? r.getContent() : "无详细内容"
            ));
        } catch (IOException e) {
            log.error("[resource-tool] 渲染 resource_detail 模板失败", e);
            return "资源详情加载失败。全文：" + (r.getContent() != null ? r.getContent() : "无");
        }
    }

    /**
     * 将本实例的方法导出为 ToolCallback 数组，供请求级注入。
     */
    public ToolCallback[] toToolCallbacks() {
        return ToolCallbacks.from(this);
    }

    @Component
    public static class ResourceToolSetFactory {

        private final ResourceRecordRepository resourceRecordRepository;

        @Value("classpath:prompts/resource/resource_detail.md")
        private Resource resourceDetailTemplate;

        public ResourceToolSetFactory(ResourceRecordRepository resourceRecordRepository) {
            this.resourceRecordRepository = resourceRecordRepository;
        }

        public ResourceToolSet createForUser(long userId) {
            return new ResourceToolSet(userId, resourceRecordRepository, resourceDetailTemplate);
        }
    }
}
