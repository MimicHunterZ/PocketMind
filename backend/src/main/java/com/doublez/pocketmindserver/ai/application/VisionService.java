package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.stereotype.Service;
import org.springframework.util.MimeType;
import org.springframework.util.StreamUtils;
import org.springframework.util.MimeTypeUtils;
import org.springframework.http.HttpStatus;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

@Service
public class VisionService {

    private final AiFailoverRouter failoverRouter;

    private final Resource systemPromptResource;

    private final Resource userPromptResource;

    public VisionService(
            AiFailoverRouter failoverRouter,
            @Value("classpath:prompts/vision/system_prompt.md") Resource systemPromptResource,
            @Value("classpath:prompts/vision/user_prompt.md") Resource userPromptResource
    ) {
        this.failoverRouter = failoverRouter;
        this.systemPromptResource = systemPromptResource;
        this.userPromptResource = userPromptResource;
    }

    //todo 删除
    public String analyzeImage(String localImagePath) {
        // 1. 读取本地文件
        var imageResource = new FileSystemResource(localImagePath);

        if (!imageResource.exists()) {
            return "错误：文件不存在";
        }

        String systemPrompt = readPrompt(systemPromptResource);
        String userPrompt = readPrompt(userPromptResource);

        // 2. 发起调用（vision -> secondary -> fallback 自动降级）
        return failoverRouter.executeVision("vision-analyze", client -> Objects.requireNonNull(client.prompt()
                .system(s -> s.text(systemPrompt))
                .user(u -> u
                        .text(userPrompt)
                        // 3. 传入图片，Spring AI 会自动将其转为 Base64 格式的 Data URL
                        .media(MimeTypeUtils.IMAGE_PNG, imageResource)
                )
                .call()
                .content()));
    }

    /**
     * 供异步 Worker 调用：直接传入已加载的 Spring Resource 和真实 MIME 类型。
     *
     * @param imageResource 图片资源（来自 AssetStore.getResource()）
     * @param mimeType      真实 MIME，如 image/jpeg、image/png
     * @return AI 识别出的图片内容描述文本
     */
    public String analyzeImage(Resource imageResource, MimeType mimeType) {
        if (!imageResource.exists()) {
            return "错误：文件不存在";
        }

        String systemPrompt = readPrompt(systemPromptResource);
        String userPrompt   = readPrompt(userPromptResource);

        return failoverRouter.executeVision("vision-analyze", client -> Objects.requireNonNull(client.prompt()
                .system(s -> s.text(systemPrompt))
                .user(u -> u
                        .text(userPrompt)
                        .media(mimeType, imageResource)
                )
                .call()
                .content()));
    }

    private String readPrompt(Resource resource) {
        if (resource == null) {
            return "";
        }
        try {
            return StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            BusinessException ex = new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "读取提示词资源失败: " + resource.getDescription()
            );
            ex.initCause(e);
            throw ex;
        }
    }
}
