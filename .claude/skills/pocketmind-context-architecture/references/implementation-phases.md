# 分阶段实施计划

## Phase 1：现有错误设计清理
目标：移除明确错误或会阻碍后续架构演进的设计。

包括：
- 删除 `ChatSession.memorySnapshot`
- 清理持久化字段、测试、schema、引用逻辑
- 保证编译、单测、启动通过

## Phase 2：上下文最小骨架
目标：在单体内建立可服务化的上下文模块骨架。

包括：
- 新增 `context` / `resource` / `memory` / `skill` 包结构
- 定义基础枚举和值对象
- 定义最小 service/repository 接口
- 增加第一版 schema 骨架
- 不接入完整业务流

## Phase 3：Resource 接入
目标：让 AI 可读内容有正式归宿。

包括：
- 定义 `ResourceSourceType`
- 把 `WEB_CLIP`、`NOTE_TEXT`、`OCR_TEXT`、`PDF_TEXT`、`MARKDOWN_TEXT`、`CHAT_TRANSCRIPT` 归入 Resource
- 保持 Note 仍是客户端主读模型
- 让旧 `preview*` 成为 projection

## Phase 4：Memory 接入
目标：形成用户长期记忆体系。

首版只支持：
- `profile`
- `preferences`
- `entities`
- `events`

包括：
- memory record
- extraction service
- query service
- 去重与幂等策略

## Phase 5：Skill 与 Context 消费重构
目标：把多租户 AI skills 与上下文统一接入聊天链路。

包括：
- `tenant skills`
- `AiChatService` 拆分
- context 查询和 prompt 组装分离
- retrieval/query service 接入

## 每阶段验收要求
每个阶段必须满足：
1. 编译通过
2. 相关单测通过
3. 项目可以启动
4. 不破坏未涉及的现有主流程
