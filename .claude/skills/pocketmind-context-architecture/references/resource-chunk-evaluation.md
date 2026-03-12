# resource_chunk 独立建模评估（Phase 8.4）

更新时间：2026-03-12

## 1. 目标
评估是否需要在当前 PocketMind 后端引入独立 `resource_chunk` 模型（按段切分、独立向量索引、分段召回）。

## 2. 现状
- `resource_records` 已有 `abstract_text / summary_text / normalized_text` 三层内容表示。
- `context_catalog` 已接入 `embedding vector(1024)` 与 HNSW 索引，支持目录与叶子节点语义召回。
- 检索主链路为：`IntentAnalyzer -> RetrievalOrchestrator -> DefaultHierarchicalRetriever/VectorMemoryRetriever`。
- 当前 Resource 注入 prompt 时以“摘要片段”为主，未做正文分段召回。

## 3. 评估结论
当前阶段不立即落地独立 `resource_chunk` 表，先维持“节点级召回 + 摘要注入”策略，理由如下：

1. 现有上下文延迟与命中率已满足当前对话链路要求，未出现必须按段检索才能解决的性能瓶颈。
2. 直接引入 chunk 会同时扩大写入链路复杂度（投影、更新、删除、重建、去重）和一致性成本。
3. 现有系统仍在进行 Phase 8 向量化收敛，优先保证检索链路稳定，再做 chunk 化可降低风险。

## 4. 触发重评条件
满足任一条件时，启动 `resource_chunk` 落地：

1. 线上出现“摘要命中但正文缺失”导致回答质量明显下降的可复现案例。
2. 单条资源正文超过阈值（建议 > 8k token）且高频被召回。
3. 需要精确引用段落级证据（例如法规条款、长文问答、审计留痕）。

## 5. 预留设计（不在本次实现范围）
- 表建议：`resource_chunks(id, resource_uuid, chunk_index, content, token_count, embedding, created_at, updated_at)`。
- 索引建议：`embedding vector_cosine_ops + HNSW`，并保留 `(resource_uuid, chunk_index)` 唯一索引。
- 检索策略：先节点召回，再对候选资源做 chunk 二次召回（两阶段）。
- 同步策略：仅对正文变更资源进行增量重切分。

## 6. 本次决策
Phase 8.4 评估已完成，结论为“暂不实现 chunk 表，保留后续触发条件与落地方案”。
