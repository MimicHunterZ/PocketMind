---
name: mobile-ai-chat-client
description: PocketMind 移动端 AI 对话实现规范（Riverpod + Isar + SSE + Markdown 流式渲染）。当用户要求实现/新增聊天会话、消息流式展示等相关功能时触发。
---

# Mobile AI Chat Client（PocketMind）

本 Skill 用于在 PocketMind `mobile/` 中稳定实现和维护 AI 聊天能力，确保代码与现有架构一致：
- Clean Architecture 分层不越界
- UI 持久化驱动（Isar stream）
- Riverpod 3 + `@riverpod` 代码生成
- 流式 Markdown 可读且稳定

## 触发场景

当用户提出以下需求时使用：
- 「点击 note 进入 AI 会话」/「会话不要重复创建」
- 「聊天页流式渲染错乱、先叠在一起、最后才正常」
- 「AI 回复支持 Markdown」
- 「键盘弹出遮挡输入框」
- 「统一用项目封装 AppBar」

## 当前实现基线（必须对齐）

### 1) 会话与消息数据链路

- 会话仓库：`mobile/lib/data/repositories/isar_chat_session_repository.dart`
  - `watchSessions({String? noteUuid})`
  - `findByUuid(String uuid)`
  - `findByNoteUuid(String noteUuid)`（用于 note -> session 精确查询，避免 stream 时序问题）
- 消息仓库：`mobile/lib/data/repositories/isar_chat_message_repository.dart`
- 业务层：`mobile/lib/service/chat_service.dart`
  - `syncSessions` / `createSession` / `syncMessages` / `streamMessage`
- Provider：`mobile/lib/providers/chat_providers.dart`
  - `chatSessionsProvider(noteUuid)`
  - `chatMessagesProvider(sessionUuid)`
  - `chatSessionByUuidProvider(uuid)`
  - `chatSendProvider(sessionUuid)`

### 2) Note -> Chat 跳转策略

入口逻辑在：`mobile/lib/page/home/note_detail_page.dart` `_goToSessionPressed()`

严格顺序：
1. 先查本地 Isar：`chatSessionRepositoryProvider.findByNoteUuid(noteUuid)`
2. 本地无 -> `chatServiceProvider.syncSessions(noteUuid: noteUuid)`
3. 再查本地仍无 -> `chatServiceProvider.createSession(noteUuid: noteUuid)`
4. 最终 `context.push(RoutePaths.chatOf(sessionUuid))`

> 禁止直接依赖 `chatSessionsProvider(...).asData?.value` 作为唯一判断依据来决定是否创建会话。

### 3) 聊天页 UI 规范

文件：`mobile/lib/page/chat/chat_page.dart`

- 顶栏必须使用 `PMAppBar`（`mobile/lib/page/widget/pm_app_bar.dart`）
- 不显示用户/AI 头像
- 发送时立即显示用户消息（乐观 UI）
  - 使用 `ChatSendState.streaming.pendingUserMessage`
  - 渲染 `_PendingUserBubble`
- AI 流式与最终消息都走统一 Markdown 组件
  - `mobile/lib/page/widget/markdown_text.dart`
- 键盘适配
  - `Scaffold(resizeToAvoidBottomInset: true)`

### 4) Markdown 流式渲染规范

复用组件：`mobile/lib/page/widget/markdown_text.dart`

必须包含：
- `isStreaming` 模式
- 流式文本预处理 `_sanitize`（至少处理未闭合代码围栏）
- `ValueKey(isStreaming)` 强制流式/完成态切换时重建
- 流式阶段建议 `selectable: false`，完成态再开启选中

## Riverpod 3.0 约束（关键）

在 `@riverpod` 代码生成模式中，family 参数写法必须为：

```dart
@riverpod
class ChatSend extends _$ChatSend {
  @override
  ChatSendState build(String sessionUuid) => const ChatSendState.idle();
}
```

不要写成 required constructor 参数（那是手写 `NotifierProvider.family` 的模式）。

## 分层约束（PocketMind 特有）

- UI / Provider 不直接操作 Isar transaction
- Repository 负责数据库访问
- Service 负责编排 API + Repository
- UI 展示以 Isar stream 为准，不以网络响应直接驱动最终列表

## 前后端协同契约（SSE / Markdown）

### 客户端已可独立处理
- 按 token/delta 逐步累积展示
- Markdown 基础语法流式可读
- 未闭合代码围栏容错

### 建议后端配合（推荐）

1. SSE 事件边界清晰：
   - `delta`（文本增量）
   - `done`（流结束）
   - `error`（错误）
2. `delta` 不要切分 UTF-16 surrogate 对 / emoji 中间字节
3. 若可控，优先按“语义片段”切块（句子/段落）而非超细粒度字符
4. `done` 时保证服务端持久化可被 `syncMessages(sessionUuid)` 立即读取

## 变更执行清单（每次改聊天功能都要走）

1. 修改代码（仅在目标层）
2. 若改了 Freezed/Riverpod 注解：
   - `flutter pub run build_runner build --delete-conflicting-outputs`
3. 运行静态分析（最小范围）：
   - `dart analyze lib/page/chat/chat_page.dart lib/providers/chat_providers.dart lib/service/chat_service.dart lib/data/repositories/isar_chat_session_repository.dart lib/page/widget/markdown_text.dart`
4. 确认交互：
   - note 点击后复用旧会话
   - 发送后立即看到用户气泡
   - AI 流式内容实时换行/代码块不堆叠
   - 键盘弹出不遮挡输入区

## 常见回归问题与修复

### 问题 A：每次进入都新建会话
- 原因：读取 stream provider 的时序导致拿到旧值
- 修复：改用 `findByNoteUuid` + `syncSessions` 二次查询

### 问题 B：流式文本先叠在一起，结束后才正常
- 原因：流式阶段 Markdown 语法不完整 + Widget 状态残留
- 修复：`MarkdownText(isStreaming: true)` + `_sanitize` + `ValueKey(isStreaming)`

### 问题 C：软键盘挡住输入区
- 原因：页面未随 inset 重新布局
- 修复：`Scaffold(resizeToAvoidBottomInset: true)` 并保持底部输入区在 body 内

## 输出要求（给用户的交付）

- 明确列出修改文件
- 明确说明是否涉及 build_runner
- 给出 `dart analyze` 结果
- 若涉及流式协议改动，明确“是否需要后端配合”以及契约点
