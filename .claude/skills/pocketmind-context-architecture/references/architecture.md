# PocketMind Context Architecture

## 目标
构建可独立服务化的上下文系统，借鉴 OpenViking 的 `resources / user memories / agent skills / agent memories` 语义，但保留 PocketMind 现有产品模型：`Note`、`ChatSession`、`ChatMessage`、`Asset`。

## 核心原则
1. `Note` 仍是客户端主读模型，不整体文件化。
2. 分享帖子抓取正文主存放数据库，保证展示、搜索、同步性能。
3. `Asset` 只负责物理文件和媒体原件。
4. `Resource` 负责 AI 可读内容：网页正文、OCR 文本、PDF/MD 提取文本、聊天归档文本。
5. `Memory` 负责从 `Resource + Chat` 中提取用户偏好、习惯、实体、事件。
6. `Skill` 负责多租户 AI 能力定义，不承载用户内容。
7. `previewTitle`、`previewDescription`、`previewContent`、`summary` 在过渡期保留为投影字段，不再是长期真相源。
8. `memorySnapshot` 应直接废弃。

## 顶层语义模型
- `pm://users/{userId}/resources/`
- `pm://users/{userId}/memories/`
- `pm://agents/{agentId}/skills/`
- `pm://agents/{agentId}/memories/`
- `pm://sessions/{sessionId}/`

## 分层说明
### 业务主数据层
- `Note`
- `ChatSession`
- `ChatMessage`
- `Asset`

### 上下文系统层
- `Resource`
- `Memory`
- `Skill`
- `ContextCatalog`
- `ContextRef`

## Note 存放策略
### 纯文本笔记
- `title/content` 在数据库
- 可同步、可搜索、可直接给客户端展示

### 分享帖子笔记
- `sourceUrl` 在数据库
- `previewTitle/previewDescription/previewContent` 在数据库，作为客户端读取投影
- 同时异步生成对应 `Resource`

## Resource 存放策略
### 必须 DB 优先的资源
- 抓取正文
- OCR 结果文本
- Chat transcript / 归档片段

### 可走 Asset + 解析的资源
- PDF
- Markdown 文件
- 图片/音视频原件

## Memory 分类
- `profile`
- `preferences`
- `entities`
- `events`
- 后续扩展：`cases`、`patterns`

## Skill 定位
- 多租户 AI skills
- Prompt 模板
- Tool 使用策略
- 工作流与系统能力说明

## 阶段验收要求
每个阶段必须满足：
1. 编译通过
2. 相关单测通过
3. 项目可启动
4. 不破坏现有移动端主流程
