# CRAWLED 状态不可降级设计

## 背景

PocketMind 移动端笔记资源抓取状态（`resourceStatus`）采用状态机驱动，状态流转为：

```
null → PENDING → SCRAPING → CRAWLED
                          → FAILED
```

`CRAWLED` 表示资源抓取成功，是笔记资源处理的终态。当前状态机 `ResourceStatusStateMachine.reduce()` 已实现 CRAWLED 不降级保护，但 `NoteService.updateNote()` 中存在直接赋值绕过状态机的漏洞。

## 需求

1. `resourceStatus = CRAWLED` 后，该字段**不可被降级**为其他状态（PENDING / SCRAPING / FAILED）
2. 后台（AI 管线 / 同步 Pull）仍可更新 previewTitle、previewDescription、previewContent、previewImageUrl、aiSummary 等衍生字段（非空覆盖）
3. 仅在移动端加固，后端不改动
4. UI 层无感知，数据静默刷新

## 方案：状态机统一守门

所有 `resourceStatus` 变更路径均通过 `ResourceStatusStateMachine.reduce()` 做决策，复用已有的「CRAWLED 不降级」规则。

### 核心变更

**文件**: `mobile/lib/service/note_service.dart` — `updateNote()` 方法

**当前实现（有缺陷）：**
```dart
existingNote
  ..resourceStatus = resourceStatus ?? existingNote.resourceStatus
```

直接赋值，绕过状态机保护。

**改为：**
```dart
if (resourceStatus != null && resourceStatus != existingNote.resourceStatus) {
  existingNote.resourceStatus = ResourceStatusStateMachine.reduce(
    current: existingNote.resourceStatus,
    event: ResourceStatusEvent.serverSnapshot,
    incoming: resourceStatus,
  );
}
```

选用 `serverSnapshot` 事件是因为它已有「CRAWLED 时维持不变」的语义，复用最简洁。

### 路径覆盖确认

| 写入路径 | 是否经过状态机 | 保护状态 |
|----------|--------------|---------|
| `NoteService.updateNote()` | 改后 ✅ | 本次加固 |
| `NoteService.applyResourceStatusEvent()` | ✅ 直接调 `reduce()` | 已保护 |
| `NoteService.persistDerivedNoteForSync()` | 调用方自行先通过 `applyResourceStatusEvent` | 已保护 |
| `PullCoordinator._mergeServerManagedFields()` | ✅ 用 `reduce(serverSnapshot)` | 已保护 |
| Pull 无 pending 全量覆盖 | 经 `NoteSyncPayloadMapper` + fallback | 已保护 |

### 预览字段非空覆盖（已有保护，无需改动）

- `PullCoordinator._mergeServerManagedFields()` 中 previewTitle/Description/Content 已有 `trim().isNotEmpty` 检查
- `NoteSyncPayloadMapper` 使用 `fallbackResourceStatus` 保留本地值
- 后台回写空值不会覆盖本地有效值

## 影响范围

- **改动文件**: `mobile/lib/service/note_service.dart`（updateNote 方法，约 5 行变更）
- **新增文件**: `mobile/test/sync/crawled_status_immutability_test.dart`
- **后端**: 无改动
- **UI**: 无改动

## 测试计划

新增测试用例（`test/sync/crawled_status_immutability_test.dart`）：

1. `CRAWLED` 笔记调用 `updateNote(resourceStatus: 'PENDING')` → 状态仍为 `CRAWLED`
2. `CRAWLED` 笔记调用 `updateNote(resourceStatus: 'FAILED')` → 状态仍为 `CRAWLED`
3. `CRAWLED` 笔记调用 `updateNote(resourceStatus: 'SCRAPING')` → 状态仍为 `CRAWLED`
4. `PENDING` 笔记调用 `updateNote(resourceStatus: 'CRAWLED')` → 可正常升级为 `CRAWLED`
5. `FAILED` 笔记经 `serverSnapshot(CRAWLED)` → 可升级为 `CRAWLED`

回归测试：运行 `flutter test test/sync` 确保现有守卫测试不受影响。

## 状态机规则总结（最终版）

```
reduce(current, event, incoming):
  if current == CRAWLED → return CRAWLED  // 终态不降级
  
  serverSnapshot:
    if incoming == null → return current  // 保持现状
    if current == FAILED && incoming != CRAWLED → return FAILED  // 屏障
    else → return incoming  // 接受服务端值
```
