package com.doublez.pocketmindserver.asset.application.dto;

import java.util.UUID;

/**
 * 图片上传成功后的响应 DTO。
 *
 * <p>必须包含 uuid、width、height、size、mime，
 * 以便前端在收到响应的瞬间就能用 width/height 渲染骨架屏占位，
 * 避免图片加载完成前的布局跳跃（Layout Shift）。</p>
 *
 * @param uuid     附件业务 UUID，客户端后续用此 ID 拼接图片 URL
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
