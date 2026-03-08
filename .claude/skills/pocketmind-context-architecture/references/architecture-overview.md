# Context Architecture 总览

## 目标
PocketMind 的 Context Architecture 要解决的不是“聊天里多一段摘要”，而是把用户上传、分享、聊天、AI 学习、能力定义、上下文检索这些能力收敛到统一语义模型中。

## 顶层语义
建议按以下语义组织：

- `resources`：用户主动提供或系统导入的知识材料
- `user memories`：AI 从资源与聊天中提取出的用户长期知识
- `agent memories`：AI/系统在执行中沉淀的经验
- `skills`：多租户 AI 能力定义、Prompt、策略、工作流
- `sessions`：会话上下文与提交入口
- `retrieval`：上下文查询、召回、重排

## 与现有业务模型的关系
现有业务模型仍保留：

- `Note`
- `ChatSession`
- `ChatMessage`
- `Asset`

它们是产品主模型，不直接等于上下文顶层。

### 建议关系
- `Note` / `Chat` / `Asset` 是业务实体
- `Resource` / `Memory` / `Skill` / `Session` 是上下文实体
- 二者通过 `ContextRef` 或等价引用结构关联

## 总体演进原则
1. 先纠偏现有设计
2. 再建立最小上下文骨架
3. 再逐步把资源接入到 Context 系统
4. 再接入长期记忆与检索
5. 最后再做 `AiChatService` 的上下文消费重构
