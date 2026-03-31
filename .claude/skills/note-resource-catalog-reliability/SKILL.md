---
name: "note-resource-catalog-reliability"
description: "PocketMind 后端 notes->resource_records->context_catalog 一致性改造专项 Skill。当用户讨论 resource_records 真相层、context_catalog 索引层、Outbox/Projector、检索 fallback、SessionCommit 长事务、transcript 重复同步或相关回归测试时必须触发。"
metadata:
  version: "1.0.0"
  updated: "2026-03-28"
  tags: ["spring-boot", "mybatis-plus", "postgresql", "outbox", "projector", "retrieval", "consistency"]
---

# Note-Resource-Catalog 可靠性改造 Skill

## 1. 目标与边界

本技能用于指导 PocketMind 后端上下文链路的一致性实现，核心目标：

1. `resource_records` 是唯一真相层（Source of Truth）。
2. `context_catalog` 是可重建索引层（Rebuildable Index）。
3. 主写链路不被 catalog 写失败阻塞。
4. 异步投影可重试、可观测、可回放。

---

## 2. 触发条件

出现以下任一关键词或问题时必须触发本 Skill：

1. `resource_records` / `context_catalog` 一致性。
2. Outbox + Projector 方案、重试机制、幂等。
3. “数据在库但 AI 检索不到” 的延迟收敛问题。
4. SessionCommit 长事务、事务内调用 LLM。
5. SSE done 与 commit 双触发导致 transcript 重复同步。
6. 相关测试：`ResourceCatalogProjectorTest`、`NoteResourceCatalogPipelineIT`、`RetrievalOrchestratorTest`。

---

## 3. 当前实现基线（必须遵守）

### 3.1 分层职责

1. `resource_records`：业务真相层，承载可检索材料。
2. `resource_index_outbox`：事件缓冲层，承接主写与索引投影。
3. `context_catalog`：检索索引层，通过 projector 异步收敛。

### 3.2 主写链路约束

1. 写资源时同时追加 outbox 事件（同事务）。
2. 不允许在主写服务里直接强耦合 catalog 同步成功。
3. 删除/更新操作码必须使用常量，不允许硬编码字符串。

### 3.3 检索链路约束

1. 优先走 catalog 检索。
2. catalog miss 时可降级到 `resource_records` 关键字检索。
3. fallback 必须可配置开关控制。

---

## 4. 关键代码锚点

### 4.1 一致性策略与配置

1. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/ResourceSyncConsistencyPolicy.java`
2. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/ResourceCatalogRuntimeProperties.java`

### 4.2 Outbox 与投影

1. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/domain/ResourceIndexOutboxConstants.java`
2. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/domain/ResourceIndexOutboxRepository.java`
3. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/ResourceCatalogProjector.java`
4. `backend/pocketmind-server/src/main/resources/schema-pg.sql`

### 4.3 检索降级

1. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/ai/application/retrieval/RetrievalOrchestrator.java`
2. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/ai/application/retrieval/ResourceRetrievalFallbackService.java`

### 4.4 事务边界与去重触发

1. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/context/application/SessionCommitServiceImpl.java`
2. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/context/application/SessionSummaryGenerator.java`
3. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/ai/application/stream/SseReplyService.java`

### 4.5 可观测性与文档

1. `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/ResourceCatalogMetrics.java`
2. `backend/pocketmind-server/src/main/resources/application-template.yml`
3. `docs/architecture/note-resource-catalog-consistency.md`

---

## 5. 变更执行清单

涉及本链路改造时，按如下顺序执行：

1. 先补测试，再改实现（TDD）。
2. 验证主写路径是否仍依赖 catalog 同步成功。
3. 验证 outbox 事件是否正确落库（`UPSERT`/`DELETE`）。
4. 验证 projector 对失败是否写回重试信息。
5. 验证 retrieval fallback 是否受配置开关控制。
6. 验证事务边界中无 LLM 调用。
7. 跑回归测试集并记录结果。

---

## 6. 必跑测试

最小回归集：

```bash
cd backend
./mvnw -pl pocketmind-server -Dtest=ResourceSyncConsistencyPolicyTest,ResourceIndexOutboxRepositoryTest,ResourceCatalogProjectorTest,ResourceCatalogOutboxRetryTest,RetrievalOrchestratorTest,SessionCommitServiceTest,SseReplyServiceTest,NoteResourceCatalogPipelineIT test
```

可观测性新增后建议补跑：

```bash
cd backend
./mvnw -pl pocketmind-server -Dtest=ResourceCatalogRuntimePropertiesTest,ResourceCatalogMetricsTest test
```

---

## 7. 禁令

1. 禁止把 `context_catalog` 当真相层。
2. 禁止在 Service 里硬编码 outbox 操作码（如 `"UPSERT"`、`"DELETE"`）。
3. 禁止恢复 transcript 双入口同步（SSE done + commit 同时触发）。
4. 禁止在长事务内调用 LLM。
5. 禁止跳过失败恢复与并发幂等测试。

---

## 8. 运维排障速查

1. 检索 miss 但资源存在：先查 fallback 开关，再查 outbox backlog。
2. 投影延迟高：看 `pocketmind.resource.catalog.outbox.backlog` 与 `projector.latency`。
3. 重试堆积：看 `projector.failed` 与 outbox `last_error`。
4. 会话摘要异常：确认 `SessionSummaryGenerator` 是否事务外执行。
