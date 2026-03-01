package com.doublez.pocketmindserver.asset.api.dto;

import java.util.UUID;

/**
 * 图片上传成功后的响应 DTO。
 *
 * @param uuid     附件业务 UUID
 * @param mime     MIME 类型，如 image/jpeg
 * @param size     文件字节数
 * @param width    图片宽度（px）
 * @param height   图片高度（px）
 */
public record UploadResultDTO(
        UUID uuid,
        String mime,
        long size,
        int width,
        int height
) {
}
