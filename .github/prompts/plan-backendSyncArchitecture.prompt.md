# Spring Boot 同步端工程方案

研究结论：后端 `sync/` 模块目前**仅存在测试骨架**（`SyncServiceTest`、`SyncChangeLogMapper` mock），无任何 `src/main` 实现。`NoteModel`/`CategoryModel` 已有 `Long updatedAt`，但缺 `server_version`。测试中的字段命名（如 `op`、`SyncChangeItem`）与 Flutter 端 DTO（`operation`、`SyncMutationDto`）存在出入，需对齐，再修改过程重不需要管之前的test代码是如何的，直接删了它，然后按照正确的流程进行构建代码。
注意，你不需要为了历史代码做任何兼容性处理。

---

## 问题一：`server_version` 生成策略与表结构改造

### 选型：Append-Only Change Log Table（PK as Version）

**放弃选项：** per-user 序列（DDL 爆炸，用户量大时不可维护）；HLC（实现复杂，客户端已用物理时钟 LWW，无需向量时钟）。

**选型理由：** 利用 `sync_change_log` 表的全局自增主键作为 `serverVersion`。每次写操作（Push入库 或 AI回调 或 逻辑删除）都向该表 INSERT 一行，返回的 `LAST_INSERT_ID()` 即为本次写操作的版本号。Pull 时查询 `WHERE user_id = ? AND id > sinceVersion ORDER BY id LIMIT ?`。

**优点：**
- `id` 由 `AUTO_INCREMENT` 保证严格单调递增，无并发冲突。
- Pull 查询直接命中 `(user_id, id)` 复合索引，无需额外版本表。
- 自然天然幂等日志（下文合并）。

### SQL：新建 `sync_change_log` 表

```sql
CREATE TABLE sync_change_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '服务端版本号，全局单调递增，即 serverVersion',
    user_id         BIGINT       NOT NULL,
    entity_type     VARCHAR(16)  NOT NULL COMMENT 'note | category',
    entity_uuid     UUID         NOT NULL,
    operation       VARCHAR(8)   NOT NULL COMMENT 'create | update | delete',
    updated_at      BIGINT       NOT NULL COMMENT '业务实体 updatedAt 毫秒时间戳（LWW 裁决用）',
    client_mutation_id VARCHAR(36) NULL UNIQUE COMMENT 'Push 幂等键；AI 触发写入时为 NULL',
    payload         JSONB        NULL COMMENT '实体完整快照（delete 时为空）',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    INDEX idx_user_since (user_id, id)
) COMMENT '增量同步变更日志，id 即 serverVersion 游标';
```

### 现有表字段新增

**`notes` 表新增字段：**
```sql
ALTER TABLE notes ADD COLUMN server_version BIGINT NULL COMMENT '最后同步的 sync_change_log.id';
```

**`categories` 表新增字段：**
```sql
ALTER TABLE categories ADD COLUMN server_version BIGINT NULL COMMENT '最后同步的 sync_change_log.id';
```

对应的 `NoteModel` 新增 `private Long serverVersion;`，`CategoryModel` 同理。

---

## 问题二：幂等性设计

### 核心：`client_mutation_id` 作为 `sync_change_log` 的唯一约束

`sync_change_log.client_mutation_id UNIQUE` 即是幂等锁。无需额外 `mutation_idempotency_log` 表。

### 事务内四步原子化（伪代码）

一个 `@Transactional(rollbackFor = Exception.class)` 方法中：

```
1. 【幂等校验】 SELECT 1 FROM sync_change_log WHERE client_mutation_id = #{mutationId}
   → 若存在：直接 SELECT id, server_version FROM sync_change_log WHERE client_mutation_id = ? 并返回缓存结果（幂等重放）
   → 若不存在：继续下面步骤

2. 【LWW 仲裁 + 业务写入】
   SELECT updatedAt FROM notes WHERE uuid = #{uuid} AND user_id = #{userId}
   IF 不存在 → INSERT INTO notes (...)
   ELSE IF clientUpdatedAt >= serverUpdatedAt → UPDATE notes SET ... WHERE uuid = ?
   ELSE → 跳过（服务端胜），仍需写 change_log 告知客户端以服务端为准
   
   特殊情况：delete 操作始终执行（UPDATE notes SET is_deleted = 1）

3. 【递增 server_version】
   INSERT INTO sync_change_log (user_id, entity_type, entity_uuid, operation, updated_at, client_mutation_id, payload)
   VALUES (...)
   → LAST_INSERT_ID() 即为此次写操作的 serverVersion

4. 【同步 server_version 到业务表】
   UPDATE notes SET server_version = #{lastInsertId} WHERE uuid = #{uuid} AND user_id = #{userId}
```

**防重放返回策略：** 若 `client_mutation_id` 已存在（重试风暴），直接返回 `accepted: true, serverVersion: <原始id>`，不重复写入，客户端幂等接收即可。

---

## 问题三：API 契约（与 Flutter 端字段严格对齐）

### `GET /api/sync/pull`

**Query Parameters：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `sinceVersion` | long | 是 | 客户端游标，首次传 0 触发全量 |
| `pageSize` | int | 否 | 默认 200，上限 500 |

**Response `data`（直接反序列化为 `SyncPullResponse`）：**

```json
{
  "serverVersion": 1024,
  "hasMore": false,
  "changes": [
    {
      "entityType": "note",
      "uuid": "550e8400-...",
      "operation": "update",
      "serverVersion": 1023,
      "updatedAt": 1709712345678,
      "payload": {
        "uuid": "550e8400-...",
        "title": "我的笔记",
        "content": "# 内容",
        "url": "https://example.com",
        "time": 1709712345678,
        "updatedAt": 1709712345678,
        "isDeleted": false,
        "categoryId": 3,
        "tags": ["AI", "技术"],
        "previewTitle": "标题",
        "previewDescription": "描述",
        "previewContent": "Markdown正文",
        "previewImageUrl": null,
        "resourceStatus": "CRAWLED",
        "aiSummary": "这是AI摘要",
        "serverVersion": 1023
      }
    },
    {
      "entityType": "note",
      "uuid": "660e8400-...",
      "operation": "delete",
      "serverVersion": 1024,
      "updatedAt": 1709712399999,
      "payload": {}
    },
    {
      "entityType": "category",
      "uuid": "770e8400-...",
      "operation": "create",
      "serverVersion": 1020,
      "updatedAt": 1709712300000,
      "payload": {
        "uuid": "770e8400-...",
        "name": "技术",
        "updatedAt": 1709712300000,
        "isDeleted": false,
        "serverVersion": 1020
      }
    }
  ]
}
```

- `serverVersion`（顶层）= 本批次 `changes` 中最大的 `change_log.id`，作为客户端更新为新游标的值。若 `changes` 为空，返回请求传入的 `sinceVersion`，游标不推进。
- `delete` 操作的 `payload` 为空对象 `{}`。

### `POST /api/sync/push`

**Request Body：**

```json
{
  "mutations": [
    {
      "mutationId": "d290f1ee-6c54-4b01-...",
      "entityType": "note",
      "entityUuid": "550e8400-...",
      "operation": "update",
      "updatedAt": 1709712345678,
      "payload": {
        "title": "更新标题",
        "content": "# 新内容",
        "url": null,
        "time": 1709712345678,
        "categoryId": 3,
        "tags": ["flutter"],
        "isDeleted": false
      }
    },
    {
      "mutationId": "a1b2c3d4-...",
      "entityType": "note",
      "entityUuid": "660e8400-...",
      "operation": "delete",
      "updatedAt": 1709712399999,
      "payload": {}
    }
  ]
}
```

**Response `data`（`List<SyncPushResult>`，与 Flutter `SyncPushResult` 对齐）：**

```json
[
  {
    "mutationId": "d290f1ee-6c54-4b01-...",
    "accepted": true,
    "serverVersion": 1025,
    "conflictPayload": null,
    "rejectReason": null
  },
  {
    "mutationId": "a1b2c3d4-...",
    "accepted": false,
    "serverVersion": null,
    "conflictPayload": {
      "title": "服务端权威标题",
      "updatedAt": 1709712500000,
      "serverVersion": 990
    },
    "rejectReason": "CONFLICT_SERVER_WINS"
  }
]
```

- `accepted: true`：LWW 客户端胜出或新建，已写入，返回 `serverVersion`。
- `accepted: false + conflictPayload`：LWW 服务端胜出（409 语义），客户端用 `conflictPayload` 覆盖本地，删除该 MutationEntry。
- `accepted: false + rejectReason`（无 `conflictPayload`）：永久性拒绝（如权限不足、数据非法），客户端将 MutationEntry 置 `failed`。

---

## 问题四：异步 AI 管线的版本号推进机制

### 流程（文字说明 + 伪代码）

```
1. 【AI 任务触发】
   Push 接受 note 写入后，SyncService 发布领域事件：
   ApplicationEventPublisher.publishEvent(new NoteAiPipelineEvent(noteUuid, userId))

2. 【@EventListener / 虚拟线程异步执行】（不阻塞 Push 事务，不在大事务内）
   @Async / Thread.ofVirtual().start(() -> {
     // 调用 Spring AI 生成摘要（耗时 60s）
     String summary = aiFailoverRouter.call(prompt);

     // AI 完成后，开启独立小事务推进版本号
     aiCallbackService.persistAiResult(noteUuid, userId, summary, previewFields...)
   })

3. 【persistAiResult — 独立 @Transactional 小事务】
   @Transactional(rollbackFor = Exception.class)
   void persistAiResult(UUID uuid, long userId, String summary, ...) {
     // a. 更新业务字段
     noteRepository.updateAiFields(uuid, userId, summary, resourceStatus=EMBEDDED, ...)
     // 注意：此处 NOT 更新 note.updatedAt（AI 结果是服务端权威字段）
     //       Pull 的 LWW 以 updatedAt 判断，AI 字段走细粒度合并路径

     // b. 插入 change_log（client_mutation_id = NULL 标识 AI 触发）
     long newVersion = syncChangeLogMapper.insertAndGetId(SyncChangeLogModel {
       userId, entityType="note", entityUuid=uuid,
       operation="update", updatedAt=System.currentTimeMillis(),
       clientMutationId=null,
       payload=buildFullSnapshot(note)  // 包含 aiSummary、resourceStatus 等全量快照
     })

     // c. 同步 server_version 到 notes 表
     noteRepository.updateServerVersion(uuid, userId, newVersion)
   }

4. 【客户端下次 Pull 捞到此变更】
   客户端 Pull 携带 sinceVersion=1025（上次 Push 获得的游标）
   后端查询: SELECT * FROM sync_change_log WHERE user_id=? AND id > 1025 ORDER BY id LIMIT 201
   → 命中 AI 回写产生的 change_log 行（id=1050，假设）
   → 客户端收到 changes[0].serverVersion=1050，payload 含 aiSummary、resourceStatus 字段
   → PullCoordinator._applyNoteChange 走「本地无 pending → updatedAt LWW」路径
     （AI 写入不修改 updatedAt，所以 change.updatedAt ≈ serverUpdatedAt，服务端胜或平局）
     → 合并 aiSummary、resourceStatus 到本地 Note，更新 serverVersion=1050
   → 客户端游标推进为 1050
```

**关键设计决策：** AI 回调写入时 **不修改 `notes.updated_at`**，因为 `updatedAt` 是客户端写入时间，是 LWW 的仲裁锚。`aiSummary`、`resourceStatus`、`preview*` 属于 Pull 协调器中的"服务端权威字段"路径（`_mergeServerAuthorityFields`），在 `hasPending=true` 时也会被合并应用，彻底与客户端编辑字段解耦。

---

## 工程模块规划（后续实现步骤）

**Steps**

1. **数据库迁移脚本** — 在 `pocketmind-server/src/main/resources/db/migration/` 新建 `V3__add_sync_change_log.sql`，包含建表 SQL 及 `notes`/`categories` 的 `server_version` 列 ALTER

2. **持久化层** — 新建包 `com.doublez.pocketmindserver.sync`，创建 `SyncChangeLogModel`（@TableName）、`SyncChangeLogMapper`（BaseMapper）、`SyncChangeLogRepository`（屏蔽 QueryWrapper）

3. **DTO 层对齐** — `SyncMutationDto`（入参，字段与 Flutter `SyncMutationDto.toJson()` 100% 对齐）、`SyncChangeItem`（Pull 响应元素，与 Flutter `SyncChangeDto.fromJson()` 100% 对齐）、`SyncPullResponse`、`SyncPushResult`（含 `conflictPayload`、`rejectReason` 字段）

4. **SyncService** — 分离 `pushMutation()` 和 `pull()` 两个核心方法，实现问题二的四步原子事务

5. **SyncController** — 极薄路由层，GET /api/sync/pull + POST /api/sync/push，注入 `SyncService`，`@Validated` 参数校验

>! 不要跨层依赖，如 Controller 不要直接调用 Mapper等
6. **AI 异步回调** — `NoteAiPipelineEventListener`（@EventListener + 虚拟线程），完成后调用 `SyncService.persistAiResult()`

7. **测试对齐** — 现有的 `SyncServiceTest`我已经删除了，请不要参考目前的代码，不要被任何目前代码迷惑，注意你是在完成一个新的架构，你需要填充新架构下的相关测试用例（含幂等重放 case、AI 回调 case、pull hasMore case等），填充目前仅有 mock 的实现

**Verification**
- 单元测试：`SyncServiceTest` 所有 case 全绿（LWW、幂等、删除、pull 分页）
- 集成测试：H2 内存库，验证 `@Transactional` 四步原子性（模拟中间步骤异常后事务回滚）
- 手动 cURL：先 push 创建笔记，验证 pull sinceVersion=0 能返回该笔记；再 push 相同 mutationId，验证响应与第一次相同（幂等）

**Decisions**
- **Change Log PK = serverVersion**：选此方案而非 per-user 序列，因为 PostgreSQL 全局自增足够满足单调性，且存量测试已基于此模型验证
- **幂等字段内聚 change_log**：`client_mutation_id UNIQUE` 合并入 `sync_change_log`，不另建表，减少跨表事务
- **AI 不修改 `updatedAt`**：确保 AI 权威字段（aiSummary 等）永远走服务端合并路径，避免因 AI 延迟时间戳早于用户编辑时间戳而被 LWW 丢弃
