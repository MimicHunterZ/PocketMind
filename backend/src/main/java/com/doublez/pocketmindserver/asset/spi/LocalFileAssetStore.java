package com.doublez.pocketmindserver.asset.spi;

import com.doublez.pocketmindserver.asset.config.StorageProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpRange;
import org.springframework.stereotype.Component;

import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;

/**
 * 本地磁盘存储实现。
 *
 * <p>物理路径规则：{rootDir}/{userDir}/{storageKey}，
 * 其中 userDir 为用户 ID 字符串，保证多租户隔离。
 * 适配 Docker volume 映射：宿主机目录挂载至容器内 rootDir 即可。</p>
 */
@Slf4j
@Component
public class LocalFileAssetStore implements AssetStore {

    private final StorageProperties storageProperties;

    public LocalFileAssetStore(StorageProperties storageProperties) {
        this.storageProperties = storageProperties;
    }

    // -------------------------------------------------------------------------
    // 私有工具
    // -------------------------------------------------------------------------

    /**
     * 计算目标物理路径。
     * 路径拼接：rootDir / userDir / storageKey（storageKey 内含子目录如 2025/01/15/xxx.jpg）
     */
    private Path resolveFilePath(String userDir, String storageKey) {
        return Path.of(storageProperties.getRootDir(), userDir, storageKey);
    }

    // 接口实现
    @Override
    public void saveFromFile(String userDir, String storageKey, File tempFile, String contentType) {
        Path target = resolveFilePath(userDir, storageKey);
        try {
            // 级联创建所有父目录（YYYY/MM/DD/）
            Files.createDirectories(target.getParent());
            Files.copy(tempFile.toPath(), target, StandardCopyOption.REPLACE_EXISTING);
            log.info("[AssetStore] 文件落盘成功: path={}, size={}B", target, tempFile.length());
        } catch (IOException e) {
            throw new UncheckedIOException("文件落盘失败: " + target, e);
        }
    }

    @Override
    public Resource getResource(String userDir, String storageKey) {
        Path path = resolveFilePath(userDir, storageKey);
        return new FileSystemResource(path);
    }

    @Override
    public ResourceRegion createResourceRegion(String userDir, String storageKey, HttpHeaders headers) {
        Resource resource = getResource(userDir, storageKey);

        long contentLength;
        try {
            contentLength = resource.contentLength();
        } catch (IOException e) {
            throw new UncheckedIOException("读取文件大小失败: " + storageKey, e);
        }

        List<HttpRange> ranges = headers.getRange();
        if (ranges.isEmpty()) {
            // 无 Range 头：全量返回（ResourceRegion 覆盖整个文件）
            return new ResourceRegion(resource, 0, contentLength);
        }

        // 只取第一个 Range（浏览器/移动端标准用法，多范围需求极为罕见）
        HttpRange range = ranges.get(0);
        long start = range.getRangeStart(contentLength);
        long end   = range.getRangeEnd(contentLength);
        // 防止末端超界
        long rangeLength = Math.min(end - start + 1, contentLength - start);

        log.debug("[AssetStore] Range 请求: bytes={}-{}/{} ({}B), key={}",
                start, end, contentLength, rangeLength, storageKey);

        return new ResourceRegion(resource, start, rangeLength);
    }

    @Override
    public void delete(String userDir, String storageKey) {
        Path path = resolveFilePath(userDir, storageKey);
        try {
            boolean deleted = Files.deleteIfExists(path);
            if (deleted) {
                log.info("[AssetStore] 文件已删除: {}", path);
            } else {
                log.warn("[AssetStore] 文件不存在，跳过删除: {}", path);
            }
        } catch (IOException e) {
            // 删除失败不应阻塞业务流程，仅打印警告
            log.warn("[AssetStore] 文件删除失败: {}", path, e);
        }
    }
}
