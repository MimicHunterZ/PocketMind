package com.doublez.pocketmindserver.asset.spi;

import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.HttpHeaders;

import java.io.File;

/**
 * 资产存储 SPI（Service Provider Interface）。
 *
 * <p>解耦具体存储介质：本次仅实现本地文件存储（LocalFileAssetStore），
 * 未来可无缝切换 S3、OSS 等实现，只需注入不同的 Bean 即可。</p>
 *
 * <p>路径约定：物理位置 = {rootDir}/{userDir}/{storageKey}，
 * 通过 userDir 参数（userId 字符串）实现多租户隔离，适配 Docker 挂载目录。</p>
 */
public interface AssetStore {

    /**
     * 将临时文件落盘到存储介质。
     *
     * @param userDir     用户目录标识（用户 ID 的字符串形式），实现租户隔离
     * @param storageKey  存储键，格式建议为 YYYY/MM/DD/{uuid}.{ext}
     * @param tempFile    上传管线中已写入内容的本地临时文件
     * @param contentType 文件的 MIME 类型（如 "image/jpeg"）
     */
    void saveFromFile(String userDir, String storageKey, File tempFile, String contentType);

    /**
     * 获取完整的 Spring {@link Resource} 抽象，用于全量响应（HTTP 200）。
     *
     * @param userDir    用户目录标识
     * @param storageKey 存储键
     * @return Spring Resource，调用方可直接写入 ResponseEntity body
     */
    Resource getResource(String userDir, String storageKey);

    /**
     * 核心分发接口：解析 HttpHeaders 中的 Range 请求头，返回 Spring 原生 {@link ResourceRegion}。
     *
     * <p>完美支持 HTTP 206 断点续传，同时为未来 S3 按段请求（GetObject with Range）预留架构接口。</p>
     *
     * @param userDir    用户目录标识
     * @param storageKey 存储键
     * @param headers    来自请求的 HttpHeaders，内部自动解析 Range 头
     * @return 包含 resource + 起始位置 + 长度的 ResourceRegion
     */
    ResourceRegion createResourceRegion(String userDir, String storageKey, HttpHeaders headers);

    /**
     * 删除物理文件（软删除时调用，或资产废弃时清理磁盘）。
     *
     * @param userDir    用户目录标识
     * @param storageKey 存储键
     */
    void delete(String userDir, String storageKey);
}
