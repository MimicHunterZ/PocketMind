---
name: "mobile-note-sync-architecture"
description: "PocketMind 移动端笔记同步架构专项 Skill。当涉及以下问题时必须触发：预览字段（previewTitle等）被同步覆盖、多端一致性与离线冲突问题、同步链路改造（Pull/Push）、UI层违规调用底层Provider、抓取/轮询等写入未进入同步队列、或维护同步守卫测试。"
metadata:
  version: "1.0.1"
  updated: "2026-03-28"
  tags: ["flutter", "sync", "isar", "riverpod", "lww", "offline-first", "guard-test"]
---

# PocketMind 移动端同步架构 Skill（当前实现版）

## 1. 核心触发场景

本技能重点解决移动端数据的防空覆盖、Pull-first + Push 多端一致性、单一写入事务以及底层架构分层问题。凡涉及核心同步链路相关的修改，必须严格遵守以下规则。

---

## 2. 当前业务目标（必须遵守）

1. **本地优先 + 离线可写**：用户写操作先落本地，再异步同步。
2. **跨端最终一致**：通过 Pull-first + Push 逐步收敛。
3. **写路径单一**：所有写操作必须走统一入口，禁止旁路写。
4. **UI 单层交互**：UI 页面层只和 `NoteService` 交互，不直接碰同步底层。
5. **预览字段防空覆盖**：服务端空值或缺失字段不能抹掉端侧抓取结果。
6. **可回归验证**：改同步链路必须补/改守卫测试并运行 `test/sync`。

---

## 3. 架构总览（当前代码）

```
UI(Page/Widget)
  -> NoteService (统一业务入口)
    -> LocalWriteCoordinator (原子双写：业务表 + MutationEntry)
      -> Isar(Note/Category/MutationEntry)
    -> SyncEngine.kick()
      -> PullCoordinator (先拉增量)
      -> PushCoordinator (再推本地 pending)

后台衍生写入链路（抓取/轮询/回调）
  -> NoteService.persistDerivedNoteForSync()
  -> LocalWriteCoordinator.writeNote()
  -> MutationEntry 入队
  -> SyncEngine.kick()
```

关键点：

1. `SyncEngine` 是网络同步唯一入口，采用 single-flight（单飞 + 追尾）。
2. `PullCoordinator` 在本地有 pending 时走字段级合并；无 pending 时走粗粒度 LWW。
3. `PushCoordinator` 以 `mutationId` 做幂等，支持 accepted / conflict / retryable / failed 四类结果处理。

---

## 4. 关键文件与职责（修改同步时优先看）

1. `mobile/lib/service/note_service.dart`
   - 统一业务入口。
   - 含 `persistDerivedNoteForSync`、`triggerSyncNow`、URL 队列调度。

2. `mobile/lib/sync/local_write_coordinator.dart`
   - 唯一合法写入协调器。
   - 单事务完成业务表写入 + MutationEntry 追加。

3. `mobile/lib/sync/sync_engine.dart`
   - 同步调度中枢（Pull-first + Push）。

4. `mobile/lib/sync/pull_coordinator.dart`
   - 增量拉取、分页游标推进、字段级合并。

5. `mobile/lib/sync/push_coordinator.dart`
   - pending 批量推送、冲突回滚、重试与失败管理。

6. `mobile/lib/sync/note_sync_payload_mapper.dart`
   - 服务端快照映射。
   - 预览字段非空覆盖与 `previewImageUrl` 回退保护。

7. `mobile/lib/sync/resource_fetch_scheduler.dart`
   - PENDING 资源抓取调度。
   - 抓取成功后必须通过 `NoteService.persistDerivedNoteForSync`。

8. `mobile/lib/service/ai_polling_service.dart`
9. `mobile/lib/service/call_back_dispatcher.dart`
   - 两条后台链路都必须走统一衍生写入口。

10. `mobile/lib/page/home/sync_settings_page.dart`
   - UI 触发同步需调用 `NoteService.triggerSyncNow`。

11. `mobile/lib/providers/sync_providers.dart`
   - 同步与抓取调度器依赖注入。

---

## 5. 强约束与禁令（高优先级）

1. 禁止新增任何绕过 `LocalWriteCoordinator` 的业务写入。
2. 禁止恢复或新增 `saveSyncInternalNote` 旁路 API。
3. 禁止 UI 页面层直接依赖：
   - `noteRepositoryProvider`
   - `localWriteCoordinatorProvider`
   - `syncEngineProvider`
4. 禁止将服务端 `null`/空串的 `previewTitle|previewDescription|previewContent` 直接覆盖本地有效值。
5. 禁止在同步关键路径中破坏 Pull-first 顺序。
6. 修改同步字段时，必须同时检查 Pull 合并逻辑、Push 回滚逻辑、Mapper 映射逻辑三处是否一致。

---

## 6. 字段合并规则（现行业务规则）

### 6.1 本地无 pending mutation

1. 使用粗粒度 LWW：`server.updatedAt >= local.updatedAt` 则服务端胜。
2. 服务端胜时可全量覆盖（保留 Isar id）。

### 6.2 本地有 pending mutation

1. 走字段级合并：只覆盖“服务端托管字段”。
2. 本地锁定字段（不可被服务端覆盖）：
   - `title`
   - `content`
   - `url`
   - `categoryId`
   - `time`
3. `tags` 使用并集合并，保持本地顺序优先（见 `TagListUtils.mergeLocalAndServer`）。

### 6.3 preview 字段

1. `previewTitle|previewDescription|previewContent` 使用非空覆盖策略。
2. `previewImageUrl` 在服务端未携带该字段时保留本地值（fallback）。

---

## 7. 标准改造流程（给后续 Agent）

1. 先定位改动属于哪一层：UI / Service / Coordinator / Mapper / Test。
2. 若涉及“写入”，先确认是否经过 `NoteService` -> `LocalWriteCoordinator`。
3. 若涉及“服务端覆盖本地”，同时检查：
   - `note_sync_payload_mapper.dart`
   - `pull_coordinator.dart` 的 `_mergeServerManagedFields`
   - `push_coordinator.dart` 的 409 冲突回滚分支
4. 若新增后台链路（爬虫/轮询/回调），必须调用 `persistDerivedNoteForSync`。
5. 修改后至少运行 `flutter test test/sync`。

---

## 8. 必跑测试（最小回归集）

1. `mobile/test/sync/write_path_guard_test.dart`
   - 防止旁路写符号回流。

2. `mobile/test/sync/ui_layer_boundary_guard_test.dart`
   - 防止 UI 直接依赖同步底层 Provider。

3. `mobile/test/sync/derived_sync_write_usage_test.dart`
   - 确保 AI 轮询/后台回调都走统一写入口。

4. `mobile/test/sync/note_sync_payload_mapper_test.dart`
   - 确保 preview 字段防空覆盖规则不回归。

5. 命令：

```bash
cd mobile
flutter test test/sync
```

---

## 9. 常见问题与处理指引

1. 症状：分享后 preview 字段又丢了。
   - 优先检查 `NoteSyncPayloadMapper._resolvePreviewField` 与 Pull 合并逻辑。

2. 症状：本地抓取到了内容，但另一端看不到。
   - 检查是否走了 `persistDerivedNoteForSync`，是否产生 MutationEntry。

3. 症状：UI 一改就触发分层守卫测试失败。
   - 检查 UI 页面是否直接引用了底层 Provider，改为通过 `NoteService`。

4. 症状：同步频繁并发、网络抖动时反复请求。
   - 检查是否破坏了 `SyncEngine` 的 single-flight（`_isPulling` + `_hasPendingKick`）。

---

## 10. 变更维护要求

当以下文件发生实质行为变化时，必须同步更新本 Skill：

1. `mobile/lib/service/note_service.dart`
2. `mobile/lib/sync/local_write_coordinator.dart`
3. `mobile/lib/sync/sync_engine.dart`
4. `mobile/lib/sync/pull_coordinator.dart`
5. `mobile/lib/sync/push_coordinator.dart`
6. `mobile/lib/sync/note_sync_payload_mapper.dart`
7. `mobile/lib/sync/resource_fetch_scheduler.dart`
8. `mobile/test/sync/*.dart`

更新要求：

1. 同步更新“业务目标”和“禁令”章节。
2. 同步更新“字段合并规则”。
3. 同步更新“必跑测试”章节，保持与当前守卫策略一致。
