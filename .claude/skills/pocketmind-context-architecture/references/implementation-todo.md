# PocketMind Context Architecture Implementation TODO

## 1. 文档目的

本文件不是泛泛而谈的路线图，而是面向实施的分阶段 TODO 清单。

使用方式：

1. 每进入一个阶段，先确认本阶段范围。
2. 只做当前阶段必须做的事项。
3. 每个阶段结束后执行编译、相关测试、启动验证。
4. 阶段完成后记录结果，再进入下一阶段。

本文件与 `SKILL.md` 的关系：

- `SKILL.md` 负责总架构与边界原则。
- `references/openviking-deep-analysis.md` 提供 OpenViking 深度技术参考。
- 本文件负责把原则拆成可执行任务清单。

---

## 2. 总体执行策略

整体顺序必须保持为：

1. 先纠偏
2. 再建统一标识和边界骨架
3. 再接 Resource 输入
4. 再引入 Session commit
5. 再实现 User Memory
6. 再正式化 Retrieval
7. 再扩展 Agent Memory 与高级治理
8. 最后做服务化准备

禁止顺序错乱，例如：

- 在没有 Resource 闭环时先做复杂 Memory 表
- 在没有 commit 语义时直接做长期记忆合并
- 在没有正式 Retrieval 服务时继续把聊天拼装做大

---

## 3. Phase 0：纠偏与架构清障

### 3.1 目标

- 删除已证伪设计
- 修正明显耦合点
- 明确业务真相源与上下文层边界

### 3.2 必做事项

- [x] 删除 `memorySnapshot` 相关设计
- [x] 确认 `Note` / `ChatSession` / `ChatMessage` / `Asset` 为业务真相源
- [x] 清理错误的 Skill 持久化和多余骨架
- [x] 将聊天上下文装配从直接字段拼接切向模板化方向

### 3.3 本阶段产出

- 边界纠偏完成
- 旧设计不再继续扩散
- 后续阶段可以在更稳定的基础上推进

### 3.4 退出条件

- 编译通过
- 相关测试通过
- 启动通过
- 旧错误设计不再作为新代码参考

---

## 4. Phase 1：Context 骨架与统一标识

### 4.1 目标

建立上下文最小公共语言。

### 4.2 必做事项

- [x] 建立 `ContextType`
- [x] 建立 `ContextLayer`
- [x] 建立 `ContextStatus`
- [x] 建立 `ContextUri`
- [x] 建立 `ContextRef` 最小模型
- [x] 建立 `ResourceSourceType`
- [x] 建立 `MemoryType` 最小边界

### 4.3 待落地事项

空间模型在架构上已经确定为：`SYSTEM`、`TENANT`、`AGENT`、`USER`、`SESSION`。

本阶段代码侧仍需落地：

- [ ] 将 `SpaceType` 五层枚举落实到代码
- [ ] 将可见性枚举落实到代码，如 `PRIVATE` / `SESSION_ONLY` / `TENANT_SHARED` / `SYSTEM_SHARED`
- [ ] 为上下文对象补充 owner / tenant / visibility 的统一接口约束
- [ ] 将 `shared skill -> SYSTEM`、`tenant skill -> TENANT`、`agent overlay -> AGENT` 的规则落实到解析流程

### 4.4 风险提醒

- 不要把统一标识误做成统一万能抽象
- 不要为了 `ContextUri` 牺牲业务对象自然边界

### 4.5 退出条件

- 所有上下文对象有一致的最小分类语义
- 代码不需要再靠字符串常量描述上下文类型

---

## 5. Phase 2：检索基建 + Resource 层最小闭环

### 5.1 目标

落地 HierarchicalRetriever SPI（Day 1 接口稳定），让 Note、Chat、Web、Asset 等来源都能投影为统一 Resource。

### 5.2 现有已完成

- [x] Note -> Resource 投影与同步
- [x] Chat transcript -> Resource 同步最小链路

### 5.3 检索基建（新增，优先）

> **为什么提前到 Phase 2**：`HierarchicalRetriever` 接口 Day 1 稳定后，Phase 3-8 只换实现不改接口。

- [ ] 实现 `ContextNode` record（uri, parentUri, contextType, layer, name, abstractText, activeCount, updatedAt, isLeaf）
- [ ] 建立 `context_catalog` 表（uri, parent_uri, context_type, layer, name, abstract_text, active_count, updated_at, is_leaf,  embedding vector(1536)）
- [ ] 实现 `ContextCatalogRepository` 接口 + MyBatis-Plus 实现
- [ ] 实现 `HierarchicalRetriever` **稳定接口** — `retrieve(RetrievalQuery, userId)` → `RetrievalResult`
- [ ] 实现 `ChildSearchStrategy` **SPI 接口** — `searchChildren()`, `globalSearch()`, `loadByUris()`
- [ ] 实现 `HotnessScorer` **SPI 接口** + `DefaultHotnessScorer`（移植 OpenViking 公式）
- [ ] 实现 `DbChildSearchStrategy` — Day 1 实现：SQL parent_uri + keyword LIKE
- [ ] 实现 `DefaultHierarchicalRetriever` — 优先队列递归 + 得分传播 + 收敛检测
- [ ] 单元测试: ContextNodeTest, DefaultHotnessScorerTest, DefaultHierarchicalRetrieverTest, DbChildSearchStrategyTest

**接口稳定性保证**：

| 接口 | 扩展方式 | 后续变更 |
|------|---------|--------|
| `HierarchicalRetriever` | 永不变 | Phase 5/8 只升级注入的实现 |
| `ChildSearchStrategy` | Day1=keyword → Day2=pgvector | 新实现类, 0接口改动 |
| `HotnessScorer` | 参数可配置 | 从不改接口 |
| `ContextNode` | 只加字段不删 | 向后兼容 |

### 5.4 Resource 继续待做

- [ ] Web clip -> Resource 规范化接入
- [ ] OCR / PDF / 音视频转写 -> Resource 统一入口
- [ ] Resource 的 hash/version/state 规则统一
- [ ] 增加 source-biz 回溯字段规范
- [ ] 补充 Resource 生命周期测试
- [ ] 为 Resource 增加 L0/L1/L2 三层内容字段（abstract_text、summary_text、normalized_text）
- [ ] 为 Resource 表增加 `embedding vector(1536)` 列（pgvector）

### 5.4 建议拆分任务

#### 子任务 A：来源枚举清理

- [ ] 统一 Resource 来源枚举命名
- [ ] 将来源类型按 note/chat/import/asset/system 分组

#### 子任务 B：投影服务收口

- [ ] 新建或补齐 `ResourceProjectionService`
- [ ] 明确不同业务域只负责提供原始内容，不直接写资源表

#### 子任务 C：异步化准备

- [ ] 明确哪些 Resource 更新同步执行
- [ ] 明确哪些 Resource 更新异步执行

### 5.5 退出条件

- 主要输入源都能统一形成 Resource
- Resource 都能回溯来源业务对象
- 聊天服务不再直接依赖 Note/Asset 杂糅字段获取长文本

---

## 6. Phase 3：Session commit 与中间层摘要

### 6.1 目标

为聊天建立阶段性提交边界，使记忆沉淀有合法触发时机。

### 6.2 必做事项

- [ ] 设计 `SessionCommitService`（参考 OpenViking `session.commit()` 6 步流水线）
- [ ] 定义 commit 触发条件（任务完成/消息阈值/暂停归档/定时切段）
- [ ] 生成 transcript resource (L2)
- [ ] LLM 生成结构化摘要 (L1)（prompt: `compression/structured_summary.st`）
- [ ] 从摘要提取 abstract (L0)
- [ ] 记录 commit log (sessionId, commitIndex, memoriesExtracted, stats)
- [ ] 建立关联 (ContextRef: session_uri ↔ 引用的 URI)
- [ ] 更新 active_count (本轮使用的所有 context URI)

### 6.3 建议设计点

- commit 可以由会话暂停、轮次结束、任务结束触发
- commit 不等于关闭会话
- commit 只负责阶段归档与沉淀触发，不负责 UI 层语义

### 6.4 测试任务

- [ ] commit 后 transcript resource 正确生成
- [ ] commit 后 stage summary 正确生成
- [ ] 重复 commit 具备幂等或可接受的版本行为

### 6.5 退出条件

- 聊天历史可形成阶段性资源
- 后续 memory 抽取有稳定输入边界

---

## 7. Phase 4：User Memory + Memory Tool Set 最小闭环

### 7.1 目标

实现首批用户长期记忆能力 + AI 渐进披露工具集。

### 7.2 v1 推荐 Memory 类型

- [ ] `PROFILE`
- [ ] `PREFERENCE`
- [ ] `ENTITY`
- [ ] `EVENT`
- [ ] `GOAL`

### 7.3 必做事项

- [ ] 定义 `MemoryRecord` 主模型（含 L0 abstract + L1 content + L2 detail + evidence）
- [ ] 定义 `MemoryEvidence` 引用模型（sourceUri, snippetRange, capturedAt）
- [ ] 实现 `MemoryExtractor`（prompt: `compression/memory_extraction.st`）
  - 从 transcript + context 提取 4 类 user memory candidates
  - 每条含 category, abstract(L0), content(L1), facet, evidence_refs
- [ ] 实现 `MemoryDeduplicator`（参考 OpenViking dedup 管线）
  - Step 1: pgvector 向量预过滤 (limit=5, scope=category+owner)
  - Step 2: LLM 决策 (prompt: `compression/dedup_decision.st`)
  - 候选决策: SKIP / CREATE / NONE
  - 已有记忆动作: MERGE / DELETE
- [ ] 实现 `MemoryMergeService`（prompt: `compression/memory_merge.st`）
  - PROFILE 类始终合并
  - PREFERENCE/ENTITY 类支持 LLM 合并
  - EVENT 类独立记录不合并
- [ ] 从 session commit 和 note/resource 更新触发 memory candidates
- [ ] 为 memory_records 表增加 `embedding vector(1536)` 列

### 7.4 Memory Tool Set（AI 渐进披露工具）

> 3 个 Tool 构成 AI 的记忆访问接口，替代文件系统浏览。

- [ ] 实现 `MemoryToolSet` 类（注册为 Spring AI ToolCallback）
  - `browseMemoryCategories()` — 返回 8 类记忆数量 + L0 摘要 (~200 tok)
  - `searchMemories(query, type?)` — pgvector 向量搜索 + hotness 排序 → top-5 L1 摘要 (~300 tok)
  - `getMemoryDetail(memoryId)` — 返回 L2 全文 + evidence refs (~500-2000 tok)
- [ ] 在 `AiToolsConfiguration` 中注册 MemoryToolSet
- [ ] Tool 描述中指导 AI 使用顺序：browse → search → detail
- [ ] 单元测试: MemoryToolSetTest

**为什么不用文件系统**：
- 1次 `searchMemories` tool call = 1次向量搜索 = ~300 tok
- 等价文件浏览: `ls` + `cat` × N = 24+ tool calls = ~7000 tok + 40s 延迟
- 向量搜索能跨分类语义匹配，文件目录只能按分类枚举

### 7.5 可延后事项

- [ ] 高级 forget / decay 机制
- [ ] 用户可见的记忆编辑界面
- [ ] 复杂冲突解决策略

### 7.5 关键判断标准

若某设计只是把摘要存起来，而不能回答“来源是什么、如何更新、如何合并”，则不算真正完成 Memory。

### 7.6 退出条件

- 至少一类长期 memory 能从真实资源中抽取并在新会话中被召回
- memory 能回溯 evidence
- memory 不等于全文复制

---

## 8. Phase 5：Retrieval 双通道正式化

### 8.1 目标

把当前零散的上下文组装升级为正式双通道 Retrieval 服务：服务端预注入 + AI Tool Bridge 渐进披露。

### 8.2 必做事项

- [ ] 实现 `IntentAnalyzer`（参考 OpenViking intent_analyzer）
  - prompt: `retrieval/intent_analysis.st`
  - 输出: `QueryPlan(List<TypedQuery>, sessionContext, reasoning)`
  - 任务类型: 操作型(skill+resource+memory) / 信息型(resource+memory) / 对话型(无需检索)
- [ ] 建立 `TypedQuery` 模型 (query, contextType, intent, priority, targetScopes)
- [ ] 建立 `ResourceRetriever`（pgvector 语义搜索）
- [ ] 建立 `MemoryRetriever`（pgvector + hotness 加权）
  - hotness = sigmoid(log1p(active_count)) × exp(-decay × age_days)
  - final_score = 0.8 × semantic + 0.2 × hotness
  - half_life = 7 天
- [ ] 建立 `SkillResolver`（已有请求级解析基础）
- [ ] 建立 `RetrievalOrchestrator`（并发分发 TypedQuery 到不同 Retriever）
- [ ] 让 `ContextAssembler` 改为消费召回结果而不是自行找材料
- [ ] 确保双通道并行：服务端预注入(system prompt里) + AI Tool Bridge(对话中按需)

### 8.3 预算与排序

- [ ] 设计 token budget 规则
- [ ] 设计最近会话与长期记忆比例
- [ ] 设计重复来源去重策略
- [ ] 设计 fallback 规则

### 8.4 测试任务

- [ ] 检索结果包含 Resource + Memory + Skill 三类材料
- [ ] 用户空间、会话空间、租户空间、Agent 空间、系统空间的召回边界正确
- [ ] 不同用户/租户的结果隔离正确
- [ ] `shared skill` 只经系统空间注入，不与 tenant/user memory 混淆
- [ ] 无可用 memory 时有合理 fallback

### 8.5 退出条件

- 聊天链路已通过 Retrieval 服务获取正式上下文
- `AiChatService` 不再承担检索决策职责

---

## 9. Phase 6：Skill 能力层稳定化

### 9.1 目标

在已完成的请求级多租户注入基础上，继续稳固 Skill 作为能力层的边界。

### 9.2 已完成

- [x] 请求级多租户 Skill 注入
- [x] shared + tenant + optional agent overlay 路径策略
- [x] 分析链路不默认注入 Skill

### 9.3 后续待做

- [ ] 统一 Skill 描述模型
- [ ] 统一 Skill 元数据与解析缓存策略
- [ ] 规划 Skill 版本化策略
- [ ] 为不同 scene 提供更清晰的选择规则

### 9.4 退出条件

- Skill 继续保持文件驱动与请求级解析
- Skill 不侵入用户记忆领域

---

## 10. Phase 7：Agent Memory 与高级治理

### 10.1 目标

在用户记忆稳定后，引入执行经验层。

### 10.2 推荐能力

- [ ] `CASE`
- [ ] `PATTERN`
- [ ] `PLAYBOOK`
- [ ] `TOOL_EXPERIENCE`

### 10.3 必做事项

- [ ] 定义 agent-space ownership
- [ ] 定义与 tenant skill 的关系
- [ ] 定义能否跨用户共享
- [ ] 定义治理流程：merge / obsolete / review

### 10.4 退出条件

- Agent 经验和用户个人知识边界清晰
- Agent memory 不会污染用户画像

---

## 11. Phase 8：检索实现升级（接口不变）

### 11.1 目标

替换 `ChildSearchStrategy` 实现为 pgvector 向量搜索，算法和接口零改动。

### 11.2 必做事项

- [ ] 实现 `VectorChildSearchStrategy implements ChildSearchStrategy`（pgvector `embedding <=> query_vec`）
- [ ] `@ConditionalOnProperty` 切换 keyword → vector 实现
- [ ] 评估 `resource_chunk` 是否需要单独建模
- [ ] pgvector 索引优化：IVFFlat 或 HNSW 索引类型选择
- [ ] 评估是否需要独立向量库（Milvus/Qdrant）替代 pgvector
- [ ] 为 memory 检索建立独立索引策略
- [ ] 建立索引重建和补偿机制
- [ ] **注意：`HierarchicalRetriever` 接口 + 算法不变，只换 `ChildSearchStrategy` 实现**
- [ ] 评估是否需要独立向量库（Milvus/Qdrant）替代 pgvector

### 11.3 风险提醒

- 不要过早引入复杂基础设施而缺少实际召回价值
- 先保证召回语义正确，再追求索引花样

### 11.4 退出条件

- 资源与记忆检索性能、准确性和可维护性达到可接受水平

---

## 12. Phase 9：服务化准备

### 12.1 目标

为未来独立 Context Service 留出接口边界。

### 12.2 待做事项

- [ ] 定义跨域接口契约
- [ ] 定义资源同步事件模型
- [ ] 定义记忆查询 API 边界
- [ ] 定义检索 API 边界
- [ ] 评估服务拆分收益与代价

### 12.3 退出条件

- 即使暂不拆服务，也已形成稳定边界

---

## 13. 横切任务清单

这些任务应贯穿多个阶段持续执行。

### 13.1 测试

- [ ] 为每个新增服务补单元测试
- [ ] 为关键同步链路补集成测试
- [ ] 为会话提交流水线补端到端验证

### 13.2 文档

- [ ] 每阶段结束更新架构文档
- [ ] 记录字段废弃计划
- [ ] 记录兼容策略与迁移顺序

### 13.3 可观测性

- [ ] 为 Resource 同步增加日志与指标
- [ ] 为 Memory 提取增加日志与指标
- [ ] 为 Retrieval 命中情况增加日志与指标

### 13.4 幂等与补偿

- [ ] 投影任务幂等
- [ ] commit 任务幂等
- [ ] 索引更新可补偿
- [ ] memory merge 可重试

---

## 14. 当前建议优先级

从当前代码状态（Phase 0-1 已完成）继续推进，建议优先级如下：

1. **HierarchicalRetriever SPI 落地** — ContextNode + ContextCatalog表 + 接口 + DefaultHierarchicalRetriever + DbChildSearchStrategy + DefaultHotnessScorer + 单测
2. **Resource L0/L1/L2 补全** — 为 resource_records 增加 abstract_text + embedding 列，同步写入 context_catalog
3. **Resource 多来源接入** — Web clip / OCR / PDF 统一入 Resource 链路
4. **Session commit 最小实现** — SessionCommitService 含归档+L0/L1/L2生成+commit log
5. **Memory 模型+提取** — MemoryRecord 含 L0/L1/L2 + MemoryExtractor（LLM prompt）
6. **Memory Tool Set** — 3个@Tool: browseCategories/searchMemories/getDetail + 注册到 AiToolsConfiguration
7. **Memory 去重+合并** — MemoryDeduplicator（pgvector 预过滤 + LLM 决策）+ MemoryMergeService
8. **双通道 Retrieval** — IntentAnalyzer + ContextAssembler升级 + VectorChildSearchStrategy替换DbChildSearchStrategy

**技术基础设施前置**：
- pgvector 扩展已在 docker-compose.yml 中启用
- prompt 模板需提前创建：`compression/memory_extraction.st`、`compression/dedup_decision.st`、`compression/memory_merge.st`、`compression/structured_summary.st`、`retrieval/intent_analysis.st`
- 配置参数在 `application.yml` 中：`pocketmind.memory.hotness.*`、`pocketmind.memory.dedup.*`、`pocketmind.retrieval.*`

---

## 15. 每轮实施的标准输出模板

每完成一轮实施，应固定输出：

1. 本轮阶段与目标
2. 本轮明确不做什么
3. 修改文件清单
4. 关键架构选择
5. 编译结果
6. 测试结果
7. 启动验证结果
8. 风险与遗留项
9. 下一轮建议

---

## 16. 最终判断标准

如果未来某一阶段出现以下现象，说明路线偏了：

- 又开始依赖业务字段硬拼上下文
- Resource 越做越像万能业务表
- Memory 无 evidence、无 merge、无 owner
- Skill 与 Memory 再次混淆
- Retrieval 只是另一个名字的字符串拼接

如果系统逐渐达到以下状态，说明路线是对的：

- 业务真相源稳定
- Resource 成为统一材料层
- Memory 成为长期知识层
- Skill 成为能力层
- Retrieval 成为正式链路
- Commit 成为沉淀边界

这时 PocketMind 的 Context Architecture 才真正进入正确轨道。
