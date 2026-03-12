---
name: pocketmind-context-architecture
description: 设计、重构和实现 PocketMind 项目中的整体上下文架构（Context Architecture），用于统一规划和落地 resources、user memories、agent memories、tenant skills、session、retrieval、ingestion、storage 与现有 Note/Chat/Asset 的边界。当用户要求为 PocketMind 新增长期记忆、重构 AI 上下文体系、借鉴 OpenViking 的上下文类型/层级/URI/存储/检索/会话思想，或需要分阶段实施 Context Service 时使用。
---

# PocketMind Context Architecture — 总规范

> **一句话**：业务真相源 + 上下文投影层 + 记忆沉淀层 + 检索装配层 + 技能能力层 — 学 OpenViking 的语义边界，不复制其物理形态。DB 存动态知识，文件存静态能力，AI Tool Bridge 实现渐进披露。

---

## §1 一页结论

1. `Note / ChatSession / ChatMessage / Asset` 继续作为**产品业务真相源**，不被上下文层取代。
2. `Resource` 是 AI 可消费材料层 — 从业务对象投影而来，不是新主模型。
3. `Memory` 是长期知识层 — 从 Resource 与 Session 中**提炼**的稳定语义单元，不是原文副本。
4. `Skill` 是租户级/系统级能力定义 — prompt + tool + policy + workflow，不是用户内容。
5. `Session.commit()` 是知识沉淀边界 — 归档 → 提取 → 去重 → 持久化 → 索引。
6. `Retrieval` 是正式能力链路 — 意图分析 → 并发召回 → 重排序 → 预算装配。
7. 语义层级统一采用 `L0(Abstract ~100tok) / L1(Overview ~2k tok) / L2(Detail 全文)` — 与 OpenViking 及 `ContextLayer.java` 完全一致。
8. 渐进迁移：新增正确链路、逐步下线旧链路，每阶段必须编译+测试+启动通过。
9. **双通道检索**：服务端预注入（IntentAnalyzer → pgvector → system prompt）+ AI主动发现（Memory Tool Set → 渐进式tool call）。
10. **存储分界线**：Skills = 文件系统（少量、静态、人工编写）；Memories/Resources = PostgreSQL + pgvector（动态、AI提取、需向量搜索、移动端可见）。
11. **HierarchicalRetriever** 接口 Day 1 落地，`ChildSearchStrategy` SPI 支持实现热替换（keyword → pgvector），算法不改。

---

## §2 使用方式

当用户提出记忆/上下文/技能/检索/资源同步相关需求时：

1. **定位层次** — 属于哪一层：业务真相源 / 资源投影 / 记忆沉淀 / 检索装配 / 技能能力 / 会话提交。
2. **识别真相源** — 先确认主真相源对象，不要上来就扩 context 表。
3. **回答五问** — ①主真相源是谁 ②投影由谁生成 ③记忆由什么触发 ④检索如何回溯 ⑤多租户隔离在哪。
4. **阶段裁剪** — 跨多阶段的需求必须拆分，每阶段编译+相关测试+启动验证。
5. **查阅参考** — `references/product-requirements-prd.md`（PRD）、`references/implementation-todo.md`（TODO）、`references/openviking-deep-analysis.md`（OpenViking 深度分析）。

---

## §3 核心原则（禁令清单）

| # | 原则 | 违规示例 |
|---|------|----------|
| P1 | 业务真相源优先 | 把 Resource 当新主业务表 |
| P2 | 存储按对象属性选型 | 把 Memory 存为文件（应在 DB）；把 Skill 改存 DB（应在文件） |
| P3 | 渐进迁移 | 一次切换所有入口 |
| P4 | 上下文是派生层 | ResourceRecord 取代 Note 对外暴露 |
| P5 | 检索是正式链路 | 在 Service 里 `note.getContent() + summary` 拼接 |
| P6 | Memory ≠ 原文 | 把整段 transcript 直接写成 memory |
| P7 | 空间隔离 | 未定义 owner/tenant/visibility 就做全局检索 |
| P8 | 每阶段可验证 | 未编译通过就推进下一阶段 |
| P9 | Memory 必有 evidence | 写入 memory 不保留来源引用 |
| P10 | Skill ≠ Memory | 把 Skill 持久化为用户知识记录 |
| P11 | 上下文是渐进披露的 | 把所有 context 一口气塞入 system prompt |
| P12 | 检索接口 Day 1 稳定 | 先用简单实现、后续推翻重写接口 |

---

## §4 六层架构蓝图

```
┌───────────────────────────────────────────────────┐
│  L7  AI 模型调用层                                  │
│      ChatClient + SSE Stream + PromptBuilder        │
├───────────────────────────────────────────────────┤
│  L6  AI Tool Bridge 层（渐进披露）                    │
│      MemoryToolSet + SkillsTool + FileSystemTools    │
│      browseCategories / searchMemories / getDetail  │
├───────────────────────────────────────────────────┤
│  L5  检索与装配层（服务端预注入）                      │
│      IntentAnalyzer → HierarchicalRetriever         │
│      → HotnessScorer → ContextAssembler             │
├───────────────────────────────────────────────────┤
│  L4  技能能力层 (文件系统)                            │
│      SharedSkill(SYSTEM) + TenantSkill + AgentOverlay│
├───────────────────────────────────────────────────┤
│  L3  记忆沉淀层 (PostgreSQL)                         │
│      UserMemory + AgentMemory + Evidence + Merge    │
├───────────────────────────────────────────────────┤
│  L2  内容投影层 (PostgreSQL)                         │
│      ResourceRecord + ResourceChunk + ContextRef    │
├───────────────────────────────────────────────────┤
│  L1  产品业务真相层 (PostgreSQL)                      │
│      Note / ChatSession / ChatMessage / Asset       │
├───────────────────────────────────────────────────┤
│  L0  存储·索引层                                     │
│      PostgreSQL / pgvector / Asset存储(文件) / 队列   │
└───────────────────────────────────────────────────┘
```

### 层间契约

- L1→L2：业务变更事件触发投影（同步或异步）
- L2→L3：Session commit / Note 更新触发记忆提取
- L3→L5：**服务端预注入** — Retriever 读取 Memory + Resource → 注入 system prompt
- L3→L6：**AI主动发现** — AI 通过 MemoryToolSet 渐进式 tool call
- L4→L6：Skills 保持文件系统读取（SkillsTool, 已有）
- L5+L6→L7：ContextAssembler + ToolCallbacks → ChatClient.prompt()

### 双通道检索架构

```
请求到达:
  ┌─→ 通道A: 服务端预注入 (低延迟, 高概率命中)
  │   IntentAnalyzer → pgvector向量搜索 → Hotness重排 → L1注入system prompt
  │   时机: AI开口前 | 代价: 0次tool call
  │
  └─→ 通道B: AI主动发现 (按需, 深度获取)
      AI调用 browseCategories() → searchMemories(query) → getDetail(id)
      时机: 对话中AI判断需要更多上下文 | 代价: 1-3次tool call

两通道并行互补: A保证基本覆盖, B提供深度探索能力
```

---

## §5 核心对象模型

### 5.1 业务对象（L1 真相源）

`Note`、`ChatSession`、`ChatMessage`、`Asset` — 由产品 Service 维护，AI 层只做读取/投影/引用。

### 5.2 Resource（L2 投影层）

Resource 是"材料层"，把分散内容转化为统一可检索的 AI 消费材料。

**最小字段集**：`resourceId, resourceType, sourceType, sourceBizId, tenantId, ownerId, title, normalizedText, summaryText, layer(L0/L1/L2), status, hash, contextUri, updatedAt`

**来源分组**：
1. 笔记类：`NOTE_BODY`
2. 会话类：`CHAT_TRANSCRIPT`, `CHAT_STAGE_SUMMARY`
3. 导入类：`WEB_CLIP`, `MARKDOWN_IMPORT`
4. 附件类：`OCR_TEXT`, `PDF_TEXT`, `AUDIO_TRANSCRIPT`
5. 系统类：`ANALYSIS_RESULT`

### 5.3 Memory（L3 沉淀层）

Memory 是从材料中**提炼**的长期知识单元 — 可跨会话复用、可回溯来源、可更新/合并/失效。

**最小字段集**：`memoryId, memoryType, spaceType, ownerId, tenantId, title, normalizedContent, summary, confidenceScore, evidenceRefs, mergeKey, status, lastValidatedAt, activeCount, hotness`

**分类体系**（对齐 OpenViking 8 类）：

| 空间 | 类型 | 对应 OpenViking | 说明 |
|------|------|----------------|------|
| USER | `PROFILE` | profile | 身份特征、长期背景 |
| USER | `PREFERENCE` | preferences | 偏好、风格、习惯 |
| USER | `ENTITY` | entities | 人物、组织、项目、术语 |
| USER | `EVENT` | events | 事件、决策、里程碑 |
| AGENT | `CASE` | cases | 成功/失败案例 |
| AGENT | `PATTERN` | patterns | 可复用问题解决模式 |
| AGENT | `TOOL_EXPERIENCE` | tools | 工具使用技巧与统计 |
| AGENT | `SKILL_EXECUTION` | skills | 工作流策略与经验 |

**memory 三层内容表示**（对齐 L0/L1/L2）：

| 层级 | Token | 内容 | 用途 |
|------|-------|------|------|
| L0 Abstract | ~100 | 一句话摘要 | 向量检索、快速过滤 |
| L1 Overview | ~2k | 结构化概览 | 重排序、上下文导航 |
| L2 Detail | 无限 | 完整内容、evidence | 按需加载 |

### 5.4 Skill（L4 能力层）

Skill 是能力包：角色说明 + 任务策略 + Prompt 模板 + 工具绑定 + 约束 + 示例。

**空间归属**：
- `shared` → `SYSTEM` 空间
- `tenant` → `TENANT` 空间
- `agent overlay` → `AGENT` 空间

**解析策略**：请求级解析，按 tenant/agent/scene 组装，不在启动时固化为全局单例。

### 5.5 Session

产品会话 = `ChatSession`（用户可见）；上下文会话 = 一次 AI 执行聚合对象（追踪检索、装配、commit）。

一个产品会话可对应多个上下文提交批次。`session.commit()` = "本阶段材料已归档，可触发长期沉淀"。

---

## §6 空间模型

### 6.1 五层空间

| 空间 | owner | 典型对象 |
|------|-------|----------|
| `SYSTEM` | system | SharedSkill、平台规则 |
| `TENANT` | tenantId | TenantSkill、组织模板 |
| `AGENT` | agentKey | AgentMemory(CASE/PATTERN)、AgentOverlay |
| `USER` | userId | UserMemory(PROFILE/PREFERENCE/ENTITY/EVENT)、Resource |
| `SESSION` | userId | 当前轮次材料、临时检索结果 |

### 6.2 统一矩阵

| 对象 | 默认空间 | owner | 默认可见性 | 可长期保留 | 可正式检索 |
|------|---------|-------|-----------|-----------|-----------|
| Note | USER | userId | PRIVATE | 是 | 间接(→Resource) |
| ChatSession | SESSION | userId | PRIVATE | 是 | 间接(→transcript) |
| ChatMessage | SESSION | userId | PRIVATE | 是 | 间接(→session resource) |
| Asset | USER | userId | PRIVATE | 是 | 间接(→解析后Resource) |
| Resource(笔记/导入) | USER | userId | PRIVATE | 是 | 是 |
| Resource(会话阶段) | SESSION | userId | SESSION_ONLY | 视策略 | 是 |
| UserMemory | USER | userId | PRIVATE | 是 | 是 |
| SharedSkill | SYSTEM | system | SYSTEM_SHARED | 是 | 是 |
| TenantSkill | TENANT | tenantId | TENANT_SHARED | 是 | 是 |
| AgentOverlay | AGENT | agentKey | TENANT_SHARED+ | 是 | 是 |
| AgentMemory | AGENT | agentKey | 按策略 | 是 | 是 |

**执行规则**：无 owner + 空间定义的对象不允许进入正式检索。会话空间对象默认不进入用户长期记忆，必须经 commit + 提炼。

---

## §7 L0 / L1 / L2 语义层级

> **权威定义**：与 OpenViking `ContextLevel` 和 `ContextLayer.java` 完全一致。

| 层级 | 枚举值 | Token | 用途 | Resource 例子 | Memory 例子 |
|------|--------|-------|------|-------------|-------------|
| **L0** | `L0_ABSTRACT` / `ABSTRACT=0` | ~100 | 向量检索、快速过滤 | "PocketMind架构重构笔记，涉及Spring Boot 4和记忆系统设计" | "用户是全栈开发者，偏好中文输出" |
| **L1** | `L1_OVERVIEW` / `OVERVIEW=1` | ~2k | 重排序、内容导航 | 结构化摘要含章节/关键点/L2访问指引 | 结构化偏好列表含分类和优先级 |
| **L2** | `L2_DETAIL` / `DETAIL=2` | 无限 | 按需全文加载 | 笔记正文/transcript全文 | 完整 evidence + 合并历史 |

**核心要求**：
- 不同层可区分、可追溯到相同来源
- 不同层消费方不同（L0→向量DB，L1→Rerank，L2→最终prompt）
- 不同层保留策略不同

---

## §8 Session Commit 机制

### 8.1 commit 语义

`session.commit()` 表示：当前阶段材料已稳定，可归档为 Resource，可触发 memory 提炼，可刷新检索索引。

**不表示**：UI 上的"发送"、立即结束会话、删除原始历史。

### 8.2 触发方式

- 一轮任务完成 / 用户显式结束分析 / 消息数达阈值 / 会话暂停·归档 / 后台定时切段

### 8.3 commit 流水线（对齐 OpenViking session.commit()）

```
1. 归档当前阶段消息
   ├── 生成阶段 transcript resource (L2)
   ├── LLM 生成结构化摘要 → overview resource (L1)
   └── 从摘要提取 abstract (L0)

2. 提取长期记忆
   ├── MemoryExtractor: 从 transcript + context 中抽取 8 类 memory candidates
   │   每条包含 L0(abstract) + L1(content) + category + evidence_refs
   ├── MemoryDeduplicator: 向量预过滤 → LLM 去重决策
   │   候选决策: SKIP(重复) | CREATE(新建) | NONE(仅处理已有)
   │   已有记忆动作: MERGE(合并) | DELETE(删除冲突)
   └── 特殊规则: PROFILE 类始终合并; TOOL/SKILL 类统计累积

3. 持久化
   ├── 新 memory → INSERT (L0 + L1 + L2)
   ├── 合并 memory → LLM merge → UPDATE
   └── 删除 memory → 逻辑删除

4. 建立关联
   └── session_uri ↔ 引用的 resource/memory/skill URI

5. 更新 active_count
   └── 所有本轮使用的 context URI → increment active_count

6. 记录统计
   └── total_turns, contexts_used, skills_used, memories_extracted
```

---

## §9 Retrieval 与 Prompt Assembly

### 9.1 检索链路（对齐 OpenViking IntentAnalyzer + HierarchicalRetriever）

```
1. IntentAnalyzer
   ├── 输入: 当前消息 + 最近会话上下文
   ├── 判断任务类型: 操作型(skill+resource+memory) / 信息型(resource+memory) / 对话型(无需检索)
   ├── 输出: List<TypedQuery> — 每条含 query, contextType(SKILL/RESOURCE/MEMORY), intent, priority
   └── 上下文覆盖检查: 已有 context 足够则跳过

2. 并发召回（按 TypedQuery 分发）
   ├── SkillResolver: tenant + shared + agent overlay → 请求级解析
   ├── ResourceRetriever: pgvector 语义搜索 + 层级递归 (L0→子节点)
   ├── MemoryRetriever: pgvector + hotness 加权
   │   final_score = (1 - 0.2) × semantic_score + 0.2 × hotness
   │   hotness = sigmoid(log1p(active_count)) × exp(-decay × age_days)
   │   half_life = 7 天
   └── SessionContextRetriever: 当前会话最近消息

3. 过滤·排序·去重
   ├── 空间+可见性过滤 (tenantId, userId, sessionId, allowedSpaces)
   ├── 同来源去重
   ├── 预算裁切 (每类 token 配额)
   └── 证据保留 (来源标识, 类型, 更新时间)

4. ContextAssembler → PromptBuilder → 模型调用
   ├── 按 section 组装 (system_prompt, skills, memories, resources, session_context)
   ├── 使用模板文件 + <variable_name> 占位
   └── 控制 section 可选性与顺序
```

### 9.2 层级递归检索（Day 1 落地，SPI 可热替换）

> **核心原则**：接口 Day 1 稳定，实现可替换。不做"先简单后推翻"。

**稳定接口集**（不允许破坏性变更）：

| 接口 | 职责 | 扩展方式 |
|------|------|---------|
| `HierarchicalRetriever` | 唯一公共检索入口 | 永不变 |
| `ChildSearchStrategy` | 子节点发现 + 全局搜索 | Day1=keyword → Day2=pgvector |
| `HotnessScorer` | 热度计算 | 参数可配置 |
| `ContextNode` | 通用节点抽象（record） | 只加字段不删 |

**算法（对齐 OpenViking HierarchicalRetriever）**：

```
初始化: 根节点 + globalSearch() top-3 → 合并为起始点（优先队列）
循环:
  弹出得分最高的非终端节点
  调用 ChildSearchStrategy.searchChildren(parent_uri, query)
  得分传播: child_score = 0.5 × child_raw + 0.5 × parent_score
  L0/L1 节点 → 加入队列继续递归
  L2 节点 → 收集为最终候选
  收敛检测: 连续 3 轮 top-k URI 集合不变 → 提前终止
返回: HotnessScorer 加权 → 按 final_score 降序取 top-limit
```

**ChildSearchStrategy 实现路径**：

| 阶段 | 实现 | 接口变更 |
|------|------|---------|
| Day 1 | `DbChildSearchStrategy` — SQL `parent_uri` + keyword `LIKE` | 无 |
| Day 2 | `VectorChildSearchStrategy` — pgvector `embedding <=> query_vec` | 无 |
| Future | `CompositeChildSearchStrategy` — vector + keyword 融合 | 无 |
| Future | `FileChildSearchStrategy` — Files.list() 映射为 ContextNode | 无 |

### 9.3 AI Memory Tool Set（渐进披露通道）

> **核心理念**：AI 不浏览文件树，而是通过 3 个语义化 Tool 按需获取记忆。

```java
@Tool("浏览用户记忆分类概览。返回8类记忆的数量和一句话摘要(L0)。对话开始时调用。")
MemoryCategoryOverview browseMemoryCategories()
// → {PROFILE: {count:3, abstract:"全栈开发者，偏好中文..."}, ...}
// Token: ~200 tok | 等价: 一次读完所有 .abstract.md

@Tool("语义搜索相关记忆。返回匹配记忆的L0/L1摘要列表。需要查找话题相关记忆时使用。")
List<MemorySummary> searchMemories(String query, @Nullable MemoryType type)
// → pgvector 向量搜索 + hotness 排序 → top-5
// Token: ~300 tok | 等价: 跨分类语义匹配（文件系统做不到）

@Tool("获取单条记忆完整详情(L2)，含全部内容和来源引用。确认需要时调用。")
MemoryDetail getMemoryDetail(Long memoryId)
// → 完整 content + evidence refs
// Token: ~500-2000 tok | 等价: 读取完整文件
```

**渐进披露示例流程**：
```
User: "帮我review一下这段Spring Boot代码"

→ AI 调用 browseMemoryCategories()   ← L0 全景 (~200 tok)
← PREFERENCE: "编码风格: 极简, 函数式, Optional..."
← ENTITY: "项目: PocketMind(SB4), MediaCrawler(Py)..."

→ AI 调用 searchMemories("代码审查 编码风格", PREFERENCE)  ← L1 定向搜索 (~300 tok)
← [{id:12, title:"编码风格", summary:"偏好不可变对象, 禁止null..."}]

→ AI 调用 getMemoryDetail(12)  ← L2 按需加载 (~800 tok)
← {完整preference规则 + 来源对话引用}

AI: "根据你的编码偏好，这段代码有3个问题..." ← 总共3次tool call, ~1300 tok
```

**对比文件浏览**：同样结果需要 `ls`+`cat`×8 ≈ 24次tool call, ~7000 tok, 延迟40s+。

### 9.4 为什么不用文件系统存储记忆（架构决策记录）

| 维度 | 文件系统 | DB + Tool Bridge |
|------|---------|-----------------|
| 发现效率 | 24+ tool call 浏览 | 1次向量搜索 |
| Token开销 | ~7000 tok/轮 | ~1300 tok/轮 |
| 跨分类语义匹配 | 不可能（按目录分类） | pgvector 天然支持 |
| 并发安全 | 文件锁/partial read | MVCC 原生 |
| 移动端展示 | 需额外同步到DB | 直接查询 |
| >100条规模 | 扫描不现实 | 索引毫秒级 |
| 适用对象 | Skills(少量、静态) | Memories/Resources(动态、大量) |

---

## §10 数据边界

### 真相源（不可替代）

| 对象 | 真相内容 | 派生层 |
|------|---------|--------|
| Note | 标题、正文、来源URL、标签 | Resource, Memory candidates |
| ChatSession/Message | 会话元数据、消息文本、时序 | transcript resource, 阶段摘要, memory candidates |
| Asset | 二进制文件、元数据 | OCR文本, 解析文本, 可检索chunk |

### 派生对象（可从真相源重建）

`ResourceRecord`, `ContextRef`, `MemoryRecord`, 检索索引, 向量条目, prompt 片段 — 都不能替代主业务对象。

### 判断规则

1. 用户直接编辑？→ 业务对象
2. 从别处抽取/摘要？→ 派生对象
3. 主要为 AI 检索服务？→ Context 对象
4. 删后可从他处重建？→ 多半不是真相源

---

## §11 存储与索引策略

### 存储分界线（架构决策）

| 对象类型 | 存储位置 | 原因 |
|----------|---------|------|
| **Skills** | **文件系统 (.md)** | 少量(5-50)、静态、人工编写、AI 直接读取、已经 work | 
| **Memories** | **PostgreSQL + pgvector** | 动态(100-10000)、AI提取、需向量搜索、移动端可见、并发写 |
| **Resources** | **PostgreSQL + pgvector** | 业务投影、需关联查询、移动端 API |
| **业务对象** | **PostgreSQL** | 产品真相源，不变 |
| **二进制资产** | **AssetStore(文件/S3)** | 已实现 |

### 为什么 Skills 用文件、Memories 用 DB

| 属性 | Skills → 文件 | Memories → DB |
|------|-------------|-------------|
| 数量级 | 5-50 | 100-10,000 |
| 变更频率 | 部署时 | 每次会话 commit |
| 作者 | 人类编写 | AI 提取 |
| 搜索方式 | 枚举/名称 | 语义向量 |
| 用户可见 | 否(AI专用) | 是(移动端展示) |
| 并发写 | 不存在 | session commit 并发 |
| 租户隔离 | 目录分离 | SQL WHERE |

### DB 表结构

| 表 | 职责 | 关键列 |
|-----|------|--------|
| `resource_records` | 投影材料 | abstract_text(L0), summary_text(L1), normalized_text(L2), embedding vector(1536) |
| `memory_records` | 长期记忆 | abstract(L0), summary(L1), normalized_content(L2), embedding vector(1536), active_count, memory_type |
| `context_catalog` | 层级目录（检索用） | uri, parent_uri, layer, abstract_text, embedding, active_count, is_leaf |
| `context_ref` | 关联关系 | source_uri, target_uri, ref_type |

---

## §12 包结构

```
com.doublez.pocketmindserver/
├── note/            # 产品业务域
├── chat/            # 产品业务域
├── asset/           # 产品业务域
├── resource/        # 投影与材料域
│   ├── domain/
│   ├── repository/
│   └── application/ # ResourceProjectionService, ResourceSyncService
├── memory/          # 长期知识域
│   ├── domain/
│   ├── repository/
│   └── application/ # MemoryExtractor, MemoryDeduplicator, MemoryMergeService
├── skill/           # 能力定义域 (文件系统)
├── context/         # 共享标识域
│   ├── domain/      # ContextType, ContextLayer, ContextUri, ContextRef, SpaceType, ContextNode
│   ├── repository/  # ContextCatalogRepository (layer hierarchy for retrieval)
│   └── infra/       # MybatisContextCatalogRepository, ContextCatalogMapper
├── ai/
│   ├── application/
│   │   ├── context/    # ContextAssembler
│   │   ├── retrieval/  # HierarchicalRetriever(SPI), ChildSearchStrategy(SPI), HotnessScorer
│   │   │              # DefaultHierarchicalRetriever, DbChildSearchStrategy, DefaultHotnessScorer
│   │   ├── memory/     # MemoryQueryService (检索侧)
│   │   └── stream/     # SSE 输出
│   ├── tool/
│   │   ├── skill/      # MultiTenantSkillsToolFactory, TenantSkillToolResolver (已有)
│   │   └── memory/     # MemoryToolSet (新增: browseCategories/searchMemories/getDetail)
│   └── config/         # AiConfiguration, AiToolsConfiguration
└── prompts/           # src/main/resources/prompts/{domain}/{scene}.st
    ├── compression/   # memory_extraction, dedup_decision, memory_merge, structured_summary
    ├── retrieval/     # intent_analysis
    └── semantic/      # document_summary, file_summary, overview_generation
```

---

## §13 分阶段实施总策略

| Phase | 目标 | 关键产出 | 前置依赖 |
|-------|------|----------|----------|
| 0 纠偏清障 | 删除错误设计、确认真相源 | ✅已完成 | — |
| 1 骨架标识 | ContextType/Layer/Uri/Ref + SpaceType | ✅已完成(SpaceType 待落地) | Phase 0 |
| 2 检索基建 + Resource 闭环 | **HierarchicalRetriever SPI + ContextNode + ContextCatalog**，多来源 Resource 接入 | HierarchicalRetriever接口, DbChildSearchStrategy, DefaultHotnessScorer, ContextCatalog表 | Phase 1 |
| 3 Session commit | 阶段提交 + transcript + summary | SessionCommitService | Phase 2 |
| 4 User Memory + Memory Tool Set | 4类 user memory + **AI渐进披露工具** | MemoryExtractor + Dedup + **MemoryToolSet(3个Tool)** | Phase 3 |
| 5 Retrieval 双通道 | 服务端预注入 + AI主动发现 | IntentAnalyzer + ContextAssembler升级 + pgvector | Phase 4 |
| 6 Skill 稳定化 | 描述模型 + 缓存 + 版本化 | SkillDescriptor | Phase 5 |
| 7 Agent Memory | CASE/PATTERN/TOOL_EXPERIENCE | AgentMemory domain | Phase 5 |
| 8 检索升级 | **VectorChildSearchStrategy** + chunk化 + rerank | 替换 DbChildSearchStrategy，接口不变 | Phase 5 |
| 9 服务化准备 | 接口契约 + 事件模型 | Context Service API | Phase 8 |

**Phase 2 提前落地检索基建的原因**：
- `HierarchicalRetriever` 接口 Day 1 稳定，后续 Phase 5/8 只换实现不改接口
- `ContextNode` + `ContextCatalog` 是 Phase 3-5 的基础依赖
- Day 1 用简单 SQL keyword 实现，即使没有 pgvector 也能工作

**禁止顺序错乱**：没有 Resource 闭环时不做复杂 Memory 表；没有 commit 语义时不做长期记忆合并；没有正式 Retrieval 时不继续把聊天拼装做大。

---

## §14 执行模板

当用户要求新增/改造上下文能力时，按此模板输出：

```
1. 归类需求 → 属于哪一层
2. 确定真相源 → 列出受影响对象
3. 判断阶段 → 是否在当前阶段范围
4. 最小改动 → 只改本阶段必要代码，明确不做什么
5. 验证 → 编译 + 单测 + 启动
6. 输出 → 改动文件、结果、风险、下一步
```

---

## §15 通过标准

本 Skill 指导的方案必须同时满足：

- [ ] 业务主模型与上下文模型边界明确
- [ ] 每类数据的真相源清晰
- [ ] USER/SESSION/TENANT/AGENT/SYSTEM 空间隔离
- [ ] `session.commit()` 角色明确
- [ ] Resource / Memory / Skill 职责不混淆
- [ ] Retrieval 成为正式链路
- [ ] L0/L1/L2 = Abstract/Overview/Detail（禁止反转）
- [ ] 存储分界线清晰：Skills=文件、Memories/Resources=DB+pgvector
- [ ] 双通道检索：服务端预注入 + AI Tool Bridge 渐进披露
- [ ] HierarchicalRetriever 接口 Day 1 落地，后续只换实现
- [ ] Memory Tool Set (3个Tool) 提供渐进式上下文发现
- [ ] 迁移顺序与兼容期策略明确
- [ ] 每阶段编译+测试+启动通过

缺少任一核心项，方案视为不完整。
