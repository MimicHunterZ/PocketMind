---
name: "asset-image-subsystem"
description: "PocketMind 图片资产存储与分发子系统。涵盖 SPI 存储抽象层、防 OOM 上传管线、HTTP 206 断点续传分发、MyBatis-Plus 持久化以及 Spring Boot 4.x 关键陷阱。当用户讨论图片上传、图片下载、Range 请求、AssetStore、NoteAttachment、ImageUploadService、ImageServeService、AssetController 时触发。"
version: 1.0.0
category: "backend"
modularized: false
user-invocable: false
tags: ['java', 'spring-boot', 'image', 'upload', 'http-range', 'mybatis-plus', 'storage-spi']
related-skills: ['headless-scraping']
updated: 2026-02-22
status: "active"
---

## 快速参考（30 秒）

**图片资产子系统**：负责图片的 上传→落盘→持久化→分发 完整生命周期。

**Auto-Triggers**：提到 AssetStore / NoteAttachment / ImageUploadService / ImageServeService / AssetController / HTTP Range 图片 / ResourceRegion / 图片上传 OOM

**核心能力**：

- 防 OOM 上传：临时文件 + ImageReader 仅读文件头
- HTTP 206 断点续传：Spring `ResourceRegion` + `ResourceRegionHttpMessageConverter`
- 存储 SPI 抽象：本地磁盘实现，接口预留 S3 扩展
- 越权防御：所有分发路径经 DB 归属校验
- Spring Boot 4.x 兼容修复：手动注册 Converter

---

## 包结构

```
backend/src/main/java/com/doublez/pocketmindserver/
└── asset/
    ├── api/
    │   └── AssetController.java          # REST 端点，Range 决策层
    ├── application/
    │   ├── ImageUploadService.java        # 上传管线（防 OOM + 宽高提取）
    │   ├── ImageServeService.java         # 分发服务（200/206 双模式）
    │   └── dto/
    │       └── UploadResultDTO.java       # 返回 uuid/mime/size/width/height
    ├── config/
    │   └── StorageProperties.java        # @ConfigurationProperties("app.storage.local")
    ├── domain/
    │   ├── NoteAttachment.java           # MyBatis-Plus 实体，映射 note_attachments
    │   ├── NoteAttachmentMapper.java     # BaseMapper<NoteAttachment>
    │   └── NoteAttachmentRepository.java # 仓储接口（业务逻辑解耦）
    ├── infra/
    │   └── NoteAttachmentDBRepository.java # MyBatis-Plus 实现
    └── spi/
        ├── AssetStore.java               # 存储 SPI 接口（4 个方法）
        └── LocalFileAssetStore.java      # 本地磁盘实现
```

---

## Step 1：SPI 存储抽象

### AssetStore 接口（4 个方法）

```java
public interface AssetStore {
    // 落盘保存（从临时文件复制到存储目录）
    void saveFromFile(String userDir, String storageKey, File tempFile, String contentType);

    // 全量资源（HTTP 200 用）
    Resource getResource(String userDir, String storageKey);

    // ★ 核心：解析 HttpHeaders.Range，返回 Spring 原生 ResourceRegion（HTTP 206 用）
    ResourceRegion createResourceRegion(String userDir, String storageKey, HttpHeaders headers);

    // 删除物理文件（软删除 + 废弃清理）
    void delete(String userDir, String storageKey);
}
```

### 路径规则（重要！必须一致）

```
物理路径 = {rootDir} / {userDir} / {storageKey}
           │              │              │
           配置项          userId字符串    YYYY/MM/DD/{uuid}.{ext}
```

示例：`/app/data/assets/2/2026/02/22/abc123.jpg`

application.yml 配置：
```yaml
app:
  storage:
    local:
      root-dir: ${ASSET_STORAGE_ROOT:/app/data/assets}
```

Docker compose 示例：
```yaml
volumes:
  - ./data/assets:/app/data/assets
```

### LocalFileAssetStore.createResourceRegion 实现要点

```java
// 关键：用 HttpRange.getRangeStart/End(contentLength) 精确计算区段
HttpRange range = ranges.get(0);
long start = range.getRangeStart(contentLength);
long end   = range.getRangeEnd(contentLength);
long rangeLength = Math.min(end - start + 1, contentLength - start); // 防超界
return new ResourceRegion(resource, start, rangeLength);
```

---

## Step 2：防 OOM 上传管线

### 三大铁律（违反任何一条都会在生产环境出问题）

#### 铁律 1：临时文件缓冲（防大图内存堆积）

```java
// ✅ 正确：先落盘，流操作全在磁盘
File tempFile = Files.createTempFile("pocketmind-upload-", "." + ext).toFile();
Files.copy(inputStream, tempFile.toPath(), REPLACE_EXISTING);

// ❌ 禁止：ByteArrayOutputStream 或任何内存缓冲
byte[] bytes = file.getBytes(); // 20MB 图片 = 20MB 堆内存
```

#### 铁律 2：ImageReader 仅读文件头（防宽高解析 OOM）

```java
// ✅ 正确：只读元数据，不加载像素
ImageInputStream iis = ImageIO.createImageInputStream(tempFile);
Iterator<ImageReader> readers = ImageIO.getImageReaders(iis);
ImageReader reader = readers.next();
reader.setInput(iis, true, false);       // seekForwardOnly=true, ignoreMetadata=false
int width  = reader.getWidth(0);         // 只读 EXIF/文件头中的尺寸
int height = reader.getHeight(0);
reader.dispose();                        // ★ 必须 dispose，否则持有文件句柄

// ❌ 禁止：将整张图加载为 BufferedImage
BufferedImage img = ImageIO.read(tempFile); // 4K 图 = 数百 MB 堆内存
int width = img.getWidth();
```

#### 铁律 3：try-finally 清理临时文件（防磁盘泄漏）

```java
File tempFile = null;
try {
    tempFile = writeToTempFile(...);
    // ... 业务逻辑 ...
} finally {
    // 无论成功或任何异常，都强制删除
    if (tempFile != null && tempFile.exists()) {
        tempFile.delete();
    }
}
```

### StorageKey 生成规则

```java
String storageKey = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
                  + "/" + uuid + "." + normalizedExt;
// 示例：2026/02/22/abc123-def456.jpg
```
按日期分散子目录，避免单目录文件过多影响文件系统性能。

### 上传响应 DTO

```java
// 返回宽高是关键！客户端可在图片未加载前就渲染正确尺寸的骨架屏
public record UploadResultDTO(UUID uuid, String mime, long size, int width, int height) {}
```

---

## Step 3：HTTP 206 分发（Range 支持）

### 为什么图片也需要 Range？

| 场景 | 说明 |
|------|------|
| 超大图断点续传 | 20MB+ 的原图下载中断后，只下载剩余部分 |
| 前端骨架屏优化 | 先 `Range: bytes=0-1023` 取文件头解析尺寸，再异步全量加载 |
| 移动端弱网 | 分片加载减少单次请求超时风险 |
| CDN/S3 架构预备 | S3 的 `GetObject with Range` 使用完全相同的 HTTP 语义 |

### Controller 层 Range 决策（职责分离）

```java
@GetMapping("/{uuid}")
public ResponseEntity<?> getImage(@PathVariable UUID uuid,
                                   @RequestHeader HttpHeaders requestHeaders) {
    long userId = parseUserId();

    // Range 决策在 Controller，保持 Service 职责单一
    if (!requestHeaders.getRange().isEmpty()) {
        return serveService.servePartialImage(uuid, userId, requestHeaders); // 206
    }
    return serveService.serveFullImage(uuid, userId); // 200
}
```

### 206 响应构建

```java
public ResponseEntity<ResourceRegion> servePartialImage(...) {
    NoteAttachment attachment = requireOwnedAttachment(attachmentUuid, userId); // 越权防御
    ResourceRegion region = assetStore.createResourceRegion(
            String.valueOf(userId), attachment.getStorageKey(), requestHeaders);

    return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
            .contentType(resolveMediaType(attachment.getMime())) // 设置正确 Content-Type
            .cacheControl(CacheControl.maxAge(365, TimeUnit.DAYS).cachePrivate())
            .body(region);
}
```

---

## ⚠️ Spring Boot 4.x 关键陷阱（必读）

### 陷阱：ResourceRegionHttpMessageConverter 未自动注册

**现象**：Range 请求返回 500，日志显示：
```
HttpMessageNotWritableException: No converter for [class org.springframework.core.io.support.ResourceRegion] 
with preset Content-Type 'image/jpeg'
```

**根因**：Spring Boot 4.x（Spring Framework 7.x）不再自动注册 `ResourceRegionHttpMessageConverter`。

**修复**（在 `WebMvcSecurityConfig` 或任意 `WebMvcConfigurer` 中）：

```java
@Override
public void extendMessageConverters(List<HttpMessageConverter<?>> converters) {
    // ★ 必须手动注册，Spring Boot 4.x 不再自动注册这个 Converter
    converters.add(new ResourceRegionHttpMessageConverter());
}
```

文件位置：[shared/security/WebMvcSecurityConfig.java](../../backend/src/main/java/com/doublez/pocketmindserver/shared/security/WebMvcSecurityConfig.java)

### 陷阱：ApiResponseAdvice 干扰二进制响应

`ResponseBodyAdvice` 会拦截所有响应体，必须排除 `Resource` 和 `ResourceRegion`：

```java
@Override
public Object beforeBodyWrite(Object body, ...) {
    if (body instanceof ApiResponse<?>) return body;
    // ★ 二进制资源直接透传，不做 JSON 包装
    if (body instanceof Resource || body instanceof ResourceRegion) return body;
    // ... 正常 JSON 包装逻辑
}
```

---

## 数据库设计

### note_attachments 表（关键字段）

```sql
-- 新增字段（幂等 ALTER，可反复执行）
ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS size             BIGINT NOT NULL DEFAULT 0;
ALTER TABLE note_attachments ADD COLUMN IF NOT EXISTS original_file_name  TEXT;
ALTER TABLE note_attachments ALTER COLUMN note_uuid DROP NOT NULL;  -- 允许独立上传
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `uuid` | UUID | 业务主键（IdType.INPUT，Java侧生成） |
| `user_id` | BIGINT | 租户隔离（注意：现有系统用数值ID，非 UUID） |
| `note_uuid` | UUID | 可为 NULL（独立上传先不绑定笔记） |
| `size` | BIGINT | 文件字节数（前端展示 + 磁盘统计） |
| `original_file_name` | TEXT | 上传时的原始文件名 |
| `storage_key` | TEXT | 相对路径键：`YYYY/MM/DD/{uuid}.{ext}` |
| `storage_type` | VARCHAR | 当前固定 `"local"`，扩展时改为 `"s3"` |
| `width` / `height` | INT | 图片尺寸（上传时仅读文件头提取，无 OOM 风险） |

### NoteAttachment 实体注意事项

```java
// ★ 必须用 IdType.INPUT，否则 MyBatis-Plus 会误用自增策略
@TableId(value = "uuid", type = IdType.INPUT)
private UUID uuid;

// storageType 在此模型中是 String 而非 enum，
// 旧的 AttachmentModel 用 enum StorageType，新模型直接用字符串避免依赖旧包
private String storageType;
```

---

## API 合约

### POST /api/assets/images

```
Request:  multipart/form-data, field=file
Response: { uuid, mime, size, width, height }
```

允许的格式：`jpg/jpeg/png/webp/gif`（扩展名 + MIME 双重校验）

### GET /api/assets/images/{uuid}

```
无 Range 头 → 200 OK     + Content-Type: image/{type} + Cache-Control: private, max-age=31536000
有 Range 头 → 206 Partial + Content-Range: bytes {start}-{end}/{total}
```

---

## 安全约束

1. **越权防御**：每次分发都通过 `findByUuidAndUserId(uuid, userId)` 校验，确保用户只能访问自己的图片
2. **格式白名单**：仅允许 `image/jpeg` / `image/png` / `image/webp` / `image/gif`
3. **路径隔离**：物理存储按 `{userId}/` 前缀隔离，防止目录穿越
4. **Broken Pipe 容忍**：`ClientAbortException` 只打 WARN，不打堆栈（防日志雪崩）

---

## 扩展指南

### 接入 S3

1. 新建 `S3AssetStore implements AssetStore`
2. 在 `saveFromFile` 中调用 `S3Client.putObject`
3. 在 `getResource` 中返回 `UrlResource`（预签名 URL）或代理流
4. 在 `createResourceRegion` 中使用 `GetObjectRequest.builder().range(...)` 精确拉取字节段
5. 修改 `@Primary` 注解切换实现，或通过 `@ConditionalOnProperty` 按配置选择
6. `storageType` 字段改写为 `"s3"`，历史数据继续用本地实现处理

### 接入视频流

视频与图片同架构，区别：
- Controller 须始终检测 Range（视频播放器必需）
- `type` 字段改为 `"video"`
- `width`/`height` 用于视频分辨率
- `createResourceRegion` 逻辑完全复用，无需任何改动
