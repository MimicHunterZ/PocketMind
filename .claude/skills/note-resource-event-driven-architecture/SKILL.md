---
name: note-resource-event-driven-architecture
description: Use when you need to understand or modify PocketMind note save to resource indexing flow, including outbox, MQ hint/DLQ compensation, projector consumption, and consistency boundaries.
---

# Note Resource Event-Driven Architecture

## Overview

本 Skill 用于说明 PocketMind 中「笔记保存 -> 资源投影 -> 索引消费」的完整链路。
核心原则：`resource_records` 是资源事实层，`resource_index_outbox` 是索引变更事实层，MQ 只做触发与补偿，不作为真相源。

## When to Use

- 你需要排查“笔记保存后 AI 检索不到内容”
- 你在改动 `NoteResourceSyncServiceImpl`、`ResourceCatalogProjector`、`ResourceOutbox*` 相关代码
- 你要处理 outbox 堆积、DLQ 重放、幂等与一致性问题
- 你要解释为什么不再使用 DB 定时轮询作为主路径

## Core Architecture

### 1) 资源事实层（Resource Records）

- 入口服务：`NoteResourceSyncServiceImpl`
- 作用：将 `NoteEntity` 投影为 `ResourceRecordEntity`
- 当前策略：
  - 无 `sourceUrl`：走 `NOTE_TEXT`
  - 有 `sourceUrl`：走 `WEB_CLIP`（避免同一笔记重复资源）
- 关键类：
  - `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/NoteResourceSyncServiceImpl.java`
  - `backend/pocketmind-server/src/main/java/com/doublez/pocketmindserver/resource/application/NoteResourceProjectionServiceImpl.java`

### 2) 变更事实层（Outbox）

- 每次资源增删改都会写 `resource_index_outbox`
- outbox 事件状态：`PENDING / PROCESSING / COMPLETED`
- 关键仓储：
  - `ResourceIndexOutboxRepository`
  - `ResourceIndexOutboxRepositoryImpl`
  - `ResourceIndexOutboxMapper`

### 3) 事件触发层（MQ Hint + DLQ）

- 事务提交后发布 hint 事件：`ResourceOutboxHintAfterCommitListener`
- 主消费：`ResourceOutboxHintListener` -> 触发 projector
- 失败补偿：`ResourceOutboxDlqListener`
- 发布失败兜底：`ResourceOutboxHintCompensationPublisherImpl`
- MQ 常量与配置：
  - `ResourceOutboxMqConstants`
  - `mq/config/RabbitMQConfig.java`

### 4) 索引消费层（Projector）

- `ResourceCatalogProjector` 负责 claim outbox -> 同步 `context_catalog` -> 回写 outbox 状态
- 关键增强：消费前执行 stale `PROCESSING` 回收，防止进程异常导致事件永久卡死
- 关键配置：`outbox-processing-lease-millis`

## Data Flow

1. Note 保存/更新 -> `NoteResourceSyncServiceImpl`
2. 写/更新 `resource_records`
3. append `resource_index_outbox`（`PENDING`）
4. after-commit 发布 MQ hint
5. hint listener 触发 `ResourceCatalogProjector.projectOnce(...)`
6. projector claim runnable outbox，读取资源，写 `context_catalog`
7. 成功 `markCompleted`；失败 `markFailed(retry_after, last_error)`，超阈值进入 DLQ 补偿

## Consistency Rules

- **Rule 1:** outbox 是索引消费的唯一事实来源，MQ 只触发
- **Rule 2:** Projector 只能消费 outbox，不直接扫描业务表做推导
- **Rule 3:** 任何“补偿任务”都应基于明确事件集，不恢复为全表轮询主路径
- **Rule 4:** 有 URL 的 note 只保留一条 `WEB_CLIP` 资源，避免重复语义资源

## Known Limits

- DLQ replay 次数目前仍是内存计数（重启后丢失历史）
- `hint-debounce-millis` 仍是预留配置，尚未做真正去抖合并
- 补偿发布失败当前仅日志记录，尚未落库审计

## Debug Checklist

1. 看 `resource_records` 是否符合当前投影规则（尤其 URL note 是否单条 WEB_CLIP）
2. 看 `resource_index_outbox` 是否积压在 `PENDING/PROCESSING`
3. 看 hint 队列与 DLQ 是否有异常堆积
4. 看 `ResourceCatalogProjector` 日志是否出现大量 `markFailed`
5. 看 `context_catalog` 是否与目标资源 root_uri 对齐
