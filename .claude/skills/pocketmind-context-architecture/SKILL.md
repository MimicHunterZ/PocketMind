---
name: pocketmind-context-architecture
description: 设计、重构和实现 PocketMind 项目中的整体上下文架构（Context Architecture），用于统一规划和落地 resources、user memories、agent memories、tenant skills、session、retrieval、ingestion、storage 与现有 Note/Chat/Asset 的边界。当用户要求为 PocketMind 新增长期记忆、重构 AI 上下文体系、借鉴 OpenViking 的上下文类型/层级/URI/存储/检索/会话思想，或需要分阶段实施 Context Service 时使用。
---

# PocketMind Context Architecture

本 Skill 用于在 PocketMind 中设计和实施“整体上下文系统”。

目标不是简单增加几个字段，而是建立一套长期可演进的 Context Architecture，使项目最终具备：

- 面向产品的主业务模型：`Note` / `ChatSession` / `ChatMessage` / `Asset`
- 面向 AI 的上下文模型：`Resource` / `Memory` / `Skill` / `Session` / `Retrieval`
- 面向未来独立服务化的清晰边界
- 借鉴 OpenViking 的上下文语义，但不盲目照搬其实现细节

## 核心原则

1. 先纠偏，再扩展。
2. `Note` 不整体文件化。
3. `Asset` 只负责物理文件与二进制原件。
4. `Resource` 负责 AI 可读内容。
5. `Memory` 负责长期学习结果。
6. `Skill` 负责多租户 AI 能力定义。
7. 上下文系统必须可独立服务化。
8. 每个大阶段都必须通过编译、单测和启动验证。

## 开始工作时先读这些参考资料

- 架构总览： [references/architecture-overview.md](references/architecture-overview.md)
- 分阶段计划： [references/implementation-phases.md](references/implementation-phases.md)
- 数据职责边界： [references/data-boundaries.md](references/data-boundaries.md)
- 存储与检索： [references/storage-and-retrieval.md](references/storage-and-retrieval.md)
- OpenViking 映射规则： [references/openviking-mapping.md](references/openviking-mapping.md)

## 执行要求

每进入一个新阶段，都要：

1. 明确本阶段目标
2. 明确本阶段不做什么
3. 只改当前阶段必要文件
4. 运行编译、相关单测、启动验证
5. 总结结果，再进入下一阶段

## 项目约束

- 遵守 PocketMind 后端分层规范
- 所有注释使用中文
- 不重新引入 `memorySnapshot` 这类大字符串快照设计
- 不把客户端主查询路径改成“先查文件再查数据库”
- 不在没有过渡读模型时删除客户端仍依赖的 `preview*` / `summary`

## 交付要求

给用户的输出应包含：

- 当前阶段目标与结果
- 修改文件清单
- 编译 / 单测 / 启动验证结果
- 下一阶段计划
- 关键架构选择说明
