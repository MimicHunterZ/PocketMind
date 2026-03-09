# PocketMind Context Architecture PRD

## 1. 文档目标

本 PRD 用于定义 PocketMind 上下文架构产品化建设的目标、范围、角色、能力、约束与验收标准。

它不是数据库设计说明，也不是单纯技术重构记录，而是回答以下问题：

- 为什么 PocketMind 需要长期记忆与统一上下文架构
- 这个架构最终要服务哪些真实用户价值
- 第一阶段到后续阶段应该交付什么能力
- 哪些能力属于用户记忆，哪些属于技能，哪些属于检索
- 如何保证移动端和现有产品流程不被破坏

---

## 2. 背景与问题

PocketMind 当前已具备：

- Note 作为知识记录主载体
- ChatSession / ChatMessage 作为 AI 对话载体
- Asset 作为附件与媒体载体
- Web 导入、分析、OCR 等内容来源

但 AI 上下文消费仍存在明显不足：

1. 上下文来源分散，缺乏统一抽象。
2. 聊天上下文组装仍然容易依赖业务字段直拼。
4. 系统缺少正式的 retrieval 流程，无法稳定区分短期上下文、长期记忆、技能能力。
5. 租户技能、多会话沉淀、用户偏好学习、跨来源知识汇聚尚未形成统一体系。

因此，需要建立一套完整的 Context Architecture，以支撑 PocketMind 从“带 AI 的笔记应用”演进为“具备长期上下文能力的第二大脑系统”。

---

## 3. 产品目标

建立 PocketMind 的统一上下文架构，使系统能够：

- 从笔记、聊天、附件、网页导入等多种来源生成可消费资源
- 从资源和会话中沉淀用户长期记忆
- 在回答时根据任务意图检索最相关的资源、记忆和技能
- 在不破坏主业务模型的前提下提升个性化、连续性与任务完成质量


## 5. 核心用户价值

### 5.1 对终端用户

- 系统能逐步记住用户偏好、关注点和项目背景。
- 新对话能继承跨会话的个人上下文，而不是每次重头介绍。
- 笔记、聊天、网页导入、附件内容能形成统一知识底座。
- 回答更连续、更符合个人习惯、更少重复说明。

### 5.2 对组织/租户

- 可以为不同租户配置不同技能能力和提示规范。
- 可以沉淀组织级工作方法、模板、流程与约束。
- 不同租户之间的技能与上下文边界清晰。

### 5.3 对研发团队

- 明确主业务模型与 AI 上下文模型边界。
- 降低聊天服务的耦合度。
- 为后续扩展检索、记忆治理、服务化提供可控演进路径。

---

## 6. 用户故事

### 6.1 作为普通用户

我希望 AI 在后续对话中知道：

- 我偏好中文输出
- 我当前在做 PocketMind 架构重构
- 我通常更关注架构边界与演进计划

这样我就不必每次重复说明背景。

### 6.2 作为知识密集型用户

我希望从网页、PDF、截图和笔记导入的信息，都能成为可检索的上下文来源，而不是散落在不同功能里。

### 6.3 作为长期项目用户

我希望系统能记住我的长期项目、常见术语、关注主题和执行偏好，并在后续任务中自动使用这些背景。

### 6.4 作为租户管理员

我希望能为团队注入统一的技能能力、规范和工作模板，但这些内容不应污染个人记忆。

### 6.5 作为后端开发者

我希望新增上下文能力时，不需要继续在 `AiChatService` 中堆逻辑，而是调用清晰的检索和装配服务。

## 7.1 资源投影层

系统应能从多种业务来源生成统一的可检索资源：

- Note 正文 → NOTE_BODY Resource
- 会话 transcript → CHAT_TRANSCRIPT Resource
- 网页爬取 → WEB_CLIP Resource
- 附件解析 → OCR_TEXT / PDF_TEXT Resource

### 验收要点

- Resource 与业务对象双向可追溯（sourceBizId ↔ resourceId）
- Resource 含三层表达：L0(Abstract ~100tok) / L1(Overview ~2k tok) / L2(Detail 全文)
- Resource 不替代业务对象，删除后可从业务源重建
- Resource 同步链路稳定（含 hash 变更检测）

## 7.2 长期记忆层

系统应能沉淀至少一部分用户长期知识（对齐 OpenViking 8 类记忆分类）：

**用户空间 Memory**：
- PROFILE：身份特征、长期背景
- PREFERENCE：偏好、风格、习惯
- ENTITY：人物、组织、项目、术语
- EVENT：事件、决策、里程碑

**Agent 空间 Memory**（v2）：
- CASE：成功/失败案例
- PATTERN：可复用解决模式
- TOOL_EXPERIENCE：工具使用经验
- SKILL_EXECUTION：工作流执行策略

### 验收要点

- 记忆不是全文复制，是提炼结果
- 每条记忆必须有 evidence 关联来源
- 记忆支持去重、合并、失效（含 LLM 辅助去重决策）
- 每条记忆含三层表达：L0(abstract) / L1(content) / L2(detail + evidence)
- PROFILE 类始终合并；EVENT/CASE 类独立记录不合并

## 7.3 会话提交机制

系统应支持把一次对话按阶段沉淀，而不是无限增长上下文。


## 7.4 Retrieval 正式链路

系统应提供正式检索服务，而不是临时拼接。

### 验收要点

- 支持会话上下文召回
- 支持用户长期记忆召回
- 支持相关 Resource 召回
- 支持 Skill 解析与注入
- 支持预算控制和去重

## 7.5 多租户 Skill

系统应支持：

- shared skill
- tenant skill

### 验收要点

- Skill 请求级解析
- 不在全局单例中固化全部技能
- 不把 Skill 当成用户记忆

---

## 8. 功能范围分层（参考）

### 8.1 v1 必须具备

- Note / Chat / Web / Asset -> Resource
- Chat 阶段提交
- 用户长期记忆最小闭环
- Retrieval 服务最小版本
- Prompt 模板化装配
- 多租户 Skill 请求级解析

### 8.2 v1.5 建议具备

- Resource chunk 化
- 更细粒度 memory 分类
- memory evidence 单独建模
- recall rerank 机制
- memory 更新与合并治理

### 8.3 v2 可规划

- Agent memory
- 用户可见的记忆管理界面
- Context Service 服务化
- 复杂工作流与 playbook 记忆

---

## 9. 信息架构与对象边界

### 9.1 业务真相对象

- Note
- ChatSession
- ChatMessage
- Asset

### 9.2 上下文对象

- **ResourceRecord**：AI 可消费材料单元，从业务对象投影而来。含 sourceType、normalizedText、summaryText、abstractText、layer(L0/L1/L2)、hash、contextUri。
- **MemoryRecord**：长期知识单元，从 Resource 和 Session 中提炼。含 memoryType(PROFILE/PREFERENCE/ENTITY/EVENT/CASE/PATTERN/TOOL_EXPERIENCE/SKILL_EXECUTION)、spaceType、normalizedContent、summary、abstract、confidenceScore、evidenceRefs、mergeKey、activeCount。
- **ContextRef**：上下文关联记录，描述对象间引用关系。含 sourceUri、targetUri、refType。
- **SessionCommit**：会话阶段提交记录。含 sessionId、commitIndex、transcriptResourceId、summaryResourceId、memoriesExtracted、commitStats。
- **TypedQuery**（运行时对象）：检索意图分析结果。含 query、contextType(SKILL/RESOURCE/MEMORY)、intent、priority。

### 9.3 边界要求

- 业务对象由业务服务维护
- 上下文对象由上下文相关服务维护
- 上下文对象不能取代业务对象对外暴露

## 9.4 对象与空间归属规则

PocketMind 的空间模型统一为：`SYSTEM`、`TENANT`、`AGENT`、`USER`、`SESSION`。

其中：

- `SYSTEM` 用于平台内置共享能力
- `TENANT` 用于组织级共享能力
- `AGENT` 用于执行经验与 agent 覆盖能力
- `USER` 用于用户个人长期知识
- `SESSION` 用于一次会话或阶段性临时上下文

统一规则表如下：

| 对象 | 默认空间 | owner | 默认可见性 | 说明 |
| --- | --- | --- | --- | --- |
| Note | USER | userId | PRIVATE | 用户主内容真相源 |
| ChatSession | SESSION | userId | PRIVATE | 产品会话容器 |
| ChatMessage | SESSION | userId | PRIVATE | 产品消息真相源 |
| Asset | USER | userId | PRIVATE | 二进制真相源 |
| Resource（笔记/导入） | USER | userId | PRIVATE | 用户材料层 |
| Resource（会话阶段） | SESSION | userId | SESSION_ONLY | 会话阶段材料 |
| UserMemory | USER | userId | PRIVATE | 用户长期知识 |
| SharedSkill | SYSTEM | system | SYSTEM_SHARED | 平台共享技能 |
| TenantSkill | TENANT | tenantId | TENANT_SHARED | 组织共享技能 |
| AgentOverlaySkill | AGENT | agentKey | TENANT_SHARED 或更严 | Agent 覆盖能力 |
| AgentMemory | AGENT | agentKey | 按策略配置 | 执行经验知识 |

产品要求：

1. 没有空间与 owner 的对象，不允许进入正式 Retrieval。
2. `shared skill` 统一归类为 `SYSTEM` 空间，不再与租户共享概念混用。
3. 会话空间对象默认不直接进入用户长期记忆，必须经 commit 与提炼流程转换。

---

## 10. 典型用户流程

> AI 信息提取使用 prompt 模板（参考 OpenViking 的 compression/memory_extraction 模板）。
> 详见 `references/openviking-deep-analysis.md` §2 记忆生命周期管线。

### 10.1 新增笔记后形成上下文

1. 用户保存笔记（纯文本笔记或者网页爬取的笔记）
2. Note 仍作为主真相源保存
3. Resource 投影服务（`NoteResourceSyncService`）生成或更新 note resource（含 L0/L1/L2 三层）
4. 后台任务可进一步生成摘要和 memory candidates 
5. 后续聊天检索时可召回此资源或其衍生记忆

### 10.2 聊天后沉淀长期记忆

1. 用户进行多轮对话
2. ChatMessage 持久化
3. 会话达到某个提交边界
4. 生成阶段 transcript resource 和阶段 summary
5. 提取长期记忆候选
6. 合并/更新现有 memory
7. 后续新对话可检索这些 memory

## 11. 关键体验要求

### 11.1 连续性

系统在后续会话中应能体现用户长期背景，而不是每次归零。

### 11.2 可控性

系统不应在没有边界的情况下把所有历史内容都丢给模型。

### 11.3 可解释性

当系统引用了长期记忆或资源时，后续应具备回溯来源的能力。

### 11.4 稳定性

上下文增强不能显著破坏当前聊天响应稳定性与笔记主流程。

---

## 12. 数据与治理要求

### 12.1 数据最小化原则

长期记忆应尽量存提炼结果，而非原文大块复制。

### 12.2 来源追溯原则

所有 memory 都应有 evidence 关联来源。

### 12.3 隔离原则

- 用户记忆不能跨用户泄露
- 租户技能不能跨租户误注入
- 会话短期上下文不能默认进入全局记忆

### 12.4 可修正原则

未来应允许：

- 记忆更新
- 记忆失效
- 记忆人工纠错

---

## 13. 兼容性要求

### 13.1 移动端兼容

- `Note` 仍是移动端主读模型
- 兼容期内不应粗暴删除客户端依赖字段

### 13.2 后端兼容

- Controller 不直接感知上下文内部表设计
- 旧服务可逐步退化为兼容层


## 14. 质量属性要求

### 14.1 可维护性

上下文能力必须按层拆分，禁止继续向单一聊天服务集中逻辑。

### 14.2 可观测性

应能看到：

- 哪些资源被生成
- 哪些记忆被提取
- 哪些检索结果被召回
- 哪些会话完成了 commit

### 14.3 可扩展性

后续接入新的输入源时，不应重写整套架构。

### 14.4 可服务化

后续应能逐步抽离出独立的 Context Service，而不破坏业务主模型。

---

## 15. 功能验收标准

### 15.1 Resource 验收

- 多来源可生成 Resource
- Resource 与业务对象双向可追溯
- Resource 同步链路稳定

### 15.2 Memory 验收

- 至少一种长期记忆类型可闭环
- memory 可被检索
- memory 可回溯 evidence

### 15.3 Retrieval 验收

- 聊天链路通过正式 retrieval service 获取上下文
- 上下文预算可控
- 注入不依赖业务字段硬编码拼接

### 15.4 Skill 验收

- 多租户技能解析正确
- 分析链路不误注入技能
- 技能与用户记忆边界清楚

---

## 16. 技术实施约束

- 遵守现有 Spring Boot 分层规范
- Controller 只依赖 Service 接口
- Repository 层屏蔽 MyBatis-Plus 细节
- Prompt 使用模板文件与 `PromptBuilder`
- 动态变量统一使用 `<variable_name>`
- 所有注释与文档注释使用中文
---

## 19. 成功标准

若 PocketMind 达到以下状态，可视为本 PRD 成功：

1. 业务真相源与上下文层不再混淆。
2. 聊天服务不再依赖直接字段拼接获取上下文。
3. 用户跨会话获得稳定、可解释的长期记忆体验。
4. 多来源内容进入统一 Resource 链路。
5. 多租户 Skill 能力与用户 Memory 明确隔离。
6. 架构支持继续演进，而不是进入新的 schema-first 死胡同。

---

## 20. 最终判断

PocketMind 的 Context Architecture 不是“新增一个 memory 功能”，而是对 AI 能力底座的一次结构性升级。

它的核心不在于多几张表，而在于建立以下能力：

- 统一材料层
- 稳定长期记忆层
- 正式检索层
- 清晰技能层
- 明确会话提交边界
- 面向未来的服务化边界

只有这样，PocketMind 才能真正从“有 AI 功能”走向“具备长期上下文智能”的第二大脑平台。
