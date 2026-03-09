# OpenViking 深度分析 — PocketMind 映射参考

> 本文档是对 OpenViking 项目关键实现的深度技术分析，每个章节附带 PocketMind 映射建议。  
> 此文档为**参考文档**，不是执行规范。执行规范见 `SKILL.md`。

---

## 1. 统一 Context 数据模型

### 1.1 OpenViking 实现

OpenViking 的核心思想是**万物皆 Context** — 所有实体（Resource、Memory、Skill）共用统一的 `Context` 模型。

**`openviking/core/context.py` — Context 完整字段**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `str` (UUID) | 唯一标识 |
| `uri` | `str` | Viking URI（如 `viking://memories/user/profile.md`） |
| `parent_uri` | `Optional[str]` | 父节点 URI（树形结构） |
| `is_leaf` | `bool` | 是否为叶子节点 |
| `abstract` | `str` | L0 一句话摘要（~100 token） |
| `context_type` | `str` | `"skill"` / `"memory"` / `"resource"` — 从 URI 自动推导 |
| `category` | `Optional[str]` | 子分类（如 `"profile"`, `"patterns"`, `"cases"`） |
| `level` | `ContextLevel` | `ABSTRACT=0` / `OVERVIEW=1` / `DETAIL=2` |
| `created_at` | `datetime` | 创建时间 |
| `updated_at` | `datetime` | 最后更新时间 |
| `active_count` | `int` | 被检索/引用次数 |
| `related_uri` | `List[str]` | 关联 URI 列表 |
| `meta` | `Dict[str, Any]` | 自由元数据 |
| `session_id` | `Optional[str]` | 来源 session |
| `user` | `UserIdentifier` | 用户标识 |
| `account_id` | `str` | 账户 ID |
| `owner_space` | `str` | 所有者空间（user_space / agent_space） |
| `vector` | `Optional[List[float]]` | embedding 向量 |
| `vectorize` | `Vectorize` | 待向量化文本 |

**关键枚举**：
```python
class ContextType(str, Enum):
    SKILL = "skill"
    MEMORY = "memory"
    RESOURCE = "resource"

class ContextLevel(int, Enum):
    ABSTRACT = 0   # L0
    OVERVIEW = 1   # L1
    DETAIL = 2     # L2
```

### 1.2 PocketMind 映射

PocketMind **不采用**万物皆 Context 的扁平化设计，而是保持业务对象独立性。但需要借鉴 Context 模型中的关键属性：

| OpenViking 字段 | PocketMind 映射位置 | 说明 |
|----------------|---------------------|------|
| `uri` | `ContextUri` 工具类 | 格式: `pm://{type}/{bizId}` |
| `context_type` | `ContextType` 枚举 | RESOURCE / MEMORY / SKILL |
| `level` | `ContextLayer` 枚举 | L0_ABSTRACT / L1_OVERVIEW / L2_DETAIL |
| `owner_space` | `SpaceType` 枚举（待落地） | SYSTEM / TENANT / AGENT / USER / SESSION |
| `active_count` | `ResourceRecord.activeCount` / `MemoryRecord.activeCount` | 各表自带 |
| `category` | `MemoryType` 枚举 | PROFILE / PREFERENCE / ENTITY / EVENT 等 |
| `abstract` | `ResourceRecord.summaryText` / `MemoryRecord.summary` | L0 级摘要 |
| `parent_uri` | `ContextRef` 表 | 关系表而非字段 |

---

## 2. 记忆生命周期管线

### 2.1 Memory 提取（MemoryExtractor）

**来源文件**：`openviking/session/memory_extractor.py`

OpenViking 使用 LLM 从 session transcript 中提取 8 类记忆：

**MemoryCategory 枚举**（`memory_extractor.py:31-49`）：

| 枚举值 | 空间 | 说明 |
|--------|------|------|
| `PROFILE` | UserMemory | 用户画像（写入 `profile.md`） |
| `PREFERENCES` | UserMemory | 用户偏好（按主题聚合） |
| `ENTITIES` | UserMemory | 实体记忆（项目、人物、概念） |
| `EVENTS` | UserMemory | 事件记录（决策、里程碑） |
| `CASES` | AgentMemory | 案例（具体问题+解决方案） |
| `PATTERNS` | AgentMemory | 模式（可复用流程/方法） |
| `TOOLS` | Tool/Skill | 工具使用记忆（优化、统计） |
| `SKILLS` | Tool/Skill | 技能执行记忆（工作流、策略） |

**空间分组常量**：
```python
_USER_CATEGORIES = {PROFILE, PREFERENCES, ENTITIES, EVENTS}
_AGENT_CATEGORIES = {CASES, PATTERNS}
TOOL_SKILL_CATEGORIES = {TOOLS, SKILLS}  # compressor.py
```

**提取流程**：
1. 将 session messages 序列化为 transcript 文本
2. 使用 `compression.memory_extraction` prompt 模板调用 LLM
3. LLM 输出 JSON：每条包含 `category`、`abstract`(L0)、`content`(L1)、`facet`(子分类key)
4. 一次 session commit 可产出 0~N 条 memory candidates

### 2.2 Memory 去重（MemoryDeduplicator）

**来源文件**：`openviking/session/memory_deduplicator.py`

去重分两步：向量预过滤 + LLM 精确决策。

**Step 1 — 向量预过滤 `_find_similar_memories()`**：
- 将候选记忆的 `abstract + content` 做 embedding
- 在 VectorDB 中搜索相似已有记忆，scope: `category_uri_prefix + account_id + owner_space`
- `limit=5`, `SIMILARITY_THRESHOLD = 0.0`
- 返回最相似的已有 Context 对象列表

**Step 2 — LLM 精确决策 `_llm_decision()`**：
- 若无相似记忆 → 直接 `CREATE`（跳过 LLM 调用）
- 否则格式化至多 `MAX_PROMPT_SIMILAR_MEMORIES = 5` 条已有记忆
- 使用 `compression.dedup_decision` prompt 调用 LLM
- 解析输出为决策结构

**候选级决策 `DedupDecision`**：

| 决策 | 含义 |
|------|------|
| `SKIP` | 候选是重复的，跳过创建 |
| `CREATE` | 候选是新知识，创建新记忆 |
| `NONE` | 不创建候选，但可能需要合并/删除已有记忆 |

**已有记忆动作 `MemoryActionDecision`**：

| 动作 | 含义 |
|------|------|
| `MERGE` | 将候选信息合并入已有记忆 |
| `DELETE` | 删除冲突的已有记忆 |

**归一化规则**（`_parse_decision_payload`）：
- 遗留 `"merge"` 决策 → 映射为 `NONE` + 第一条相似记忆 MERGE
- `SKIP` → 清除所有 per-memory 动作
- `CREATE` + 任何 MERGE → 归一化为 `NONE`（矛盾操作）
- `CREATE` 只允许携带 `DELETE` 动作
- 同一 URI 上的冲突动作 → 两条都丢弃

### 2.3 Memory 合并（MemoryMerge）

**两种合并 prompt**：
1. `compression.memory_merge` — 合并已有+新信息，输出单条合并结果
2. `compression.memory_merge_bundle` — 合并后同时输出 L0/L1/L2 三层

**特殊类别处理**（`compressor.py`）：

| 类别 | 合并策略 |
|------|---------|
| `PROFILE` | `ALWAYS_MERGE_CATEGORIES` — 跳过去重，始终合并到 `profile.md` |
| `PREFERENCES`, `ENTITIES`, `PATTERNS` | `MERGE_SUPPORTED_CATEGORIES` — 支持 LLM 合并 |
| `EVENTS`, `CASES` | 不支持 MERGE（事件和案例是独立记录） |
| `TOOLS`, `SKILLS` | `TOOL_SKILL_CATEGORIES` — 使用统计累积逻辑，不经 LLM 去重 |

### 2.4 PocketMind 映射

PocketMind 应实现等价管线，但适配 Spring Boot 生态：

```
MemoryExtractor (Spring AI + prompt template)
  → MemoryDeduplicator (pgvector 预过滤 + LLM 决策)
    → MemoryMergeService (LLM 合并 或 统计累积)
      → MemoryRepository.save() / .update() / .softDelete()
```

**prompt 模板路径**：
- `src/main/resources/prompts/compression/memory_extraction.st`
- `src/main/resources/prompts/compression/dedup_decision.st`
- `src/main/resources/prompts/compression/memory_merge.st`
- `src/main/resources/prompts/compression/structured_summary.st`

---

## 3. L0 / L1 / L2 三层索引体系

### 3.1 OpenViking 实现

OpenViking 使用 AGFS（Agent Ground-truth File System）物理化三层：

```
viking://resources/my_project/
├── .abstract.md          # L0: ~100 token 极短摘要
├── .overview.md          # L1: ~2k token 结构化概览
├── docs/
│   ├── .abstract.md      # 子目录也有 L0/L1
│   ├── .overview.md
│   └── api.md            # L2: 完整内容
└── src/
```

**三层用途**：

| 层 | 文件 | Token | 用途 |
|----|------|-------|------|
| L0 | `.abstract.md` | ~100 | 向量检索、快速过滤 — 只需读这一层就能判断"有没有关系" |
| L1 | `.overview.md` | ~2k | Rerank、内容导航 — 告诉 Agent 如何访问详细内容 |
| L2 | 原始文件 | 无限 | 全文内容 — 仅在确认需要时按需加载 |

**向量化策略**（`embedding_utils.py`）：
- L0 和 L1 都入向量库（分别作为独立 Context 对象）
- L2 文件的向量化使用文件摘要（text files 读全文，非文本用 summary）
- 每层的 Context 对象 `level` 字段不同

### 3.2 PocketMind 映射

PocketMind 不用物理文件，但在 DB 中实现等价语义：

**ResourceRecord 表**：
- `normalized_text` = L2（全文）
- `summary_text` = L1（概览）
- `abstract_text` = L0（待新增字段，或 summary 截取前 100 token）
- `layer` = `ContextLayer` 枚举值

**MemoryRecord 表**：
- `normalized_content` = L2（完整 evidence + 细节）
- `summary` = L1（结构化概览）
- `abstract` = L0（一句话摘要，用于向量化）

**pgvector 索引策略**：
- v1: 对 L0/L1 的文本做 embedding，存入 `vector(1536)` 列
- 检索时先搜 L0 快速过滤，必要时加载 L1 做 rerank，最终取 L2 入 prompt

---

## 4. 层级递归检索（HierarchicalRetriever）

### 4.1 OpenViking 实现

**来源文件**：`openviking/retrieve/hierarchical_retriever.py`

**核心常量**：
```python
MAX_CONVERGENCE_ROUNDS = 3     # 收敛检测轮数
MAX_RELATIONS = 5              # 最大关联数
SCORE_PROPAGATION_ALPHA = 0.5  # 得分传播权重
DIRECTORY_DOMINANCE_RATIO = 1.2 # 目录优势比
GLOBAL_SEARCH_TOPK = 3        # 全局搜索返回数
HOTNESS_ALPHA = 0.2            # 热度混合权重
```

**搜索算法 `_recursive_search()`**：

```
输入: starting_points (List[Context]), query, limit, mode, reranker
输出: List[Context] (按 final_score 降序)

1. 初始化优先队列 dir_queue = [(-score, uri) for each starting_point]
2. while dir_queue 非空:
   a. 弹出最高分 URI → current_uri, current_score
   b. 跳过已访问节点
   c. 搜索子节点: vector_store.search_children_in_tenant(parent_uri=current_uri)
      pre_filter_limit = max(limit*2, 20)
   d. 如有 reranker + THINKING mode → rerank 子节点
   e. 对每个子节点:
      - 得分传播: final_score = 0.5 × child_score + 0.5 × parent_score
      - 低于阈值 → 跳过
      - URI 去重（保留最高分）
      - 非 L2 节点（L0/L1 = 目录）→ 加入 dir_queue 继续递归
      - L2 节点 = 终端命中 → 收集为候选
   f. 收敛检测:
      - 计算当前 top-k URI 集合
      - 若与上轮相同 且 候选数 >= limit → convergence_rounds++
      - convergence_rounds >= 3 → 提前终止
      - 否则重置计数器
3. 按 final_score 降序排序，返回 top-limit
```

**起始点选择**：
- 指定 `target_directories` 或按 `ContextType` 获取根 URI
- 全局向量搜索 `GLOBAL_SEARCH_TOPK=3` 条
- 合并起始点（rerank 或原始得分 + 根 URI score=0.0）

### 4.2 Hotness 混合公式

**来源文件**：`openviking/retrieve/memory_lifecycle.py`

```
hotness = sigmoid(log1p(active_count)) × exp(-(ln2 / half_life) × age_days)
final_score = (1 - HOTNESS_ALPHA) × semantic_score + HOTNESS_ALPHA × hotness
           = 0.8 × semantic_score + 0.2 × hotness
```

其中：
- `sigmoid(x) = 1 / (1 + exp(-x))`
- `half_life = 7.0 天`（默认）
- `age_days = (now - updated_at).total_seconds() / 86400`
- `active_count = 0` 时 `hotness ≈ 0.5 × recency`

### 4.3 PocketMind 映射

PocketMind **Day 1 落地层级递归检索**，通过 SPI 接口确保实现可替换：

1. **`HierarchicalRetriever` 稳定接口**（永不变）
   - `retrieve(RetrievalQuery, userId)` → `RetrievalResult`
   - 内部算法：优先队列递归 + 得分传播 + 收敛检测（与 OpenViking 一致）

2. **`ChildSearchStrategy` SPI**（实现可热替换）
   - Day 1: `DbChildSearchStrategy` — SQL `parent_uri` + keyword `LIKE`
   - Day 2: `VectorChildSearchStrategy` — pgvector `embedding <=> query_vec`
   - Future: `CompositeChildSearchStrategy` — vector + keyword 融合

3. **`HotnessScorer` SPI**（参数可配置）
   - 移植上述 hotness 公式，默认参数与 OpenViking 一致
   - `half_life=7.0`, `alpha=0.2`

4. **`ContextNode` 通用节点**（只加字段不删）
   - `uri, parentUri, contextType, layer, name, abstractText, activeCount, updatedAt, isLeaf`
   - 对应 `context_catalog` 表，支持 DB 和未来 File 两种后端

5. **Hotness 加权**
   - 实现 `DefaultHotnessScorer` — 移植上述公式
   - 在 `DefaultHierarchicalRetriever` 最终结果上应用 hotness blending

**不同于 OpenViking 的简化**：
- v1 无目录树结构，但 `parent_uri` 字段预留，递归算法天然支持
- v1 无 reranker，递归中直接用 raw score，预留 reranker 扩展点

---

## 5. 意图分析（IntentAnalyzer）

### 5.1 OpenViking 实现

**来源文件**：`openviking/retrieve/intent_analyzer.py`、`openviking/prompts/templates/retrieval/intent_analysis.yaml`

**TypedQuery 结构**：
```python
@dataclass
class TypedQuery:
    query: str                        # 检索查询文本
    context_type: ContextType         # SKILL | RESOURCE | MEMORY
    intent: str                       # 意图描述
    priority: int = 3                 # 1-5，1 最高
    target_directories: List[str] = []  # 目标目录
```

**类型分配规则**（从 prompt 模板）：

| 类型 | 触发条件 | 查询风格 |
|------|---------|---------|
| `skill` | 任务含动作动词（创建、生成、编写、构建、分析） | 以动词开头，保持操作意图 — "创建 RFC 文档" |
| `resource` | 需要参考材料、模板、规范、知识 | 名词短语，描述知识内容 — "RFC 文档标准模板" |
| `memory` | 需要个性化（用户记忆）或经验（agent 记忆） | 用户记忆: "用户的XX偏好"；agent 记忆: "执行XX的经验" |

**三步分析流程**：
1. **任务类型判断**：操作型 → skill+resource+memory；信息型 → resource+memory；对话型 → 无需检索
2. **上下文覆盖检查**：已有覆盖 → 跳过；部分覆盖 → 补充；无覆盖 → 全量查询
3. **生成查询**：最多 5 条 TypedQuery，每条含 context_type + intent + priority

**输出**：`QueryPlan(queries: List[TypedQuery], session_context: str, reasoning: str)`

### 5.2 PocketMind 映射

```java
// 核心模型
public record TypedQuery(
    String query,
    ContextType contextType,  // SKILL / RESOURCE / MEMORY
    String intent,
    int priority,             // 1-5
    List<String> targetScopes // 替代 target_directories
) {}

public record QueryPlan(
    List<TypedQuery> queries,
    String sessionContext,
    String reasoning
) {}

// IntentAnalyzer 接口
public interface IntentAnalyzer {
    QueryPlan analyze(String currentMessage, List<ChatMessage> recentMessages);
}
```

prompt 模板：`src/main/resources/prompts/retrieval/intent_analysis.st`

---

## 6. Session Commit 完整流程

### 6.1 OpenViking 实现

**来源文件**：`openviking/session/session.py:193-244`（`commit()` 方法）

**完整 6 步流程**：

```python
def commit(self) -> Dict[str, Any]:
    # Step 1: 归档当前消息
    #   - compression_index += 1
    #   - 复制消息列表
    #   - LLM 生成结构化摘要（prompt: compression.structured_summary）
    #   - 从摘要中提取 abstract
    #   - 写入 history/archive_{NNN:03d}/
    #     ├── .abstract.md
    #     ├── .overview.md
    #     └── messages.jsonl
    #   - 清空当前 self._messages

    # Step 2: 提取长期记忆
    #   - self._session_compressor.extract_long_term_memories(messages, user, session_id, ctx)
    #   - 内部调用 MemoryExtractor.extract() → MemoryDeduplicator → persist

    # Step 3: 写入当前消息到 AGFS
    #   - messages.jsonl + .abstract.md + .overview.md

    # Step 4: 建立关联（relations）
    #   - for each usage_record: viking_fs.link(session_uri, usage.uri)

    # Step 5: 更新 active_count
    #   - vikingdb_manager.increment_active_count(ctx, uris=[all usage URIs])

    # Step 6: 更新统计
    #   - compression_count = compression_index
    #   - return {session_id, status, memories_extracted, active_count_updated, archived, stats}
```

**`stats` 返回字段**：
- `total_turns`: 本轮消息数
- `contexts_used`: 使用的上下文数量
- `skills_used`: 使用的技能数量
- `memories_extracted`: 提取的记忆数量

### 6.2 Compressor 内部流程（extract_long_term_memories）

**来源文件**：`openviking/session/compressor.py`

```
1. MemoryExtractor.extract(messages) → List[MemoryCandidate]
   每条含: category, abstract, content, facet, evidence_refs

2. 按 category 分组处理:
   a. PROFILE → 始终合并到 profile.md（跳过去重）
   b. TOOLS/SKILLS → 统计累积（非 LLM 去重）
   c. 其他类别 → MemoryDeduplicator.deduplicate()

3. 根据去重决策执行:
   - CREATE → 在 AGFS 创建新记忆文件（.abstract.md + content）→ 向量化入库
   - SKIP → 丢弃候选
   - NONE + MERGE → LLM 合并旧记忆+新信息 → 更新文件 → 重新向量化
   - NONE + DELETE → 逻辑删除旧记忆 → 移除向量

4. 更新向量索引
```

### 6.3 PocketMind 映射

```java
@Service
public class SessionCommitService {
    // Step 1: 归档
    TranscriptResource archiveStage(Long sessionId, List<ChatMessage> messages);

    // Step 2-3: 提取+持久化
    List<MemoryRecord> extractAndPersistMemories(TranscriptResource transcript);

    // Step 4: 关联
    void createContextRefs(Long sessionId, List<String> referencedUris);

    // Step 5: 活跃度
    void incrementActiveCounts(List<String> usedUris);

    // Step 6: 统计
    CommitStats recordCommitStats(Long sessionId, CommitResult result);
}
```

---

## 7. Prompt 模板体系

### 7.1 OpenViking 完整模板清单

OpenViking 使用 YAML + Jinja2 模板，共 **26 个模板文件**，分 8 组：

#### compression/（会话压缩 & 记忆管理）

| 文件 | ID | 用途 |
|------|-----|------|
| `memory_extraction.yaml` | `compression.memory_extraction` | 从 session 提取 8 类记忆（L0/L1/L2 三层） |
| `dedup_decision.yaml` | `compression.dedup_decision` | LLM 去重决策：skip/create/none + merge/delete |
| `memory_merge.yaml` | `compression.memory_merge` | 合并已有记忆与新信息（单条输出） |
| `memory_merge_bundle.yaml` | `compression.memory_merge_bundle` | 合并后输出 L0+L1+L2 三层 JSON |
| `structured_summary.yaml` | `compression.structured_summary` | 为归档 session 生成结构化 Markdown 摘要 |

#### retrieval/（检索 & 查询规划）

| 文件 | 用途 |
|------|------|
| `intent_analysis.yaml` | 分析 session 上下文生成 TypedQuery 计划 |

#### semantic/（语义摘要）

| 文件 | 用途 |
|------|------|
| `document_summary.yaml` | 文档摘要 |
| `file_summary.yaml` | 文件摘要 |
| `overview_generation.yaml` | 目录 L1 概览生成 |
| `code_summary.yaml` | 代码摘要 |
| `code_ast_summary.yaml` | AST 代码摘要 |

#### indexing/（打分）

| 文件 | 用途 |
|------|------|
| `relevance_scoring.yaml` | 相关性打分 |

#### processing/（学习）

| 文件 | 用途 |
|------|------|
| `interaction_learning.yaml` | 用户交互学习 |
| `strategy_extraction.yaml` | 策略提取 |
| `tool_chain_analysis.yaml` | 工具链分析 |

#### parsing/、vision/、skill/、test/ — 内容解析与视觉理解（PocketMind v1 低优先级）

### 7.2 PocketMind v1 必需模板

基于优先级，PocketMind v1 需要实现以下 prompt 模板：

```
src/main/resources/prompts/
├── compression/
│   ├── memory_extraction.st       # 核心：从 transcript 提取 8 类记忆
│   ├── dedup_decision.st          # 核心：LLM 去重决策
│   ├── memory_merge.st            # 核心：记忆合并
│   └── structured_summary.st      # 核心：session 阶段摘要
├── retrieval/
│   └── intent_analysis.st         # 核心：意图分析生成 TypedQuery
└── semantic/
    ├── document_summary.st        # 建议：文档摘要（Resource L1 生成）
    └── overview_generation.st     # 建议：概览生成
```

**注意**：PocketMind 使用 Spring AI 的 `.st` 模板格式（StringTemplate），变量占位使用 `<variable_name>`，不是 Jinja2 的 `{{ }}`。

---

## 8. 配置与调优参数

### 8.1 OpenViking 关键可调参数

| 参数 | 默认值 | 位置 | 说明 |
|------|--------|------|------|
| `DEFAULT_HALF_LIFE_DAYS` | 7.0 | memory_lifecycle.py | 热度衰减半衰期 |
| `HOTNESS_ALPHA` | 0.2 | hierarchical_retriever.py | 热度与语义得分混合权重 |
| `SCORE_PROPAGATION_ALPHA` | 0.5 | hierarchical_retriever.py | 父→子得分传播权重 |
| `MAX_CONVERGENCE_ROUNDS` | 3 | hierarchical_retriever.py | 收敛检测轮数 |
| `GLOBAL_SEARCH_TOPK` | 3 | hierarchical_retriever.py | 全局搜索起始点数 |
| `SIMILARITY_THRESHOLD` | 0.0 | memory_deduplicator.py | 去重向量相似度阈值 |
| `MAX_PROMPT_SIMILAR_MEMORIES` | 5 | memory_deduplicator.py | 去重 prompt 中最大已有记忆数 |
| `ALWAYS_MERGE_CATEGORIES` | {PROFILE} | compressor.py | 始终合并的记忆类别 |
| `MERGE_SUPPORTED_CATEGORIES` | {PREFERENCES, ENTITIES, PATTERNS} | compressor.py | 支持 LLM 合并的类别 |
| `TOOL_SKILL_CATEGORIES` | {TOOLS, SKILLS} | compressor.py | 统计累积类别 |

### 8.2 PocketMind 建议配置

```yaml
# application.yml
pocketmind:
  memory:
    hotness:
      half-life-days: 7.0
      alpha: 0.2
    dedup:
      similarity-threshold: 0.0
      max-similar-memories: 5
    merge:
      always-merge: [PROFILE]
      merge-supported: [PREFERENCE, ENTITY, PATTERN]
      stat-accumulate: [TOOL_EXPERIENCE, SKILL_EXECUTION]
  retrieval:
    score-propagation-alpha: 0.5
    max-convergence-rounds: 3
    global-search-topk: 3
```

---

## 9. OpenViking 不可直接采用的设计

以下 OpenViking 设计不适用于 PocketMind，需要注意规避：

| OpenViking 设计 | 原因 | PocketMind 替代 |
|----------------|------|-----------------|
| AGFS 物理文件系统（记忆/资源） | Memories 动态(100-10000条)、需向量搜索、移动端可见、并发写入 | DB 表 + pgvector + AI Tool Bridge |
| 万物皆 Context 扁平模型 | PocketMind 需保留独立业务对象 | 业务表 + 投影表 + 记忆表分离 |
| VikingDB 向量库适配器 | OpenViking 支持多种向量库 | v1 用 pgvector，ChildSearchStrategy SPI 预留扩展 |
| URI 中的物理路径（如 `.abstract.md`） | DB 中无物理路径 | `pm://{type}/{id}#{layer}` 格式 |
| Python 异步队列 | Java 生态差异 | 虚拟线程 + @Async + RabbitMQ |
| 全文件树浏览发现 | >50条时浏览需24+tool call, 7000+tok, 40s+ | 向量搜索1次call, 300tok, 50ms |

### 9.1 为什么 Skills 保持文件而 Memories/Resources 用 DB

| 属性 | Skills → 文件 | Memories → DB |
|------|-------------|---------------|
| 数量级 | 5-50 | 100-10,000 |
| 变更频率 | 部署时 | 每次会话 commit |
| 作者 | 人类编写 | AI 提取 |
| 搜索方式 | 枚举/名称 | 语义向量 |
| 用户可见 | 否(AI专用) | 是(移动端展示/编辑) |
| 并发写 | 不存在 | session commit 并发 |

Skills 文件模式已验证可行（`MultiTenantSkillsToolFactory`），但该模式**不适用于**动态、大量、需向量搜索、移动端可见的数据。

### 9.2 AI 渐进披露：Tool Bridge vs 文件浏览

PocketMind 采用 **DB + AI Tool Bridge** 实现 OpenViking AGFS 的等价渐进披露语义：

```
OpenViking 文件浏览:                    PocketMind Tool Bridge:
ls /memories/ → 8 个分类目录            browseMemoryCategories() → 8 类摘要
cat /memories/profile/.abstract.md      searchMemories("profile") → L0/L1 列表
cat /memories/profile/profile.md        getMemoryDetail(id) → L2 全文

浏览开销: 24+ tool calls, ~7000 tok     工具开销: 3 tool calls, ~1300 tok
延迟: 40s+ (每次tool call=一次LLM往返)    延迟: 8s (每次tool call=一次LLM往返)
跨分类语义: 不可能                       跨分类语义: pgvector 天然支持
```
