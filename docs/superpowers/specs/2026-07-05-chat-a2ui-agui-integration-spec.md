# Spec: 真实聊天接入 A2UI 生成式 UI + 后端事件重设计

## Objective

现在的 AI 聊天(`mobile/lib/page/chat/`)只能渲染纯文字和硬编码的工具调用卡片(`ChatToolCallCard`)。目标是让 AI 助手的每一轮回复都能像 `mobile/lib/demo/a2ui/` 里验证过的 demo 一样,用 A2UI 声明式 UI 混排文字与交互组件(卡片、选择器、按钮),同时后端的 SSE 事件从现在过于粗糙的 `delta`/`done`/`paused`/`error` 四件套,重设计为一套更细粒度的自定义事件(参考 AG-UI 的事件词汇,但不依赖 AG-UI SDK)。

用户是本项目维护者本人,直接使用真实聊天功能验收。成功标准是:AI 一轮回复里能同时出现文字段落和至少一个交互卡片,顺序符合 AI 的实际生成顺序,刷新/重新打开聊天后原样复现,且不引入 AG-UI/A2UI 的第三方 Java 依赖(因为查证过没有可用的)。

## 决策记录(含依据)

以下决策已经和用户逐条讨论确认,记录决策依据是为了以后回看时知道"为什么这么做",而不是重新猜测。

### D1. 后端不采用 AG-UI 的字面线上协议,也不引入 AG-UI 的 Java/Kotlin SDK

**依据**:
- 直接查了 Maven Central:`com.ag-ui` 分组下只有 `community/` 子路径,`com.ag-ui:core/client/http:0.0.1`(官方 Java SDK 文档里写的坐标)完全没有发布,解析会 404。
- `ag-ui-protocol/ag-ui` 仓库里 `sdks/community/java/` 确实有源码(含 `spring`、`spring-ai` 集成模块),但从未发布到任何公开仓库。
- 官方 A2UI+AG-UI 集成技能(`ag-ui-protocol/ag-ui/skills/ag-ui-a2ui-integration/SKILL.md`)里,`@ag-ui/a2ui-middleware` 是纯 JS/TS 包,框架适配器列表(ADK/LangGraph/CrewAI/Mastra/Pydantic AI/LlamaIndex/Agno/AG2)里没有 Java/Spring。
- 本 App 是唯一的消费方,不需要和 CopilotKit 等通用 AG-UI 客户端互通,严格对齐协议字面格式没有实际收益。

### D2. 后端仍然重设计事件粒度,但是"AG-UI 风格的自定义事件",不是 AG-UI 协议本身

**依据**:
- 现有 `delta`/`done`/`paused`/`error`(`backend/.../ChatSseEventFactory.java`)对"文字流"和"工具调用"不分,用户认为太粗糙。
- AG-UI 官方事件词汇(`ag-ui/docs/concepts/events.mdx`,已完整读取)分七大类:生命周期(`RunStarted`/`RunFinished`/`RunError`/`StepStarted`/`StepFinished`)、文本消息(`TextMessageStart/Content/End`)、工具调用(`ToolCallStart/Args/End/Result`)、状态同步(`StateSnapshot`/`StateDelta`/`MessagesSnapshot`)、活动(`ActivitySnapshot`/`ActivityDelta`,A2UI 内容官方就是走这里,`activityType: "a2ui-surface"`)、特殊(`Raw`/`Custom`)、推理(`Reasoning*`)。这套分类作为后端新事件设计的命名/结构参考。
- 验证了 Spring AI 2.0(当前线上版本,`docs.spring.io/spring-ai/reference` 侧边栏确认)具备实现这套粒度所需的钩子:`StreamAdvisor`/`ChatClientMessageAggregator` 能在工具调用参数还在流式生成、尚未聚合完成时就拿到原始 chunk 并转发给自己的订阅者(官方文档原话确认),文本流的 Start/Content/End 直接对应 `Flux<ChatClientResponse>` 的分块。因此不需要 AG-UI SDK,靠 Spring AI 现成的拦截点就能手搭一套等价粒度的事件。
- **Reasoning 类事件已验证可行,纳入范围**:查了 Spring AI 的模型集成文档——DeepSeek R1/vLLM reasoning parser 的流式响应里,每个 chunk 的 `message.getMetadata().get("reasoningContent")` 就是推理内容的增量(官方示例代码就是逐块累加进 `StringBuilder`,跟 `ReasoningMessageContent` 的 delta 累加是同一形状);Anthropic 扩展思考在流式模式下"thinking"和"signature"也是分块到达("Thinking is fully supported in streaming mode"),其"redacted thinking block"(`data` 字段,安全过滤后的推理内容)对应 AG-UI 的 `ReasoningEncryptedValue`。三个主流模型集成都有现成支撑,不需要额外查证。

### D7. 工具返回的 A2UI JSON 自动进入模型对话历史,不需要额外设计"摘要 vs 全量 JSON"

**依据**:
- 工具调用的返回值被自动加入对话历史、喂给模型继续生成,是任何 agent 框架(包括 Spring AI,`ToolCallingManager.executeToolCalls` 的结果通过 `result.conversationHistory()` 带入下一次 prompt)默认就有的行为,不是需要我们额外搭建的能力。
- 用官方 dojo 里真实存在的 `a2ui_fixed_schema` demo(`ag-ui/apps/dojo/src/mastra/agents/a2ui-fixed.ts`)验证:`search_flights` 工具的 `execute` 直接返回 `a2ui_operations` envelope,agent 的系统提示词写着"调用工具后不要复述/总结数据,工具已经自动渲染了富 UI,只需简短说一句"——这句话成立的前提就是模型已经从工具返回值里知道了数据是什么。
- 因此:**不做额外的"摘要"设计**。工具返回什么,模型上下文里就有什么;客户端落库存的是同一份最终 JSON。用户后续追问"刚才选的哪个"时,模型能回答,靠的是工具结果本来就在它的对话历史里,不需要额外机制。
- 用户交互产生的选择(比如点击卡片按钮触发的 `event`)会作为一次新的往返消息进入对话历史,agent 处理后如果要更新卡片状态,是对同一个 Surface 再发一次 `updateDataModel`——不需要为"记录用户选择"单独设计存储字段。

### D3. 废弃 `ChatToolCallCard` 硬编码卡片渲染,工具调用产生的结构化内容统一走 A2UI Surface 渲染

**依据**: A2UI 是通用声明式渲染器,继续维护一套并行的硬编码 Flutter 卡片渲染没有必要,重复维护两条"结构化内容"渲染路径不划算。

### D4. 一轮 AI 回复(文字 + 卡片 + 文字...)合并为**一个** A2UI Surface,而不是拆成多条独立消息按 `messageType` 分支渲染

**依据**:
- A2UI 的设计本意就是"一个 Surface 描述一次完整呈现",文字与组件的先后顺序靠组件树的 `children` 列表天然表达——这正是 `mobile/lib/demo/a2ui/a2ui_stream_api_service.dart` 已经验证可行的模式(`createSurface` 建一次,后续 `updateComponents`/`updateDataModel` 增量更新同一个 surface)。
- 如果文字和卡片继续拆成独立消息行,等于在"消息列表的行顺序"上重新发明一套排序/编排逻辑去模拟 A2UI 组件树本来就有的能力。
- 合并后 `ChatMessage.messageType` 的渲染分支反而变少:`USER` 不变,`ASSISTANT` 统一渲染为一个 Surface,不再需要 `TEXT`/`TOOL_CALL`/`TOOL_RESULT` 四路分支。
- 查了 `a2ui/docs/reference/components.md`:标准 `Text` 组件只有纯字符串 + `variant`,协议本身不定义 markdown 语义。demo 里已经写好了自定义 catalog 组件 `StreamingMarkdownCatalogItem`(`mobile/lib/demo/a2ui/streaming_markdown_catalog_item.dart`)解决这个问题,可以直接复用,不需要重新开发。
- **Surface 的生命周期覆盖"AI 出卡片 → 用户交互 → AI 据交互继续更新同一 Surface"整段**,不是卡片一出现就算这轮结束。只有整段都跑完,才落库存最终 JSON——理由见 D5 和 D7。

### D5. 持久化只存"最终态 JSON",不存流式过程

**依据**:
- 现状本来就是这样——探索确认 `ChatMessage.content` 存的是完整文本,不是逐字 delta 回放,`ChatSendState.streaming` 只是内存态,不落库。UI Surface 沿用同一模式。
- `deleteSurface` 语义是"这个画布不再存在"(生成过程中推翻重建的中间状态),不是"用新数据替换旧数据"那种更新——`updateComponents`/`updateDataModel` 才是替换/更新。因此被 `deleteSurface` 掉的中间产物从不落库,只有一轮回复结束时存活的那个 Surface 的最终 JSON 会被持久化。
- 后端和客户端两边都存:后端存一份作为自己对话历史的真相来源(`syncMessages` 的校验源头,也是模型下一轮的上下文来源),客户端存 Isar 做离线/秒开复现。两边存的都是最终 JSON,reload 时直接把 JSON 一次性喂给新建的 `SurfaceController`,不重新走流式过程。

### D6. A2UI 协议版本用 v0.9.1(不用 v1.0)

**依据**: `a2ui-authoring` skill 明确"默认用 v0.9.1,因为文档标注它是当前生产版本",且本次不需要 v1.0 才有的 `actionResponse`/`callFunction`/inline `dataModel` 等特性。demo 现在用的也是 v0.9,保持一致。

### D8. 不做历史数据迁移/兼容,直接改

**依据**: 用户明确决定不需要考虑旧版 `TEXT`/`TOOL_CALL`/`TOOL_RESULT` 消息的兼容或迁移,直接把渲染逻辑和数据模型改成新的一套。旧格式的历史消息如何处理不在本次范围内。

## 范围边界

**本次覆盖**:
- 后端事件从 4 种粗粒度事件重设计为 AG-UI 风格的细粒度自定义事件,**含 Reasoning 类事件**(D2 已验证可行)
- 后端新增"生成 A2UI 卡片"的工具调用能力(fixed-schema 模式:工具直接返回 `a2ui_operations` envelope)
- 客户端 `ChatMessage` 数据模型 + Isar 持久化改动,支撑"一轮回复 = 一个 Surface"
- 客户端消息列表渲染改为统一走 `genui` 的 `Surface`/`SurfaceController`,废弃 `ChatToolCallCard`
- 端到端可验证的分步实施(每步都能独立验证,不要求一次性完工)

**本次不覆盖(超出范围,需要另开工作)**:
- 对 AG-UI/A2UI 协议字面格式的严格合规(D1 已否决)
- 历史消息迁移(D8 已决定不做)

## 数据模型改动(客户端)

- `ChatMessage`(`mobile/lib/model/chat_message.dart`):`messageType` 增加新取值表示"这是一个 A2UI Surface 载体"(命名待 PLAN 阶段定,例如 `UI_SURFACE` 或直接让 `ASSISTANT` 角色的消息默认按此解释);`content` 字段存最终态的 A2UI 消息数组(JSON 字符串)。
- 沿用现有的 messageType 判别 + 可选 side-channel 元数据模式(`ToolCallData`/`toolData` 是既有先例),不额外发明新范式。
- 编辑/重新生成/分支(`chat_providers.dart` 的 `editMessage`/`regenerate`/`ChatBranchChip`)目前只按 `parentUuid`/`activeLeafUuid` 走,不检查 `content` 形状,理论上不受影响,但**需要在 PLAN 阶段针对"重新生成一个 Surface 消息"走一遍这些流程确认没有隐藏假设**。

## 后端事件改动

- 用 Spring AI 2.0 的 `StreamAdvisor` + `ChatClientMessageAggregator` 包一层,替换现有 `ChatSseEventFactory`/`SseReplyService` 的四件套。
- 新事件集合(参考 AG-UI 命名,自定义实现,不引入 AG-UI 依赖):生命周期类比 `RunStarted`/`RunFinished`/`RunError`;文本类比 `TextMessageStart/Content/End`;工具调用类比 `ToolCallStart/Args/End/Result`;A2UI 内容类比 `ActivitySnapshot`(`activityType: "a2ui-surface"`);推理类比 `ReasoningStart`/`ReasoningMessageStart/Content/End`(源数据来自 Spring AI 模型集成暴露的 `reasoningContent`/`ThinkingBlock` 流式增量,D2 已验证)。具体字段结构在 PLAN 阶段定稿。
- A2UI 卡片生成走 fixed-schema 模式:定义一个 `@Tool` 方法,返回值直接是 `a2ui_operations` envelope(`createSurface`/`updateComponents`/`updateDataModel`),由包装层识别这个工具的返回值形状后,发一个 A2UI 专用事件给客户端。工具的返回值仍按 Spring AI 默认行为进入模型对话历史(D7),不做额外拦截/摘要。

## 客户端渲染改动

- `chat_message_widgets.dart` 的 `ChatMessageBubble` 不再按 `messageType == 'TOOL_CALL'` 分支到 `ChatToolCallCard`,改为:USER 消息保持现状,ASSISTANT 消息统一渲染一个绑定该消息 `SurfaceController` 的 `Surface`。
- `ChatStreamingBubble`(直播态)需要从"只认 `String content`"改造为能驱动一个临时 `SurfaceController` 实时渲染,直播结束后把最终 JSON 落到 `ChatMessage.content`。
- Markdown 段落复用 demo 里已经写好的 `StreamingMarkdownCatalogItem`,不重新开发。

## 项目结构(受影响文件)

```
mobile/lib/model/chat_message.dart              → messageType 新增取值
mobile/lib/api/models/chat_models.dart          → 新事件的 Dart 侧解析
mobile/lib/api/chat_api_service.dart            → _parseSseStream 改造
mobile/lib/service/chat_service.dart            → 透传新事件类型
mobile/lib/providers/chat_providers.dart        → _consumeStreamEvents 改造
mobile/lib/page/chat/widgets/chat_message_widgets.dart → 渲染改为 Surface
mobile/lib/demo/a2ui/streaming_markdown_catalog_item.dart → 原样复用(可能需要移出 demo 目录到共享位置)
backend/.../ai/application/stream/ChatSseEventFactory.java → 事件重设计
backend/.../ai/application/stream/SseReplyService.java     → 配合新事件
backend/.../(新增) A2UI 卡片生成工具类
```

## 测试策略

- 客户端:`flutter analyze` + `flutter test` 覆盖新增的 messageType 渲染分支;沿用 demo 已有的手动验证方式(在真实聊天页面里先塞假数据验证 Surface 渲染,再接后端真实事件)。
- 后端:沿用现有测试框架(`./mvnw test`),新增 Advisor/事件重设计的单元测试。
- 每一步(见下方 PLAN 阶段的任务拆分)要求独立可验证,不接受"写完一大批再统一验证"。

## 边界(Always / Ask First / Never)

- **Always**:每步改动后跑对应测试/`flutter analyze`;新事件设计先在 mock 层验证通过,再接真实后端;工具返回的 A2UI JSON 按框架默认行为进入模型对话历史,不额外拦截或改写。
- **Ask first**:后端事件的具体字段命名定稿前;删除 `ChatToolCallCard` 相关代码前确认没有其他调用点。
- **Never**:引入不存在的 AG-UI Java/Kotlin 依赖;为兼容旧版 `TEXT`/`TOOL_CALL`/`TOOL_RESULT` 数据格式做特殊处理(D8 已决定不做);一次性大改到不可回退的中间状态。

## Success Criteria

- 真实聊天里,AI 一轮回复能在文字中间插入至少一种交互卡片,顺序与 AI 生成顺序一致。
- 关闭并重新打开该聊天会话,卡片和文字原样复现,不需要重新请求后端。
- 后端新事件集合有对应的单元测试,`ChatToolCallCard` 相关代码被移除且没有遗留引用。
- 整个过程分阶段交付,每个阶段都有独立可验证的产出(不是一次性大爆炸式改动)。

## Open Questions

1. **新 messageType 的具体命名和取值设计**:是新增一个值,还是让 `ASSISTANT` 角色默认就是 Surface 载体(即弱化 `messageType` 这个字段本身的必要性)?留到 PLAN 阶段定稿。
2. **`ChatStreamingBubble` 直播态渲染的具体实现方式**(临时 `SurfaceController` 的生命周期管理——何时创建、何时把最终状态搬运到持久化的 `ChatMessage`)留到 PLAN 阶段细化,概念上已经理清(见"客户端渲染改动"一节)。
