---
name: "asset-image-subsystem"
description: "PocketMind 资产存储与分发子系统（图片/PDF/视频/音频/任意文件）。涵盖 SPI 存储抽象层、防 OOM 上传管线、HTTP 206 断点续传分发、MyBatis-Plus + PostgreSQL JSONB 持久化以及 Spring Boot 4.x 关键陷阱。当用户讨论图片上传、图片下载、Range 请求、AssetStore、Asset、ImageUploadService、ImageServeService、AssetController、JsonbTypeHandler 时触发。"
version: 2.0.0
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

**Auto-Triggers**：提到 AssetStore / Asset / ImageUploadService / ImageServeService / AssetController / HTTP Range 图片 / ResourceRegion / 图片上传 OOM / JsonbTypeHandler / asset_extractions

**核心能力**：

- 防 OOM 上传：临时文件 + ImageReader 仅读文件头
- HTTP 206 断点续传：Spring `ResourceRegion` + `ResourceRegionHttpMessageConverter`
- 存储 SPI 抽象：本地磁盘实现，接口预留 S3 扩展
- 越权防御：所有分发路径经 DB 归属校验
- 异步图片识别：RabbitMQ 投递 + 虚拟线程 Worker + DLQ（高吞吐 + 绝不无限重试）
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
    │   ├── Asset.java                    # MyBatis-Plus 实体，映射 assets 表
    │   ├── AssetMapper.java              # BaseMapper<Asset>
    │   └── AssetRepository.java          # 仓储接口（业务逻辑解耦）
    ├── infra/
    │   └── AssetDBRepository.java        # MyBatis-Plus 实现
    └── spi/
        ├── AssetStore.java               # 存储 SPI 接口（4 个方法）
        └── LocalFileAssetStore.java      # 本地磁盘实现

backend/src/main/java/com/doublez/pocketmindserver/
└── shared/
    └── mybatis/
        └── JsonbTypeHandler.java         # PostgreSQL JSONB 专用 TypeHandler（Map↔jsonb）

backend/src/main/java/com/doublez/pocketmindserver/
└── mq/
    ├── config/
    │   └── RabbitMQConfig.java           # MQ 基建 + Listener 虚拟线程配置（含重试 + DLQ）
    ├── event/
    │   └── VisionJobMessage.java         # 图片识别任务消息（assetUuid + userId）
    ├── VisionMqConstants.java            # vision_queue / exchange / routingKey / dlq 常量
    ├── VisionMessagePublisher.java       # 上传成功后投递识别任务
    └── VisionWorker.java                 # 异步识别消费者（幂等 + 落库 + 重试 + DLQ）

backend/src/main/java/com/doublez/pocketmindserver/
└── attachment/
    └── infra/persistence/vision/
        ├── AttachmentVisionModel.java    # MyBatis-Plus 模型：asset_extractions
        └── MybatisAttachmentVisionRepository.java
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
    Asset asset = requireOwnedAsset(assetUuid, userId); // 越权防御
    ResourceRegion region = assetStore.createResourceRegion(
            String.valueOf(userId), asset.getStorageKey(), requestHeaders);

    return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
            .contentType(resolveMediaType(asset.getMime())) // 设置正确 Content-Type
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

## Step 4：异步图片识别（MQ + Vision Worker）

> 目标：上传链路只负责「落盘 + assets 落库 + 投递 MQ」，
> 识别链路交给异步 Worker 在虚拟线程里跑，失败可重试，最终进入 DLQ，绝不阻塞主队列。

### 两张表的职责（非常重要）

- `assets`：任意格式资产事实表（上传成功即写入），字段包含 `uuid/user_id/type/mime/storage_key/metadata/...`
- `asset_extractions`：内容提取结果表（异步 Worker 写入），通过 `asset_uuid` 关联 `assets.uuid`；`content_type` 区分提取方式（`vision`/`ocr`/`pdf_text`/`transcript`）

识别幂等检查必须查 `asset_extractions`，这是"提取是否完成"的唯一可信来源。

### 消息契约（当前实现）

文件：[backend/src/main/java/com/doublez/pocketmindserver/mq/event/VisionJobMessage.java](../../backend/src/main/java/com/doublez/pocketmindserver/mq/event/VisionJobMessage.java)

```java
public record VisionJobMessage(UUID assetUuid, long userId) {}
```

- `assetUuid`：幂等键（同一资产提取完成后，后续重复投递会被直接 Ack 丢弃）
- `userId`：租户隔离（AssetStore 物理路径 = `{rootDir}/{userId}/{storageKey}`）

### MQ 拓扑 + 重试 + DLQ

常量定义：[backend/src/main/java/com/doublez/pocketmindserver/mq/VisionMqConstants.java](../../backend/src/main/java/com/doublez/pocketmindserver/mq/VisionMqConstants.java)

- 主队列：`vision_queue`
- 主交换机：`vision_exchange`
- 路由键：`vision.key`
- 死信队列：`vision_queue.dlq`
- 死信交换机：`vision_dlq_exchange`
- 死信路由键：`vision.dlq`

重试策略：`RetryInterceptorBuilder.stateless().maxRetries(3)`；重试耗尽后由 `RepublishMessageRecoverer`
将消息重新发布到 `vision_dlq_exchange`，避免无限重试卡死主队列。

### Spring Boot 4.x：@RabbitListener 虚拟线程提速

文件：[backend/src/main/java/com/doublez/pocketmindserver/mq/config/RabbitMQConfig.java](../../backend/src/main/java/com/doublez/pocketmindserver/mq/config/RabbitMQConfig.java)

Vision 专用 `SimpleRabbitListenerContainerFactory`：

```java
SimpleAsyncTaskExecutor virtualExecutor = new SimpleAsyncTaskExecutor("vision-worker-");
virtualExecutor.setVirtualThreads(true);
factory.setTaskExecutor(virtualExecutor);
```

每条消息在独立虚拟线程中执行，AI 网络 IO 阻塞不占用平台线程，吞吐稳定。

### 上游触发：上传成功后投递任务

投递器：[backend/src/main/java/com/doublez/pocketmindserver/mq/VisionMessagePublisher.java](../../backend/src/main/java/com/doublez/pocketmindserver/mq/VisionMessagePublisher.java)

上传链路在 `ImageUploadService.upload()` 中完成落盘与 `assets` 落库后投递：

```java
assetRepository.save(entity);
visionMessagePublisher.publishVisionTask(assetUuid, userId);
```

### Worker 管线（幂等 + DB 状态机）

消费者：[backend/src/main/java/com/doublez/pocketmindserver/mq/VisionWorker.java](../../backend/src/main/java/com/doublez/pocketmindserver/mq/VisionWorker.java)

处理顺序：

1. 查 `asset_extractions`（`userId + assetUuid`）：若存在 `DONE` 直接 Ack
2. 创建/复用提取实体：无记录则插入 `PENDING`；有 `PENDING/FAILED` 则复用
3. 查 `assets` 拿到 `mime + storageKey`
4. `assetStore.getResource(userId, storageKey)` 得到 `Resource`
5. 调用 `visionService.analyzeImage(Resource, MimeType)`
6. 成功：写入 `content` 并标记 `DONE`（调用 `visionEntity.markDone(content)`）
7. 失败：标记 `FAILED` 并更新，然后 re-throw 触发重试；重试耗尽进入 DLQ

### 生产级关键坑：`asset_extractions.content` 必须允许为 NULL

Worker 会先插入 `PENDING` 再调用 AI，成功后才回填 `content`。
因此 `content` 必须允许 NULL，否则会出现"INSERT PENDING 失败 → 重试 → DLQ"的死循环。
`schema-pg.sql` 中 `content TEXT` 无 NOT NULL 约束，已正确设计。

---

## 数据库设计

### assets 表（关键字段）

统一存储任意格式（图片/PDF/视频/音频/文件）的物理文件元数据，替代旧的 `note_attachments`。

| 字段 | 类型 | 说明 |
|------|------|------|
| `uuid` | UUID | 业务主键（IdType.INPUT，Java侧生成） |
| `user_id` | BIGINT | 租户隔离 |
| `note_uuid` | UUID | 可为 NULL（上传中尚未绑定笔记） |
| `type` | VARCHAR | 格式分类：`image`/`pdf`/`video`/`audio`/`file` |
| `source` | VARCHAR | 来源：`user`/`scrape`/`system_gen` |
| `mime` | VARCHAR | MIME 类型（如 `image/png`） |
| `size` | BIGINT | 文件字节数 |
| `file_name` | TEXT | 上传时的原始文件名 |
| `sha256` | CHAR(64) | 内容指纹，存储层去重 |
| `storage_key` | TEXT | 相对路径键：`YYYY/MM/DD/{uuid}.{ext}` |
| `storage_type` | VARCHAR | `local`/`server`/`oss` |
| `metadata` | JSONB | 物理元数据：`{"width":1920,"height":1080,"duration_seconds":120,"page_count":50}` |
| `business_metadata` | JSONB | 业务/排版元数据预留：`{"caption":"...","layout":"full-width"}` |

### Asset 实体注意事项

```java
// ★ 必须用 IdType.INPUT，否则 MyBatis-Plus 会误用自增策略
@TableId(value = "uuid", type = IdType.INPUT)
private UUID uuid;

// ★ JSONB 字段必须使用 JsonbTypeHandler，不能用默认的 JacksonTypeHandler！
// JacksonTypeHandler 输出 VARCHAR，PostgreSQL 拒绝隐式转换（BadSqlGrammarException）
@TableField(value = "metadata", typeHandler = JsonbTypeHandler.class)
private Map<String, Object> metadata;

@TableField(value = "business_metadata", typeHandler = JsonbTypeHandler.class)
private Map<String, Object> businessMetadata;
```

图片上传时 `metadata` 存放宽高：
```java
Map<String, Object> meta = new HashMap<>();
meta.put("width", width);
meta.put("height", height);
asset.setMetadata(meta);
```

### asset_extractions 表（关键字段）

> 由异步 Worker 写入，存储 AI 描述/PDF全文/视频转录等提取结果，替代旧的 `attachment_visions`。

| 字段 | 类型 | 说明 |
|------|------|------|
| `uuid` | UUID | 提取记录业务 UUID |
| `user_id` | BIGINT | 租户隔离 |
| `asset_uuid` | UUID | 关联 `assets.uuid` |
| `note_uuid` | UUID | 冗余，便于按笔记关联查询 |
| `content_type` | VARCHAR | 提取方式：`vision`/`ocr`/`pdf_text`/`transcript` |
| `content` | TEXT | 提取结果（PENDING/FAILED 允许 NULL） |
| `model` | VARCHAR | 识别所用模型名（溯源） |
| `status` | VARCHAR | `PENDING` / `DONE` / `FAILED` |

对应模型文件：
- [attachment/infra/persistence/vision/AttachmentVisionModel.java](../../backend/src/main/java/com/doublez/pocketmindserver/attachment/infra/persistence/vision/AttachmentVisionModel.java)

---

## ⚠️ Spring Boot 4.x 关键陷阱

### 陷阱：PostgreSQL JSONB 字段插入报 BadSqlGrammarException

**现象**：
```
org.postgresql.util.PSQLException: ERROR: column "metadata" is of type jsonb
but expression is of type character varying
```

**根因**：MyBatis-Plus 内置 `JacksonTypeHandler` 调用 `ps.setString()`，JDBC 层类型为 VARCHAR，
PostgreSQL 不允许隐式 VARCHAR→JSONB 转换。

**修复**：使用自定义 `JsonbTypeHandler`，核心在于 `ps.setObject(i, jsonString, Types.OTHER)`，
`Types.OTHER` 让 PostgreSQL JDBC 驱动将字符串识别为 jsonb：

```java
// shared/mybatis/JsonbTypeHandler.java
@Override
public void setNonNullParameter(PreparedStatement ps, int i,
                                Map<String, Object> parameter,
                                JdbcType jdbcType) throws SQLException {
    try {
        // Types.OTHER 告诉驱动「这是数据库原生类型」，PostgreSQL 将其识别为 jsonb
        ps.setObject(i, MAPPER.writeValueAsString(parameter), Types.OTHER);
    } catch (JsonProcessingException e) {
        throw new SQLException("无法将 Map 序列化为 JSON: " + e.getMessage(), e);
    }
}
```

注意：无需引入 `org.postgresql:postgresql` compile 依赖，runtime scope 即可。

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

### 接入 S3（模式一：服务端代理，当前 SPI 可直接支持）

1. 新建 `S3AssetStore implements AssetStore`
2. 在 `saveFromFile` 中调用 `S3Client.putObject`
3. 在 `getResource` 中用 `S3Client.getObject` 下载到 `InputStreamResource` 再透传
4. 在 `createResourceRegion` 中使用 `GetObjectRequest.builder().range("bytes=start-end")` 精确拉取
5. 通过 `@ConditionalOnProperty("app.storage.type", havingValue="s3")` 按配置选择
6. `storage_type` 字段改写为 `"s3"`，历史数据继续用本地实现处理

> **⚠️ 代理模式的局限**：图片数据仍经过服务器（Client→Server→S3→Server→Client），
> 上行耗带宽 CPU，下行翻倍延迟，不适合高并发生产环境。

### 接入 S3（模式二：企业级直传，Pre-signed URL）

这是真正的企业级方案，图片数据**完全不经过服务器**：

**上传流程**：
```
前端 → POST /api/assets/presign  (告诉后端：我要传 images/pdf)
后端 → 生成 N 个带时效 + 大小限制的 Pre-signed PUT URL，返回给前端
前端 → 直接并发 PUT 到 OSS/S3（不经过服务器，零服务器带宽消耗）
前端 → POST /api/assets/commit  (提交已上传成功的 storageKey 列表)
后端 → 校验文件存在 + 写 assets 表 + 投 MQ
```

**下载流程**：
```
前端 → GET /api/assets/{uuid}/url  (需要访问图片)
后端 → 校验归属，生成 Pre-signed GET URL（时效 15min）
前端 → 直接用该 URL 访问 CDN/S3（零服务器带宽）
```

**Pre-signed URL 的安全参数**：
- `ContentLengthRange`：限制最大文件大小（防恶意超大文件）
- `ContentType`：锁定 MIME 类型（防上传可执行文件）
- `Expires`：15 分钟时效（防盗链）
- Key 前缀必须包含 `userId/`（租户隔离，防越权写入）

**SPI 变化**：模式二需要 `AssetStore` 增加两个方法：
```java
// 生成上传用 Pre-signed PUT URL
String generatePresignedPutUrl(String storageKey, String contentType, long maxSizeBytes, int expirySeconds);

// 生成下载用 Pre-signed GET URL（或 CDN 签名 URL）
String generatePresignedGetUrl(String storageKey, int expirySeconds);
```

此时 `saveFromFile` 和 `getResource`/`createResourceRegion` 对 S3 实现变为空操作，
服务器端 HTTP 206 Range 功能移交给 CDN（性能更好）。

**何时用哪种模式**：

| | 代理模式 | Pre-signed 直传 |
|---|---|---|
| 实现复杂度 | 低，当前 SPI 直接支持 | 中，需新增 presign/commit 接口 |
| 服务器带宽 | 全量消耗 | 零消耗 |
| 适合场景 | 开发/小规模自建 | 生产/高并发/云厂商 OSS |
| HTTP Range | 服务器实现 | CDN/S3 原生支持 |

### 接入视频流

视频与图片同架构，区别：
- Controller 须始终检测 Range（视频播放器必需）
- `type` 字段为 `"video"`
- `metadata` JSONB 存 `{"width":1920,"height":1080,"duration_seconds":120}`
- `createResourceRegion` 逻辑完全复用，无需任何改动
- 视频建议优先使用 Pre-signed 直传 + CDN 分发（视频文件体积通常 > 100MB）
