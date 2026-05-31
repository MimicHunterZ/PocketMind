# 资源抓取流水线架构

> 适用范围：移动端"分享 URL → 抓取 metadata / 图片 / 提交 AI 分析"的整条链路。
>
> 本文档是这套链路的设计源文件，所有相关代码以此为准。修改本文档同步影响 `lib/sync/`、`lib/service/call_back_dispatcher.dart`、`lib/main.dart`、`lib/main_share.dart` 等模块。

---

## 1. 设计目标

1. **单一调度入口**：分享、回前台、网络恢复、通知重试，所有触发路径都汇聚到同一个 scheduler。
2. **崩溃可恢复**：进程在抓取过程中被杀（OOM / 强退 / Workmanager 超时），下次启动能自动接管，不丢数据、不重复爬取。
3. **失败可观测**：每一次抓取尝试（含失败、崩溃）都留下一条历史记录，UI 可直接查询展示。
4. **关注点分离**：领域对象 `Note` 不承载执行细节；执行状态、重试计数、lease 都放在专门的作业表里。
5. **跨 isolate 安全**：前台 isolate 与 Workmanager 后台 isolate 同时运行时，不会双跑同一条 note。

---

## 2. 核心模型

将"领域"和"执行"拆成两张 Isar collection。

### 2.1 `Note`（领域）

```dart
@collection
class Note {
  // ... 业务字段 ...

  /// 资源抓取的领域状态，三态：
  /// - PENDING  : 有 url 但还没抓到内容
  /// - CRAWLED  : 已成功抓取，终态
  /// - FAILED   : 抓取彻底失败，终态
  String resourceStatus;

  // 不再存储任何执行细节：无 retryCount、无 SCRAPING、无 lease。
}
```

`resourceStatus` 是**派生字段**——由 scheduler 在 finalize 阶段反向写入，仅供 UI 列表快速过滤使用。读端不应该依赖它判断"是不是正在抓"。

### 2.2 `ScrapeAttempt`（执行 + 历史）

```dart
@collection
class ScrapeAttempt {
  Id? id;

  /// 关联到 Note.uuid
  @Index() late String noteUuid;

  /// queued / running / succeeded / failed / cancelled
  @Index() late String state;

  /// 同一 noteUuid 下的第几次尝试（从 1 起）
  late int attemptNumber;

  late DateTime enqueuedAt;
  DateTime? claimedAt;            // running 起始时间，悬挂检测的依据
  DateTime? finishedAt;

  /// claim 这次尝试的进程标识（isolate 启动时生成的 UUID）
  String? claimedBy;

  /// network / cookie_expired / parse / quota / cancelled / crashed / unknown
  String? errorCode;
  String? errorMessage;
}
```

**关键不变量**：

- 同一个 `noteUuid` 下，`state ∈ {queued, running}` 的记录**至多 1 条**。由 enqueue 时的前置检查 + `writeTxn` 串行性保证。
- 终态记录（`succeeded` / `failed` / `cancelled`）**不可再修改**，永久保留作为历史。
- `attemptNumber` 单调递增，可用于读端判定"这条 note 已经被试了几次"。

---

## 3. 状态机

### 3.1 Note 状态机（3 态）

```
       localCreatedWithUrl
              │
              ▼
         ┌─────────┐
         │ PENDING │ ◀──── userRequestedRetry
         └─────────┘       (FAILED → PENDING)
              │
   attempt    │
   succeeded  │
              ▼
         ┌─────────┐
         │ CRAWLED │  终态，不回退
         └─────────┘

         ┌─────────┐
         │ FAILED  │  终态（attemptNumber 达上限，或硬失败）
         └─────────┘
```

`Note.resourceStatus` 的所有写入都集中在 scheduler.finalize 内，且遵循"CRAWLED 终态绝不回退"的原则。

### 3.2 ScrapeAttempt 状态机

```
   enqueue
      │
      ▼
 ┌─────────┐  claim    ┌─────────┐
 │ queued  │──────────▶│ running │
 └─────────┘           └─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   ┌──────────┐       ┌──────────┐        ┌──────────┐
   │succeeded │       │  failed  │        │cancelled │
   └──────────┘       └──────────┘        └──────────┘
                  (errorCode 描述失败种类，包括 'crashed')
```

---

## 4. 生命周期与触发路径

### 4.1 唯一调度入口

```
ResourceFetchScheduler.runNow(userQuestion?)
   ├── [已有 _inFlight Future？→ 直接复用，不重跑]
   ├── _drainPendingAiSubmissions()   # best-effort 补偿：重试上次失败的 AI 提交
   ├── enqueueOrphanedPendingNotes()  # 兜底：把游离 PENDING note 补入队
   ├── while (attemptId = claimNext()) != null:
   │       process(attemptId)        # 内部包含 finalize
   └── 通知（如有终态失败）
```

`_inFlight` 是一个 `Future<void>?` 字段——第一个 `runNow()` 调用把 `_runOnce` 的 Future 赋给它，后续所有并发调用都 `return _inFlight!`，共享同一次扫描，直到它完成后置空。这样无论从哪条路径重复触发，都不会双跑。

### 4.2 触发路径全景

| 场景 | 路径 |
|---|---|
| 用户分享 URL | `main_share` 落 Note(`resourceStatus=PENDING`) → 注册 Workmanager 一次性任务 → `callbackDispatcher` → `scheduler.runNow()` |
| 主 App 启动 | `main.initState` **显式**调用 `scheduler.start()` → 首次扫描 `runNow()` + 订阅网络变化 |
| 主 App resumed | `main.didChangeAppLifecycleState` → `scheduler.runNow()` |
| 网络恢复 | `scheduler.start()` 内订阅 `Connectivity.onConnectivityChanged` → `scheduler.runNow()` |
| Workmanager 后台 isolate | `callbackDispatcher` → **直接** `scheduler.runNow()`；该 isolate **不调用 `start()`** |
| 通知"重试" | Workmanager → `callbackDispatcher` → `scheduler.retryNotes(noteUuids)`（FAILED→PENDING + enqueueIfAbsent）→ `scheduler.runNow()` |
| 通知"忽略" | Workmanager → `callbackDispatcher` → `scheduler.dismissNotes(noteUuids)`（取消 live attempt + Note→FAILED） |
| 同 isolate 重复触发 | 第二个 `runNow()` 检测到 `_inFlight != null`，直接复用同一 Future，不重跑 |

> **`start()` 仅在主 App isolate 的 `initState` 中显式调用一次**。  
> Workmanager 后台 isolate 和分享 isolate 不调用 `start()`——它们直接调用 `runNow()`，只需要单次扫描，无需订阅网络变化（订阅在 isolate 退出后也会丢失）。  
> `sync_providers.dart` 的 provider 工厂中**不调用** `start()`，避免后台 isolate 构建 provider 时意外触发。

**所有路径里没有任何地方会"删除 url"**。url 永远留在 Note 上。

### 4.3 单次 attempt 的内部流水线（三段）

`_process` 拆分为三个 phase，**只有 Phase 1 失败才算 scrape 失败**——这条规则把"客户端本地爬到了 metadata、但后端 AI 提交因网络问题失败"这种情况和"真的爬不到内容"严格分开。

```
process(attemptId):
  attempt = isar.scrapeAttempts.get(attemptId)
  note    = isar.notes.where(uuid == attempt.noteUuid).findFirst()

  if note == null OR note.isDeleted:
      finalize(attemptId, state='cancelled')
      return

  # ─── Phase 1: 本地 metadata（必须成功） ───
  try:
    metadata = MetadataManager.fetchAndProcessMetadata([note.url])
    更新 note 的 preview* 字段（previewTitle / previewContent / previewImageUrl）
  except e:
    handleScrapeFailure(attempt, note, e)   # ↓ Phase 1 失败处理
    return

  # ─── Phase 2: 后端动作（best-effort，失败不影响 scrape 状态） ───
  if isPlatformScraper:
    try { uploadImagesAndPersistAssets(note, meta.imageUrls) }
    except e: log.warn （单图失败已被内部吞掉，本地资产保留）

  if noteApi != null:
    try {
      noteApi.submitAnalysis(...)
      enqueueAiAnalysis(noteUuid)         # 加入 keyPendingAiAnalysis 给 polling
    }
    except e:
      markPendingAiSubmission(noteUuid)   # 加入 keyPendingAiSubmission
      log.warn （**仍然会进 Phase 3，scrape 算成功**）

  # ─── Phase 3: 持久化 + finalize ───
  noteService.persistDerivedNoteForSync(note)
  finalize(attemptId, state='succeeded')
      └─▶ Note.resourceStatus = CRAWLED


handleScrapeFailure(attempt, note, e):
    errorCode = classify(e)
    terminal  = attempt.attemptNumber >= maxScrapeAttempts (=3)
    finalize(attempt.id, state='failed', errorCode=errorCode, terminal=terminal)
    if not terminal:
        # 关键：退避后才允许下一次被 claim
        backoff = scrapeBackoffSchedule[attempt.attemptNumber - 1]
        enqueueIfAbsent(noteUuid, enqueuedAt = now + backoff)
    else:
        Note.resourceStatus = FAILED + 终态通知
```

**Phase 2 的 AI 提交失败会进 `keyPendingAiSubmission` 列表**；下一次 `runNow()` 入口会 best-effort drain 这个列表（每个 noteUuid 重新提交一次），成功就移走，仍失败就留下次再来。这条路径**完全不计入 ScrapeAttempt 重试计数**，后端长期不可用时不会触发"3 次失败"通知。

### 4.4 软失败退避表

| 第几次 attempt 失败 | 下次重试时间 |
|---|---|
| attempt 1 | now + 1 分钟 |
| attempt 2 | now + 5 分钟 |
| attempt 3 | terminal（不再重试） |

退避通过给重入队的 ScrapeAttempt 设 `enqueuedAt = now + backoff`、`claimNext` filter `enqueuedAt <= now` 实现。这样**同一轮 `runNow` 的 outer loop 不会立刻把刚失败的作业捡回来重跑**——避免短暂网络抖动直接打满 3 次失败通知。

退避表见 `AppConstants.scrapeBackoffSchedule`。

---

## 5. 并发与崩溃安全

### 5.1 lease 阈值

`LEASE_THRESHOLD = 5 minutes`

Worker 在 `claim` 时把 `claimedAt = now`；超过 5 分钟没动的 running 行视为悬挂。该值远大于实际抓取耗时（通常 1–2 分钟），把"被错误判定为悬挂"挤到长尾。

### 5.2 claim：CAS + 悬挂复活（"立墓志铭"模式）

```dart
Future<int?> claimNext() async {
  return isar.writeTxn(() async {
    final row = await isar.scrapeAttempts
        .filter()
        .stateEqualTo('queued')
        .or()
        .group((q) => q
            .stateEqualTo('running')
            .and()
            .claimedAtLessThan(DateTime.now().subtract(LEASE_THRESHOLD)))
        .sortByEnqueuedAt()
        .findFirst();

    if (row == null) return null;

    if (row.state == 'running') {
      // 给前一次执行立墓志铭：复制一份失败记录
      await isar.scrapeAttempts.put(ScrapeAttempt()
        ..noteUuid      = row.noteUuid
        ..attemptNumber = row.attemptNumber
        ..state         = 'failed'
        ..errorCode     = 'crashed'
        ..enqueuedAt    = row.enqueuedAt
        ..claimedAt     = row.claimedAt
        ..claimedBy     = row.claimedBy
        ..finishedAt    = DateTime.now()
        ..errorMessage  = 'Lease expired, presumed crashed');

      // 当前行升级为新的一次尝试
      row.attemptNumber += 1;
    }

    row.state     = 'running';
    row.claimedAt = DateTime.now();
    row.claimedBy = ProcessId.current;   // isolate 启动时生成
    await isar.scrapeAttempts.put(row);
    return row.id;
  });
}
```

Isar 的 `writeTxn` 跨 isolate 串行化，确保两个 isolate 同时 claim 时同一行不会被双领。

### 5.3 enqueue：写前去重

```dart
Future<void> enqueueIfAbsent(String noteUuid, {int? attemptNumber}) async {
  await isar.writeTxn(() async {
    final note = await isar.notes.where().uuidEqualTo(noteUuid).findFirst();
    if (note == null) return;
    if (note.resourceStatus == CRAWLED) return;          // 终态拒绝
    final exists = await isar.scrapeAttempts
        .filter()
        .noteUuidEqualTo(noteUuid)
        .stateEqualTo('queued')
        .or()
        .group((q) => q.noteUuidEqualTo(noteUuid).stateEqualTo('running'))
        .findFirst();
    if (exists != null) return;                           // 幂等

    final n = attemptNumber ?? (await _nextAttemptNumber(noteUuid));
    await isar.scrapeAttempts.put(ScrapeAttempt()
      ..noteUuid      = noteUuid
      ..state         = 'queued'
      ..attemptNumber = n
      ..enqueuedAt    = DateTime.now());
  });
}
```

### 5.4 finalize：写回 CAS

防止"慢 worker"覆盖已被新 worker 接管的行：

```dart
Future<void> finalize(int attemptId, {
  required String state,
  String? errorCode,
  String? errorMessage,
}) async {
  await isar.writeTxn(() async {
    final row = await isar.scrapeAttempts.get(attemptId);
    if (row == null) return;
    if (row.claimedBy != ProcessId.current) return;   // 我已被收编，丢弃结果
    if (row.state != 'running') return;               // 同上

    row.state        = state;
    row.errorCode    = errorCode;
    row.errorMessage = errorMessage;
    row.finishedAt   = DateTime.now();
    await isar.scrapeAttempts.put(row);

    // 顺带更新 Note.resourceStatus，但 CRAWLED 不回退
    final note = await isar.notes.where().uuidEqualTo(row.noteUuid).findFirst();
    if (note == null || note.resourceStatus == CRAWLED) return;

    if (state == 'succeeded') {
      note.resourceStatus = CRAWLED;
      await isar.notes.put(note);
    } else if (state == 'failed' && _isTerminal(row, errorCode)) {
      note.resourceStatus = FAILED;
      await isar.notes.put(note);
    }
  });
}
```

`_isTerminal` 的判定：`attemptNumber >= 3` 或 `errorCode` 属于硬失败白名单（cookie_expired 等）。

### 5.5 慢 worker 兜底：副作用幂等

唯一无法靠数据库锁解决的竞态：worker A 跑得慢、被认定悬挂、worker B 接管，A 后续仍跑完。此时 A 的写回会被 5.4 的 CAS 拦掉，但**它在 finalize 之前的副作用已经发生**。

| 副作用 | 兜底机制 |
|---|---|
| metadata 网络抓取 | 幂等读 |
| 图片本地落盘 | sha256 内容寻址，相同 url 命中已有文件不再下载 |
| 图片上传到后端 | **后端按 (noteUuid, sha256) 做幂等校验** |
| AI 分析 submit | **后端按 noteUuid 做幂等校验** |
| AI 轮询入队 | SharedPreferences 列表 `if !contains add` |

**约定**：图片上传与 AI submit 接口的幂等性由后端保证，移动端只负责正常发起调用。

### 5.6 跨 isolate 安全总结表

| 竞态 | 兜底 | 残余风险 |
|---|---|---|
| 同/跨 isolate 抢 claim | `writeTxn` + filter + claimedBy | 无 |
| 同 noteUuid 重复入队 | `writeTxn` + 唯一性 filter + 终态拦截 | 无 |
| 进程被杀 | 5 分钟阈值 + 立墓志铭 | 无 |
| 慢 worker 被抢占 | 5.4 CAS + 5.5 幂等 | 仅多一次后端调用，结果一致 |
| CRAWLED 仍残留 queued | enqueue 终态拦截 + finalize 终态不回退 | 无 |
| 抓取中删除 note | finalize 写 cancelled，不动 Note | 无 |

---

## 6. claim 节奏

scheduler 内 outer loop **一次只领一条**。实际实现中 `runNow` 使用 `_inFlight` 字段做 Future 收敛——同一 isolate 内的并发调用会复用同一轮扫描：

```dart
Future<void> runNow({String? userQuestion}) {
  if (_inFlight != null) {
    PMlog.d(_tag, '复用进行中的扫描');
    return _inFlight!;
  }
  final f = _runOnce(userQuestion: userQuestion);
  _inFlight = f.whenComplete(() => _inFlight = null);
  return _inFlight!;
}

Future<void> _runOnce({String? userQuestion}) async {
  // 1. best-effort 补偿上次未提交的 AI 任务
  await _drainPendingAiSubmissions();

  // 2. 把游离的 PENDING note（有 url 但无 live attempt）补入队
  await enqueueOrphanedPendingNotes();

  // 3. 逐条领取并执行
  while (true) {
    final id = await claimNext();
    if (id == null) break;
    await _process(id);
  }
}
```

不批量 claim 的原因：批量会让多条 running 行共用同一个 `claimedAt`，悬挂检测的语义会模糊；一条一条 claim 可以让每条 attempt 都有独立的 lease 时间窗，行为更清晰，吞吐量在端侧场景里也够用。

---

## 7. 文件清单

修改以下任一文件时，**必须同步更新本文档**。

| 文件 | 职责 |
|---|---|
| `lib/model/note.dart` | `resourceStatus` 三态枚举 |
| `lib/model/scrape_attempt.dart` | 作业 + 历史 collection |
| `lib/sync/resource_status_state_machine.dart` | Note 状态机（事件 → 三态转移） |
| `lib/sync/scrape_attempt_state.dart` | Attempt 活跃态集合（`ScrapeAttemptState.live`） |
| `lib/sync/resource_fetch_scheduler.dart` | `runNow` / `claimNext` / `finalize` / `_process` / `start` 触发订阅 |
| `lib/sync/process_id.dart` | 每个 isolate 启动时生成的 UUID（用于 CAS `claimedBy`） |
| `lib/service/call_back_dispatcher.dart` | Workmanager 任务路由到 scheduler；任务结束后显式关闭 Isar |
| `lib/service/notification_service.dart` | 通知按钮 → Workmanager 任务，payload 中携带 `failedNoteUuids` |
| `lib/main.dart` | **显式**调用 `scheduler.start()`；resumed → `scheduler.runNow()` |
| `lib/main_share.dart` | 落 Note + 注册 Workmanager 任务；本进程不调用 `start()` |
| `lib/providers/sync_providers.dart` | scheduler 依赖注入；provider 工厂中**不调用** `start()` |

---

## 8. 开发约束

1. **禁止**在 `Note` 上添加任何执行类字段（lease、retryCount、claimedBy 等）。需要新增的执行元数据一律加到 `ScrapeAttempt` 上。
2. **禁止**在 scheduler 之外的地方写 `Note.resourceStatus` 或 `ScrapeAttempt`。仅 `scheduler.finalize` / `scheduler.enqueueIfAbsent` / `scheduler.claimNext` 是合法入口。`call_back_dispatcher` 的"忽略"动作也走这些 API，不直接操纵字段。
3. **禁止**新增独立的 Workmanager 任务名称去做"标记失败 / 通知"等业务，所有业务收敛到 scheduler。Workmanager 任务名称只用作"拉一次 scheduler"或"按 noteUuid 触发某个 scheduler API"。
4. **禁止**在 SharedPreferences 上恢复任何 URL 队列 / retryCount map / 终态列表。这些都是 ScrapeAttempt 的职责。
5. **状态机变更**必须配套修改单元测试，并保留架构守护测试覆盖。
6. **禁止**在 `sync_providers.dart` 的 provider 工厂、Workmanager 后台 isolate、分享 isolate 中调用 `scheduler.start()`。`start()` 只在主 App 的 `main.dart initState` 中显式调用一次。后台 isolate 只需直接调用 `runNow()`——其 isolate 生命周期由 Workmanager 管控，订阅无意义且会在 isolate 退出时丢失。

---

## 9. 测试策略

| 层级 | 内容 |
|---|---|
| 状态机单元测试 | Note 状态机三态转移；ScrapeAttempt 状态机 5 态转移 |
| Scheduler 单元测试 | 用真 Isar（test 临时目录）：claim → process → finalize 全链路；同 noteUuid 双入队幂等；CRAWLED 拒绝再入队；finalize 后 Note.resourceStatus 正确 |
| 崩溃恢复测试 | 模拟 lease 过期：插入 running + 旧 claimedAt → claim 应该复活并写一条 crashed 历史 |
| CAS 测试 | 模拟双 worker：A 拿到 attemptId 后被抢，A finalize 时应静默丢弃 |
| 架构守护测试 | 正则扫源码：除 scheduler 外不得直接赋值 `resourceStatus` / `ScrapeAttempt` 字段 |

---

## 10. 历史

| 版本 | 时间 | 变更 |
|---|---|---|
| v1 | 2026-05 | 初版：废弃 SharedPreferences URL 队列、`Note.retryCount`，引入 `ScrapeAttempt` 作业表 + 三态 `Note.resourceStatus` |
| v1.1 | 2026-05 | **isolate 修复**：移除 provider 工厂中的 `start()` 调用，改为 `main.dart initState` 显式调用；修复 Workmanager isolate 因 `runNow` 被 `_isRunning` 标志立即跳过导致后台任务立刻返回、isolate 被 Android 杀死的问题。**`_inFlight` 收敛**：将 `_isRunning: bool` 替换为 `_inFlight: Future<void>?`，并发调用复用同一 Future 而非静默跳过。**三段流水线**：将 `_process` 拆为 Phase 1（本地 metadata，必须成功）/ Phase 2（后端动作，best-effort）/ Phase 3（持久化 + finalize），Phase 2 失败不再计入 scrape 失败次数，AI 提交失败写入 `keyPendingAiSubmission` 延后补偿。**软失败退避**：Phase 1 失败后重入队时设 `enqueuedAt = now + backoff`（1min / 5min），`claimNext` 过滤未到时间的行，防止同一轮 `runNow` 内连续打满 3 次失败。**CR 清理**：删除 `scraper_task.dart`、死代码 repository/service 方法、`Note.retryCount`、`ScrapeAttemptState` 多余方法；dispatcher 补 `isar.close()`；通知 payload 由 URL 改为 noteUuid。 |
