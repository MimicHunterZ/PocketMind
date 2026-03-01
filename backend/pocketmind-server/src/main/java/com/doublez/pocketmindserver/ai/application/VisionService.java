package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
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

    //todo 鍒犻櫎
    public String analyzeImage(String localImagePath) {
        // 1. 璇诲彇鏈湴鏂囦欢
        var imageResource = new FileSystemResource(localImagePath);

        if (!imageResource.exists()) {
            return "閿欒锛氭枃浠朵笉瀛樺湪";
        }

        String systemPrompt = readPrompt(systemPromptResource);
        String userPrompt = readPrompt(userPromptResource);

        // 2. 鍙戣捣璋冪敤锛坴ision -> secondary -> fallback 鑷姩闄嶇骇锛?
        return failoverRouter.executeVision("vision-analyze", client -> Objects.requireNonNull(client.prompt()
                .system(s -> s.text(systemPrompt))
                .user(u -> u
                        .text(userPrompt)
                        // 3. 浼犲叆鍥剧墖锛孲pring AI 浼氳嚜鍔ㄥ皢鍏惰浆涓?Base64 鏍煎紡鐨?Data URL
                        .media(MimeTypeUtils.IMAGE_PNG, imageResource)
                )
                .call()
                .content()));
    }

    /**
     * 渚涘紓姝?Worker 璋冪敤锛氱洿鎺ヤ紶鍏ュ凡鍔犺浇鐨?Spring Resource 鍜岀湡瀹?MIME 绫诲瀷銆?
     *
     * @param imageResource 鍥剧墖璧勬簮锛堟潵鑷?AssetStore.getResource()锛?
     * @param mimeType      鐪熷疄 MIME锛屽 image/jpeg銆乮mage/png
     * @return AI 璇嗗埆鍑虹殑鍥剧墖鍐呭鎻忚堪鏂囨湰
     */
    public String analyzeImage(Resource imageResource, MimeType mimeType) {
        if (!imageResource.exists()) {
            return "閿欒锛氭枃浠朵笉瀛樺湪";
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
                    "璇诲彇鎻愮ず璇嶈祫婧愬け璐? " + resource.getDescription()
            );
            ex.initCause(e);
            throw ex;
        }
    }
}

