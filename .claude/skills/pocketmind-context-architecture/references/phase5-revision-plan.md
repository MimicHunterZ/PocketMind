# Phase 5 修订计划 — 检索编排层重构

> **状态**: 执行完毕（除阶段 B 记忆注入重构延后）  
> **日期**: 2026-03-12  
> **触发**: 用户反馈当前 Phase 5 实现存在过度设计、过渡手段、无效代码问题

---

## §1 问题诊断

### 1.1 当前实现的问题

| # | 问题 | 具体表现 | 应对 |
|---|------|---------|------|
| 1 | 规则引擎替代了 LLM | `RuleBasedIntentAnalyzer` 用停用词+正则做意图分析 | 直接用 LLM 做意图分类 |
| 2 | 注释含过渡痕迹 | `Phase 5 默认实现`、`适合 Day1 使用`、`Phase 8 将切换` | 清理所有此类注释 |
| 3 | 无效 token 估算 | `ContextSnippet.estimateTokens()` 用 `chars * 1.5` 粗算 | 删除，后续实现精确 token 计数 |
| 4 | 关键词检索替代向量检索 | `KeywordMemoryRetriever` 用 SQL LIKE 模糊匹配 | 用户记忆量小，直接全量注入 |
| 5 | token budget 截断无意义 | `RetrievalOrchestrator.applyTokenBudget()` 基于错误的 token 估算 | 删除截断逻辑，后续引入精确统计 |

### 1.2 核心认知修正

1. **用户记忆不会很多**：PocketMind 是个人第二大脑，单用户 memory 量级在 10-200 条。L0 abstract 每条约 100 token，200 条 = 20k token，完全可以一口气注入（现代模型 128k 上下文窗口）。
2. **不需要过渡手段**：规则引擎→LLM 引擎是错误的渐进路径。LLM 意图分类本身成本低（单次 <500 token），延迟可接受。
3. **OpenViking 的做法**：
   - 意图分析 = LLM 直出 `List<TypedQuery>`，按 skill/resource/memory 三类生成检索查询
   - 记忆检索 = 取 top-3 memory via pgvector，L0 abstract 注入 system prompt
   - 记忆注入 = context.py 中直接 `get_viking_memory_context()` → 格式化注入
   - 无规则引擎、无 token 粗算

---

## §2 OpenViking / OpenClaw 架构参考

### 2.1 OpenViking 记忆注入模式

```python
# bot/vikingbot/agent/context.py — 系统提示词构建
async def build_system_prompt(session_key, message, history):
    # 1. 获取用户画像 (PROFILE 类 memory)
    profile = await memory.get_viking_user_profile(workspace_id, user_id)
    # → "## Current user's information\n{profile}"

    # 2. 获取相关记忆 (向量检索 top-3)
    viking_memory = await memory.get_viking_memory_context(message, workspace_id)
    # → "## Your memories. Using tools to read more details.\n{formatted}"

    # 3. 组装: identity + env + profile + memories + skills摘要
```

**OpenViking 记忆格式**:
```
1. {abstract}; uri: {uri}; isDir: {is_leaf}; related score: {score}
2. ...
```

核心特征：
- **Profile 单独处理**：始终注入，不走检索
- **其他记忆走向量 top-N**：limit=3，只注入 L0 abstract
- **双通道配合**：system prompt 注入 L0 + MemoryTool 按需获取 L2

### 2.2 OpenViking 意图分析模式

```yaml
# retrieval/intent_analysis.yaml
# LLM 直接分类，不用规则引擎
# 输入: session_summary + recent_messages + current_message
# 输出: {reasoning, queries: [{query, context_type, intent, priority}]}
#
# 三类查询风格:
#   skill → 动词开头 ("创建RFC文档")
#   resource → 名词短语 ("RFC文档标准模板")
#   memory → "用户XX偏好格式" / "执行XX的经验"
#
# 三类任务:
#   操作型 → skill + resource + memory
#   信息型 → resource + memory
#   对话型 → 无需检索
```

OpenClaw 的记忆系统设计颠覆了传统 AI Agent 依赖庞大云端向量数据库的范式。从底层架构来看，它采用的是“文件即源头 (File-first) + 本地轻量级 RAG + 上下文自动压缩”的混合架构。以下自底向上对其记忆系统进行深度解构。

### 一、 存储基座：Markdown 即 Source of Truth
OpenClaw 摒弃将记忆封装在黑盒数据库中的做法，所有持久化记忆均以纯文本 (Markdown) 形式直接写在本地磁盘的 Agent Workspace（通常位于 <~/.openclaw/workspace/>）。模型只能“记住”落盘的内容，保证了极高的数据透明度与可干预性。

核心文件分层模型：
1. **身份与规则层 (Identity Files)**：每次 Session 启动时全量注入 System Prompt。
   - `SOUL.md`：核心人格、能力边界、核心价值观（Core Truths）。这是 Agent 的“控制面”，决定了底层的行为逻辑。
   - `USER.md`：用户的画像、风险偏好与工作契约。
   - `AGENTS.md`：当前 Workspace 的标准操作程序 (SOP)。
2. **流式工作记忆层 (Ephemeral/Daily Memory)**：
   - `memory/YYYY-MM-DD.md`：每日自动生成的 Append-only 日志，记录运行上下文、决策树和流水。Session 启动时默认加载“今天+昨天”的日志，提供时间窗口上下文。
3. **长期固化记忆层 (Long-term Memory)**：
   - `MEMORY.md`：经过沉淀和高度浓缩的长期记忆（如项目规范）。为保证安全边界，仅在 Private Main Session 中加载，严格隔离于群组上下文。



### 二、 检索层：基于 SQLite + sqlite-vec 的本地自闭环 RAG
当记忆文件膨胀后，OpenClaw 通过 `memory-core` 插件在本地构建了一个极轻量级的混合检索系统，避免了长上下文带来的 Token 损耗。

1. **底层引擎**：摒弃复杂的分布式向量库，直接基于本地 SQLite。环境支持时，通过 sqlite-vec 扩展实现高性能的 C 级二进制向量计算。
2. **数据表结构**：
   - `files` 表：跟踪文件修改时间 (mtime) 和哈希，避免未变动文件被重复计算 Embedding。
   - `chunks` 表：Markdown 文本分块（Target 约 400 token，Overlap 80 token），保存起始行范围。
   - `chunks_vec` 虚拟表：存储序列化的 Float Vector，支撑相似度计算。
3. **混合检索 (Hybrid Search)**：执行 memory_search 工具时，采用 Union（并集）而非 Intersection（交集）逻辑：
   finalScore = vectorWeight * vectorScore + textWeight * textScore
   即语义向量和关键词命中任意其一即可被召回，以此确保高召回率。

### 三、 运行时状态机：Context Compaction 与记忆落盘机制
在长周期的 Session（基于 .jsonl 持久化转录）中，LLM 的 Context Window 必然触顶。OpenClaw 的内存防丢失管理在此处展现了极其硬核的工程化设计。

1. **Context Compaction (上下文压缩)**：
   当 Token 逼近模型极限时，系统触发 Compaction 机制，将旧的会话历史总结为一个极其精简的 summary node，替换掉原始记录，仅保留最近约 20,000 Token 的原始消息结构。
2. **Pre-compaction Memory Flush (压缩前记忆落盘 - 核心防御机制)**：
   在系统执行不可逆的 Compaction 抹除细节之前，自动触发一个静默的 Agentic Turn。
   - 内部注入强提示指令（如：<Pre-compaction memory flush. Store durable memories now... 必须追加而非覆盖>）。
   - 强制 Agent 审视即将被压缩的上下文，将其中的关键事实、决策路径提取出来，调用写工具 Append 到当天的 `memory/YYYY-MM-DD.md` 中。
   - 机制本质：在状态销毁前，用一次短期的推理算力开销，换取长期状态的持久化安全。



### 架构沉淀总结
OpenClaw 记忆系统用最朴素的 Markdown 文件解决了数据主权问题，用本地 SQLite 解决了检索效率问题，用 Pre-compaction Flush 解决了长上下文遗忘问题。工程复杂度被完全收敛在了极简的文件接口之下，是一种高内聚、低耦合的绝佳实践。

### 2.4 PocketMind 记忆架构设计

#### 2.4.1 核心设计原则

综合 OpenViking (服务端向量检索) 和 OpenClaw (客户端 Markdown 文件)，PocketMind 作为多用户 C/S 架构需要解决一个关键矛盾：

- **OpenClaw 是单用户本地工具**：记忆直接写磁盘，SQLite 本地索引。无服务端。
- **OpenViking 是多用户服务**：记忆存 PostgreSQL + pgvector，服务端全权管理。
- **PocketMind 的独特性**：多用户 C/S，但希望保留 OpenClaw "文件可见、可编辑" 的数据主权体验。

#### 2.4.2 分层记忆模型

借鉴 OpenClaw 的三层文件分层，适配为 PocketMind 的数据库 + 客户端双栈模型：

| 层级 | OpenClaw 对应 | PocketMind 实现 | 注入时机 |
|------|-------------|----------------|---------|
| **身份层** | `SOUL.md` / `USER.md` | `memory_records` WHERE type=PROFILE | 每次对话启动时全量注入 |
| **工作记忆层** | `memory/YYYY-MM-DD.md` | 对话结构化摘要（`structured_summary`）| 加载最近 N 条对话摘要 |
| **长期记忆层** | `MEMORY.md` | `memory_records` 其他类型（PREFERENCES, ENTITIES, EVENTS 等）| 全量 L0 abstract 注入 |

**为什么不用 Markdown 文件？**

PocketMind 是多用户移动端应用，不是开发者本地工具：
1. **多设备同步**：用户可能在手机和平板同时使用，文件同步引入冲突。数据库天然解决一致性。
2. **用户无需直接编辑记忆文件**：移动端用户不会打开 Markdown 编辑器改记忆。UI 提供增删改查足够。
3. **安全隔离**：多用户场景下，数据库行级权限远优于文件系统隔离。
4. **已有基础设施**：`memory_records` 表 + `MemoryType` 枚举已就位。

**但借鉴 OpenClaw 的理念**：
- **记忆可导出为 Markdown**：提供「导出我的记忆」功能，生成 OpenClaw 风格的 `MEMORY.md`。
- **透明可审查**：移动端提供记忆浏览 UI，用户能看到 AI 记住了什么。
- **Pre-compaction Memory Flush**：对话 token 逼近上限时，自动触发记忆落盘。

#### 2.4.3 记忆注入策略

```
请求到达:
  ├─ 1. 全量注入用户记忆 L0 (abstract)
  │    量级: 10-200条 × ~100 tok = 1k-20k tok
  │    方式: 查询 memory_records WHERE user_id = ? AND is_deleted = false
  │    格式: "## 用户记忆\n- [{type}] {abstract}\n- ..."
  │    条件: 始终注入（PROFILE 优先置顶）
  │
  ├─ 2. LLM 意图分析 → 资源检索查询
  │    输入: 当前消息
  │    输出: List<TypedQuery> (resource/memory 两类)
  │    条件: 全局对话时触发
  │
  ├─ 3. 双通道并行检索
  │    ├─ resource 查询 → HierarchicalRetriever → Resource L1 摘要
  │    └─ memory 查询(可选) → MemoryRetriever → 特定记忆 L2 详情
  │
  └─ 4. ContextAssembler 组装
       system_prompt + 全量记忆L0 + 资源摘要 + 特定记忆L2 + 笔记上下文
```

**与纯全量注入的区别**：
- L0 abstract 始终全量注入（提供全局 awareness）
- LLM 意图分析可产生 `memory` 类型查询 → 触发特定记忆的 L2 (content) 加载
- 这样 AI 同时具备"全局扫描 (L0)" + "按需深入 (L2)" 的能力

#### 2.4.4 Memory Tool 与客户端协作

**当前架构（服务端主导）**：
```
Client → HTTP → Server(MemoryToolSet) → DB → Response
```

**未来演进方向（MCP 资源协议）**：

当客户端本地存储发展成熟后，可引入 MCP 资源请求协议实现"服务端透明代理"：

```
1. LLM 触发 Memory Tool → 生成 MCP 资源请求
2. Server 将请求转化为标准 MCP resource URI:
   read_resource: pm://users/{userId}/memories/{memoryId}
3. 通过 SSE/WebSocket 长连接下发到 Client
4. Client 本地 Isar 数据库查询 → 流式回传到 Server
5. Server 将内容注入 Context Window
```

这一模式的优势：
- **数据主权**：敏感记忆可仅存在客户端，服务端只做转发
- **离线能力**：客户端有完整记忆副本，离线时可本地推理
- **带宽优化**：仅传输 LLM 需要的特定记忆，非全量同步

**但这是后续阶段的事**。当前阶段保持服务端 DB 作为 Source of Truth，原因是：
1. 移动端 Isar 与服务端 PostgreSQL 的双写一致性尚未建立
2. MCP 协议的客户端实现需要 Flutter 侧配合
3. 当前记忆量级不需要这种优化

#### 2.4.5 与 OpenClaw 每日 MD 文件的对应

OpenClaw 的 `memory/YYYY-MM-DD.md` 日志在 PocketMind 中对应为**对话结构化摘要**：

| OpenClaw | PocketMind |
|----------|-----------|
| `memory/2026-03-12.md` | `structured_summary` of sessions on that day |
| Append-only 日志 | 对话结束后压缩生成 |
| Session 启动加载今天+昨天 | 全局对话可加载最近 N 条摘要 |

不需要单独的"每日 Markdown 文件"实体，对话结构化摘要已经承载了这个职责。

#### 2.4.6 记忆量级扩展策略

| 记忆量级 | 策略 | 注入成本 |
|---------|------|---------|
| < 50 条 | 全量 L0 注入 | ~5k tok |
| 50-200 条 | 全量 L0 注入 + LLM 选择性 L2 | ~20k tok |
| 200-500 条 | PROFILE 全量 + 其他 top-N L0 (by relevance) | 需引入 pgvector |
| 500+ 条 | 完全走向量检索 top-N | 回到 OpenViking 模式 |

当前实现面向 <200 条场景。扩展到 >200 时再引入 pgvector 记忆检索。

---

## §3 修订任务清单

### 阶段 A: 清理（不改功能，只删无效代码）

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| A1 | 删除 `estimateTokens()` | `ContextSnippet.java` | 粗算无意义 |
| A2 | 删除 `applyTokenBudget()` / `truncateByTokens()` | `RetrievalOrchestrator.java` | 基于粗算的截断 |
| A3 | 删除 `totalTokenEstimate` 字段 | `OrchestratedContext.java` | 与 A2 配套 |
| A4 | 删除 `KeywordMemoryRetriever` | `KeywordMemoryRetriever.java` | 记忆改为全量注入 |
| A5 | 删除 `MemoryRetriever` 接口 | `MemoryRetriever.java` | 与 A4 配套 |
| A6 | 删除 `RuleBasedIntentAnalyzer` | `RuleBasedIntentAnalyzer.java` | 被 LLM 实现替换 |
| A7 | 清理所有注释中的 `Phase X`、`Day 1`、`Day1`、`Day 2` 等过渡痕迹 | 全项目搜索 | 见 §4 |
| A8 | 删除对应的单元测试 | `RuleBasedIntentAnalyzerTest.java` | 与 A6 配套 |
| A9 | 更新 `RetrievalOrchestratorTest` | 适配新逻辑 | 删除 token 相关测试 |

### 阶段 B: 记忆全量注入

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| B1 | 新建 `MemoryInjector` | `ai/application/retrieval/MemoryInjector.java` | 查询用户全量 L0 memory，格式化为 system prompt section |
| B2 | 新建 `prompts/chat/context/memory_all_section.md` | 模板 | `## 用户记忆\n\n以下是用户的长期记忆摘要，可通过 Memory 工具获取详情。\n\n<memories>` |
| B3 | 新建 `prompts/chat/context/memory_all_item.md` | 模板 | `- [<memoryType>] <abstract>` |
| B4 | 修改 `ContextAssembler` | 全局路径注入全量记忆 | 调用 `MemoryInjector` 替代 `RetrievalOrchestrator.retrieveMemories()` |
| B5 | 单元测试 | `MemoryInjectorTest.java` | 验证全量注入格式正确 |

### 阶段 C: LLM 意图分析

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| C1 | 新建 `prompts/retrieval/intent_analysis_system.md` | 提示词模板 | 参考 OpenViking 的 `intent_analysis.yaml`，适配 PocketMind 的 resource/memory 两类（PocketMind 无 skill 检索需求） |
| C2 | 新建 `prompts/retrieval/intent_analysis_user.md` | 提示词模板 | `当前消息：<currentMessage>\n最近对话：<recentMessages>` |
| C3 | 新建 `LlmIntentAnalyzer` | `ai/application/retrieval/LlmIntentAnalyzer.java` | 调用 AiFailoverRouter，解析 JSON 输出为 `AnalyzedIntent` |
| C4 | 修改 `AnalyzedIntent` | 扩展字段 | 增加 `List<TypedQuery> queries` 替代简单 keywords |
| C5 | 新建 `TypedQuery` record | `ai/application/retrieval/TypedQuery.java` | `(query, contextType, intent, priority)` |
| C6 | 修改 `RetrievalOrchestrator` | 重构检索流程 | 接收 `AnalyzedIntent` 的资源查询 → HierarchicalRetriever |
| C7 | 修改 `ContextAssembler` | 更新调用链 | 先注入全量记忆，再根据意图分析结果检索资源 |
| C8 | 单元测试 | `LlmIntentAnalyzerTest.java` | Mock LLM 返回验证解析 |

### 阶段 D: 提示词优化（参考 OpenViking）

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| D1 | 优化 `global_system.md` | 主系统提示词 | 参考 OpenViking context.py 的身份定义、能力声明、约束 |
| D2 | 优化 `note_system.md` | 笔记系统提示词 | 增加笔记操作指引 |
| D3 | 优化 `memory_section.md` | 记忆注入容器 | 参考 OpenViking 的 "Your memories" 格式 |
| D4 | 优化 `structured_summary_system.md` | 结构化摘要 | 对齐 OpenViking 的 `structured_summary.yaml` 格式规范 |
| D5 | 优化 `memory_extraction_system.md` | 记忆抽取 | 对齐 OpenViking 的三层输出结构和 per-category 规则 |
| D6 | 优化 `vision/system_prompt.md` | 视觉理解 | 参考 OpenViking 的 `image_understanding.yaml` |

### 阶段 E: Demo 隔离

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| E1 | `application-dev.yml` 中 `pocketmind.demo.enabled` 改为 `false` | 配置文件 | 默认不加载 demo |
| E2 | 确认 `@ConditionalOnProperty` 生效 | 启动验证 | 启动时不应出现 `[skill-demo]` 日志 |

### 阶段 F: 后续任务（记入 progress.json，本轮不实现）

| # | 任务 | 说明 |
|---|------|------|
| F1 | 精确 token 计数 | 引入 tiktoken 或 Spring AI 内置 token counter |
| F2 | Token 预算管理 | 基于精确 token 数的预算分配和截断 |
| F3 | pgvector 资源检索 | `VectorChildSearchStrategy` 替换 `DbChildSearchStrategy` |
| F4 | pgvector 记忆语义去重 | `MemoryDeduplicator` 向量预过滤 |

---

## §4 注释清理范围

搜索并清理以下模式的注释：

```
Phase 5 / Phase 8 / Phase N
Day 1 / Day1 / Day 2 / Day2
适合 Day1 使用
后续 Phase X 将...
Phase X 默认实现
Phase 8 将通过 @ConditionalOnProperty 切换
```

替换原则：
- 直接描述功能和职责，不提阶段号
- 不预告"未来将如何"，只描述当前实现

---

## §5 文件变更影响分析

### 将删除的文件（阶段 A）
- `RuleBasedIntentAnalyzer.java`
- `RuleBasedIntentAnalyzerTest.java`
- `KeywordMemoryRetriever.java`
- `MemoryRetriever.java`（接口）

### 将新建的文件（阶段 B+C）
- `MemoryInjector.java`
- `LlmIntentAnalyzer.java`
- `TypedQuery.java`
- `prompts/retrieval/intent_analysis_system.md`
- `prompts/retrieval/intent_analysis_user.md`
- `prompts/chat/context/memory_all_section.md`
- `prompts/chat/context/memory_all_item.md`
- `MemoryInjectorTest.java`
- `LlmIntentAnalyzerTest.java`

### 将修改的文件（阶段 B+C+D+E）
- `ContextSnippet.java` — 删除 `estimateTokens()`
- `OrchestratedContext.java` — 删除 `totalTokenEstimate`
- `RetrievalOrchestrator.java` — 重构：不再管理记忆通道，只做资源检索
- `ContextAssembler.java` — 重构调用链
- `RetrievalOrchestratorTest.java` — 删除 token 相关测试，适配新逻辑
- `AnalyzedIntent.java` — 扩展 queries 字段
- `IntentAnalyzer.java` — 接口签名可能调整
- `global_system.md` 等提示词文件
- `application-dev.yml` — demo.enabled → false

### 受影响的已有测试
- `AiChatServicePauseTest.java` — ContextAssembler 构造函数变更
- `AiChatServiceTest.java` — 同上
- `RetrievalOrchestratorTest.java` — 重写

---

## §6 风险与约束

1. **LLM 意图分析增加延迟**：约 0.5-1s（单次轻量 LLM 调用）。对话型任务可跳过。
2. **全量记忆注入的上限**：200 条 × 100 tok = 20k tok。如果用户记忆量增长到 500+，需要回到"检索 + 注入 top-N"模式。
3. **Demo 禁用后影响**：开发人员需要手动在本地 yml 中打开 `pocketmind.demo.enabled=true` 才能使用 demo 功能。考虑新增 `application-demo.yml` profile 做完全隔离。
