package com.doublez.pocketmindserver.asset.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Getter;
import lombok.Setter;

/**
 * 存储资产根路径配置。
 * 对应 application.yml 中 app.storage.local.root-dir。
 * Docker 映射时，宿主机目录挂载到容器的 /app/data/assets 即可。
 */
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "app.storage.local")
public class StorageProperties {

    /**
     * 本地存储根目录，容器内默认为 /app/data/assets。
     * 物理路径 = rootDir/{userId}/{storageKey}
     */
    private String rootDir = "/app/data/assets";
}
