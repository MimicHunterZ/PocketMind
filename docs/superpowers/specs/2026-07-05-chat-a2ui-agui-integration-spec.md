# Spec: 真实聊天接入 A2UI 生成式 UI + 后端事件重设计

## Objective

现在的 AI 聊天(`mobile/lib/page/chat/`)只能渲染纯文字和简陋的工具调用提示(`ChatToolCallCard` 只显示一行"调用工具中…")。目标是让 AI 助手的一轮回复能按"块序列"混排:文字段落(md)+ 工具调用记录(可展开)+ A2UI 声明式交互卡片(选择器、按钮等,像 `mobile/lib/demo/a2ui/` 里验证过的 demo),顺序符合 AI 的实际生成顺序;同时后端的 SSE 事件从现在过于粗糙的 `delta`/`done`/`paused`/`error` 四件套,重设计为一套更细粒度的自定义事件(对齐前端已依赖的 `ag_ui ^0.3.0` Dart 包的事件格式,但后端不依赖任何 AG-UI Java SDK)。

用户是本项目维护者本人,直接使用真实聊天功能验收。成功标准是:AI 一轮回复里能同时出现文字段落和至少一个交互卡片,顺序符合 AI 的实际生成顺序,刷新/重新打开聊天后文字、工具调用、卡片都原样复现,且不引入 AG-UI/A2UI 的第三方 Java 依赖(查证过没有可用的)。

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
- AG-UI 官方事件词汇(`ag-ui/docs/concepts/events.mdx`,已完整读取)分七大类:生命周期(`RunStarted`/`RunFinished`/`RunError`/`StepStarted`/`StepFinished`)、文本消息(`TextMessageStart/Content/End`)、工具调用(`ToolCallStart/Args/End/Result`)、状态同步(`StateSnapshot`/`StateDelta`/`MessagesSnapshot`)、活动(`ActivitySnapshot`/`ActivityDelta`,A2UI 内容据 AG-UI 网页文档走这里,`activityType: "a2ui-surface"`)、特殊(`Raw`/`Custom`)、推理(`Reasoning*`)。这套分类作为后端新事件设计的命名/结构参考。
- **Spring AI 2.0 流式工具调用能力:框架层面文档支持,但本项目尚未实测。** Spring AI 1.0 早期流式不支持内部工具执行循环;2.0 的 `ChatClient.stream()` 配合自动注册的工具 advisor 支持流式下的工具调用。本项目现有代码(`SseReplyService.buildContentFlux` 已向流式请求注入 `toolCallbacks`,并挂 `PersistingToolCallAdvisor` 做工具调用持久化)意图就是走这条路,**但该后端代码是从 Spring AI 1.x 迁到 2.0 的产物,部分写法尚未改完,迁移后从未启动运行过,因此"流式+工具能正常跑"目前是代码意图、不是已验证事实**。因此 PLAN 的第一个 spike(Task 2.1)的首要目标是先把"迁移后的流式+工具路径能否正常跑起来"验证掉,再谈加事件粒度。文本流的 Start/Content/End 直接对应流式分块,风险低。
- **`StreamAdvisor`/`ChatClientMessageAggregator`/`toolCallingAdvisorAutoRegister` 等具体 API 名称待 spike 时以代码/IDE 为准核实,不以本文档或联网文档转述为准**(联网文档在"流式工具"这一细节上多次给出自相矛盾的解读,不可信)。方向是:优先保留现有"框架托管"模式(工具自动执行 + `PersistingToolCallAdvisor` 自动持久化),只把流式返回从"仅文本"扩展到"能识别工具调用并发细粒度事件";只有当框架托管拿不到所需粒度时,才评估切换到"用户托管"手动聚合循环(那会牵扯持久化 advisor 迁移,见 D9)。
- **Reasoning 类事件本次不做**(见 D10):本项目只对接 OpenAI 兼容 API,原先关于 DeepSeek/Anthropic 推理内容的论证与本项目接入方式不符,移出范围。

### D7. 工具返回的 A2UI JSON 自动进入模型对话历史,不需要额外设计"摘要 vs 全量 JSON"

**依据**:
- 工具调用的返回值被自动加入对话历史、喂给模型继续生成,是任何 agent 框架(包括 Spring AI,`ToolCallingManager.executeToolCalls` 的结果通过 `result.conversationHistory()` 带入下一次 prompt)默认就有的行为,不是需要我们额外搭建的能力。
- 用官方 dojo 里真实存在的 `a2ui_fixed_schema` demo(`ag-ui/apps/dojo/src/mastra/agents/a2ui-fixed.ts`)验证:`search_flights` 工具的 `execute` 直接返回 `a2ui_operations` envelope,agent 的系统提示词写着"调用工具后不要复述/总结数据,工具已经自动渲染了富 UI,只需简短说一句"——这句话成立的前提就是模型已经从工具返回值里知道了数据是什么。
- 因此:**不做额外的"摘要"设计**。工具返回什么,模型上下文里就有什么;客户端落库存的是同一份最终 JSON。用户后续追问"刚才选的哪个"时,模型能回答,靠的是工具结果本来就在它的对话历史里,不需要额外机制。
- 用户交互产生的选择(比如点击卡片按钮触发的 `event`)会作为一次新的往返消息进入对话历史,agent 处理后如果要更新卡片状态,是对同一个 Surface 再发一次 `updateDataModel`——不需要为"记录用户选择"单独设计存储字段。

### D3. 一轮 AI 回复 = 有序的"块"序列,按消息类型各自渲染;不合并成单一 Surface

**核心模型(经与用户反复讨论定稿,替代早期的"合并成一个 Surface"设想)**:
- 一轮 AI 回复本质是一个**有序块序列**:`(思考) + 文本 + 工具调用 + 文本 + 工具调用 + ...`。这正是 LLM 实际吐出来的形状,也正是后端 `PersistingToolCallAdvisor` 现在**已经**按多条独立 `ChatMessageEntity`(用 `parentUuid` 串联)持久化的形状。
- 每个块按自己的类型渲染,**不强行合并**:

  | 块 | 消息类型 | 渲染 |
  |---|---|---|
  | 用户输入 | USER `TEXT` | 用户气泡 |
  | AI 文本 | ASSISTANT `TEXT` | Markdown(复用现有 `StreamingTextMarkdown`) |
  | 普通工具调用(bash/搜记忆等) | `TOOL_CALL`/`TOOL_RESULT` | 折叠的工具卡片(可展开看结果) |
  | A2UI 卡片工具 | `TOOL_RESULT`(content 是 A2UI JSON) | A2UI `Surface` |
  | 思考 | (D10 本次不做) | — |

- **关键洞察(用户提出)**:"生成卡片"本身也是一次工具调用,只是这个特殊工具的**返回结果是一段 UI(A2UI JSON)**。所以卡片不是独立于工具调用的东西,而是"结果恰好是 UI 的工具调用"。因此**不需要新增 `UI_SURFACE` messageType**——卡片就是一条 `TOOL_RESULT`,其 `content` 是 A2UI envelope JSON。

**为什么放弃"合并成一个 Surface"(原 D4)**:
- 原 D4 反对"拆成多条消息"的理由是"会在消息列表行顺序上重新发明排序逻辑"——但这是稻草人:多条消息本来就有 `parentUuid` 链天然定序,不需要重新发明任何东西。
- 原 D4 唯一硬的理由是"卡片交互后 AI 原地更新同一 Surface"——但那个需求**只要求「卡片」是 Surface,不要求「文本」也包进 Surface**。文本不需要被 `updateDataModel` 更新。
- 合并方案的代价:要把 LLM 吐的纯文本流**翻译成 A2UI `updateComponents` 操作**塞进 Surface,还要替换掉现在已经能跑的 `StreamingTextMarkdown` 流式渲染。多此一举。
- 结论:文本就是文本(md),Surface 只是"某次工具调用结果的一种呈现"。这比合并方案简单一大截,且贴合前后端数据的自然形状。

### D4. 前端识别"哪条 `TOOL_RESULT` 是 A2UI 卡片":靠 `A2uiMessage.fromJson` 试解析(已核实 genui 包能力)

**依据(已核实 `genui ^0.8.0` 包源码)**:
- `genui` 的 `A2uiMessage.fromJson()`(`lib/src/model/a2ui_message.dart:20-87`)**严格校验**:JSON 必须有 `"version": "v0.9"` + 恰好一个 `createSurface`/`updateComponents`/`updateDataModel`/`deleteSurface` 键,否则抛 `A2uiValidationException`。
- 因此前端拿到一条 `TOOL_RESULT`,试着 `A2uiMessage.fromJson`:成功 → 是 A2UI 卡片,渲染 `Surface`;抛异常 → 是普通工具结果,渲染折叠工具卡片。**不需要额外的类型标记字段**(但若嫌 try/catch 丑,后端可在事件里带一个 `activityType: "a2ui-surface"` 标记辅助判别,见 D11)。
- 包里还提供 `a2uiMessageSchema()`(`a2ui_message.dart:89-123`)可做更严格的 schema 校验。
- 渲染路径已被 demo(`surface_handoff_lifecycle_demo_page.dart:84-91`)和 Task 1.3a spike 验证:同步 `A2uiMessage.fromJson()` + `SurfaceController.handleMessage()` 灌入,不走 `addChunk` 异步管线,避免空白帧。

### D5. 持久化只存"最终态 JSON",不存流式过程;工具调用(含卡片)前后端都落库、reload 复现

**依据**:
- 现状:`ChatMessage.content` 存完整文本,不是逐字 delta 回放,`ChatSendState.streaming` 只是内存态,不落库。沿用同一模式。
- **过渡态 vs 最终态要分清**(用户强调):流式时"🔧 正在执行中…"这种**进度动画是过渡态,不落库**;但工具调用的**事实 + 结果(调了什么、返回什么)是最终态,必须落库并 reload 可复现**。
- **前端也落库(用户确认)**:前端 Isar 从后端 `syncMessages` 拉全部消息(含 `TOOL_CALL`/`TOOL_RESULT`),reload 后历史里的工具调用和卡片原样复现。前后端都存最终 JSON。
- 卡片(A2UI `TOOL_RESULT`)reload 时:直接把存的 A2UI JSON 用 `A2uiMessage.fromJson` + `handleMessage` 一次性灌进新建的 `SurfaceController`,不重新走流式(D4)。
- `deleteSurface` 语义是"画布不再存在"(生成中推翻重建的中间态),这种中间产物不落库;只有一轮结束时存活的最终态落库。

### D6. A2UI 协议版本用 v0.9.1(不用 v1.0);卡片交互支持"本地处理"和"往返 AI"两种,按需选

**版本依据**: `a2ui-authoring` skill 明确"默认用 v0.9.1,因为文档标注它是当前生产版本"。demo 现在用的也是 v0.9,`genui` 包也校验 `version == "v0.9"`,保持一致。

**卡片交互依据(已核实 `a2ui/docs/concepts/actions.md` + `genui` 包实现)**:
- **v0.9.1 就支持"本地处理",不用等 v1.0**。A2UI action 有两个分支,`genui` 包(`button.dart:198-243`)都实现了:
  - `action.functionCall`:**本地执行,不往返 agent**(官方原话"agent is not informed of local function calls")。用于导航、开链接(`openUrl`)、关弹窗(`closeModal`)、本地校验。
  - `action.event`:发 `UserActionEvent` → `SurfaceController.onSubmit` 流 → **作为新消息往返 agent**。用于需要 AI 决策的业务逻辑。
- 还有更轻的第三种:输入类组件(`ChoicePicker` 等)用户操作时**直接写本地 `dataModel`**(`dataContext.update()`),连 event 都不发(官方的 "local-first / Write 契约")。
- **决策(回答用户"交互不一定要往返 AI")**:交互走哪种**不是全局开关,而是逐组件、由生成该卡片的一方在 A2UI JSON 里写死**。同一张卡片上,"打开链接"可以是本地 `functionCall`,"帮我深入分析"可以是往返 `event`。本次实现要**保留这个能力**(前端 `genui` 已支持),具体每个按钮走哪种取决于那次工具生成的卡片 JSON——见 D13。
- v1.0 的 `actionResponse`(服务器对客户端动作同步 RPC 回复)本次用不到,不升级。

### D8. 不做历史数据迁移/兼容,直接改

**依据**: 用户明确决定不需要考虑旧版 `TEXT`/`TOOL_CALL`/`TOOL_RESULT` 消息的兼容或迁移,直接把渲染逻辑和数据模型改成新的一套。旧格式的历史消息如何处理不在本次范围内。

### D9. 区分"功能型工具"与"A2UI 卡片工具";`TOOL_CALL`/`TOOL_RESULT` 的处理要分两类看

**背景事实(探索已确认,是既存实现,不是本次引入)**:
- 有两类工具,不能混为一谈:
  - **功能型工具**(`MemoryToolSet`/`ResourceToolSet`/skill 工具):返回**纯文本数据**(`@Tool` 方法返回 `String`),供模型继续生成用。它**没有 UI 可渲染**,不该套 A2UI。
  - **A2UI 卡片工具**(本次新增,fixed-schema):返回值**本身就是一个界面**(A2UI envelope),要渲染成 Surface。
- **关键既存事实**:后端 `AiChatService.toSpringAiMessages`(`AiChatService.java:443-455`)加载历史时**只保留 `TEXT` 且只保留 USER/ASSISTANT**,**明确 filter 掉 `TOOL_CALL`/`TOOL_RESULT`**。也就是说:现在 `PersistingToolCallAdvisor` 把功能型工具的 tool_call/tool_result 存进库,但**下一轮对话根本不会把它们喂回给模型**——跨轮工具历史目前是**丢弃的**。模型在**单轮生成内部**靠 Spring AI 框架在内存里跑 tool_call→tool_result 循环(两类工具都一样),但那份历史落库后跨轮就断了。
- 前端 `ChatToolCallCard` 现在只渲染一行"调用工具中…"/"工具执行完成"的文字提示(`chat_message_widgets.dart:178-227`),不显示工具名/参数/结果。

**决策**:
- **两类工具、两种渲染,都按 D3 的"块序列"模型走**(不再有"合并成一个 Surface"的通道 B 说法):
  - **功能型工具**:返回纯文本数据,不走 A2UI。它的 `TOOL_CALL`/`TOOL_RESULT` 消息在前端渲染成 `ChatToolCallCard`(D14,折叠可展开看结果)。
  - **A2UI 卡片工具**:返回 A2UI envelope,它的 `TOOL_RESULT`(content 是 A2UI JSON)在前端渲染成 `Surface`(D4 用 `A2uiMessage.fromJson` 判别)。
  - A2UI 卡片工具只是"返回值恰好是 UI 的工具调用",和普通工具在数据结构上同形(都是 tool_call + tool_result),只是 content 形状不同、前端渲染分支不同。不是嵌套。
- **流式过渡态**:工具执行中的"🔧 正在执行…"进度提示由流式事件 `TOOL_CALL_START`/`TOOL_CALL_END` 驱动(通道 A),**是过渡态不落库**;工具调用的事实+结果(最终态)按下面落库。
- **`TOOL_CALL`/`TOOL_RESULT` 两个 messageType:前后端都保留**:
  - 后端保留:是模型跨轮历史的载体(D12 要读回喂模型)。A2UI 卡片工具的 `TOOL_RESULT` 也一样是历史。
  - **前端也保留并落库**(用户确认,修正早期"前端不存"的说法):前端从后端 `syncMessages` 拉全部消息(含 `TOOL_CALL`/`TOOL_RESULT`),reload 后工具调用和卡片原样复现(D5)。
  - `ChatToolCallCard` **保留但重做**(D14),不是删除。
  - **不新增 `UI_SURFACE` messageType**(D3):卡片就是 content 为 A2UI JSON 的 `TOOL_RESULT`。
  - `PersistingToolCallAdvisor` 的 `TOOL_CALL`/`TOOL_RESULT` 落库逻辑**保留**;不存在早期担心的"既写 TOOL_CALL/TOOL_RESULT 又写 UI_SURFACE 重复落库"问题了——因为卡片本来就是那条 `TOOL_RESULT`,没有第二条。只需在实施时核对:A2UI 卡片工具的 tool_result content 存的是完整 A2UI JSON。

### D10. 只对接 OpenAI 兼容 API;Reasoning 类事件本次不做

**依据**:
- 用户确认本项目 AI 接入只走 OpenAI 兼容 API(现状 `AiConfiguration` 就是 base-url + api-key + model 的 OpenAI-compatible 模式)。
- 原 D2 里关于 DeepSeek R1 `reasoningContent`、Anthropic thinking block 的论证是针对具体模型集成的,和"只走 OpenAI 兼容网关"的接入方式不匹配(标准 OpenAI Chat Completions 没有 reasoning 字段;个别兼容网关塞的 `reasoning_content` 是非标准扩展)。
- **决策**:Reasoning 事件本次**不做**(不是"可选",是明确移出范围)。`ag_ui ^0.3.0` 包里虽有全套 `REASONING_*` 事件类可用,但本次不发。以后若真接推理模型,另开工作。

### D11. 前后端事件契约 = `ag_ui ^0.3.0` 这个 Dart 包的事件 JSON 格式(已核实包源码)

**依据(已核实 `ag_ui ^0.3.0` 包源码,不再是假设)**:
- 客户端已依赖 `ag_ui: ^0.3.0`(`mobile/pubspec.yaml:76`,包在 `~/.pub-cache/.../ag_ui-0.3.0`),demo 已迁移到它的事件模型。客户端解析新事件应复用这个包的事件类型,不手写重复解析。
- 已读 `lib/src/events/event_type.dart` + `events.dart`,包里事件类型齐全,字符串值是标准 AG-UI 大写下划线格式:
  - 文本:`TEXT_MESSAGE_START/CONTENT/END/CHUNK`
  - 工具:`TOOL_CALL_START/ARGS/END/CHUNK/RESULT`(**`TOOL_CALL_ARGS` 确实存在**,参数级 chunk 事件有类可接)
  - 生命周期:`RUN_STARTED/FINISHED/ERROR`、`STEP_STARTED/FINISHED`
  - **A2UI 内容:`ACTIVITY_SNAPSHOT`(`ActivitySnapshotEvent`)确认存在**,字段 = `messageId`(String) + `activityType`(String) + `content`(任意 JSON,可为 null 但键必须在) + `replace`(bool,默认 true);另有 `ACTIVITY_DELTA`(走 RFC6902 JSON Patch)
  - 兜底:`CUSTOM`、`RAW`
  - Reasoning:`REASONING_*` 全套(本次不用,D10)
- **A2UI 承载方案定稿**:用 `ACTIVITY_SNAPSHOT` 事件,`activityType = "a2ui-surface"`,`content` 字段放 A2UI envelope(`createSurface`/`updateComponents`/`updateDataModel`)。后端手写 SSE 输出这个格式,客户端 `BaseEvent.fromJson` 直接解析成 `ActivitySnapshotEvent`。
- 后端(D1 已定不引入任何 AG-UI Java 依赖)手写 SSE,字段严格对齐上述大写下划线格式 + 字段名(注意包同时接受 camelCase 和 snake_case:`messageId`/`message_id` 都认,后端选一种即可)。
- **仍需前后端一起定的少量自定义点**:(a) A2UI envelope 在 `content` 里的确切 JSON 结构(照 A2UI v0.9.1,D6);(b) 工具调用事件 `TOOL_CALL_ARGS` 是否真发(取决于 Task 2.1 spike 能否从框架托管模式拿到参数级 chunk,拿不到就只发 `TOOL_CALL_START`/`END`)。
- **决策**:D11 已从"待核实"升级为"已核实"。PLAN 的"事件对照表"任务简化为"确认后端 SSE 输出与 `ag_ui ^0.3.0` 各事件类字段逐一对齐"的核对清单即可,不必再探索包里有没有对应事件。

### D12. 修复"跨轮工具历史丢失"既存缺陷(本次一并做)

**背景事实**:
- 后端 `AiChatService.toSpringAiMessages`(`AiChatService.java:443-455`)加载历史时只保留 `TEXT` + USER/ASSISTANT,**明确 filter 掉 `TOOL_CALL`/`TOOL_RESULT`**。结果是:功能型工具的调用记录存了库,但**下一轮对话不喂回给模型**,模型跨轮"不记得"自己调过什么工具、拿到过什么结果。用户后续追问"刚才搜到的第二条"时,模型只能重新调一遍工具或答不上来。

**决策(用户确认本次一并修复)**:
- 改 `toSpringAiMessages`(或等价的历史加载逻辑),把 `TOOL_CALL`/`TOOL_RESULT` 记录**按 Spring AI 的 `AssistantMessage`(带 toolCalls)+ `ToolResponseMessage` 形状重建**,喂回给模型,让工具调用历史跨轮连续。
- 这条**反过来锁定了 D9 的结论**:`TOOL_CALL`/`TOOL_RESULT` 后端持久化**必须保留**(它们就是这个历史的载体),不能废弃。
- **风险 / 需在 PLAN 处理**:
  - 重建 tool_call/tool_result 消息喂回模型,要保证 `toolCallId` 配对正确、`AssistantMessage` 的 toolCalls 与后续 `ToolResponseMessage` 一一对应,否则某些 OpenAI 兼容网关会报"tool_call 无对应 response"之类的 400。
  - 与 `PersistingPruningToolCallAdvisor` 的上下文裁剪(D9 提到的 keepRecentToolResponses 等)交互:跨轮读回的历史 + 单轮内裁剪,两者叠加后 token 预算要重新算,别超窗口。
  - A2UI 卡片工具的 `TOOL_RESULT`(content 是 A2UI JSON)本身也要作为工具历史喂回(D7:模型靠它回答"刚才选的哪个"),这条历史加载路径对卡片 `TOOL_RESULT` 和普通 `TOOL_RESULT` 一视同仁。
- **建议**:这是一个可独立于 A2UI 渲染验证的后端改动,PLAN 里作为一个单独 task(如 Task 2.7),不与事件重设计强耦合,失败不牵连前端。

### D13. A2UI 卡片走 fixed-schema:每业务场景一个工具,组件 catalog 不进模型上下文

**依据(已核实官方 `a2ui-fixed.ts` 示例 + `ag-ui-a2ui-integration/SKILL.md` + `a2ui/agent_sdks/agent_sdk_guide.md`)**:
- 用户担心"A2UI 支持几十种组件样式,是不是每种样式一个工具、撑爆上下文"。核实结论:**fixed-schema 模式恰好避免这个问题**。
- 官方两种模式对比:

  | | fixed-schema(本次采用) | dynamic-schema(本次不用) |
  |---|---|---|
  | 工具数 | 每个业务场景一个(如"推荐书"/"搜航班"),通常 ≤5 | 主 agent 只 1 个 `generate_a2ui`,再委托 sub-agent |
  | 组件 catalog 是否进模型上下文 | **否**——组件布局硬编码在后端代码,模型看不到 | sub-agent 才看(可 `allowed_components` 剪枝) |
  | 工具 input schema | 只要业务数据(如 `books: [...]`),**零组件 schema** | — |
  | 上下文开销 | 约等于 N 个普通工具 | 大 |

- 官方 fixed 示例(`ag-ui/apps/dojo/src/mastra/agents/a2ui-fixed.ts`)只有 2 个业务工具(`search_flights`/`search_hotels`),入参只是 `flights: array`,组件长啥样(`FLIGHT_SCHEMA`)全写死在后端,LLM 完全不知道有多少种组件。
- **决策**:本次用 fixed-schema。要几种卡片就定义几个业务型 `@Tool`(如 `recommendBooks(books)`),每个工具的 `execute` 返回硬编码布局的 `a2ui_operations` envelope。**模型上下文里只有"有这么几个业务工具"的信息,不背整个 A2UI 组件表**。上下文可控。想让模型自由拼 UI 才需要 dynamic-schema(本次不需要,以后另说)。
- 卡片里每个按钮/组件走本地 `functionCall` 还是往返 `event`(D6),就在这个后端工具**硬编码的布局 JSON**里写死。

### D14. `ChatToolCallCard` 保留但重做(不是删除)

**依据(修正早期"删除 ChatToolCallCard"的说法)**:
- 早期决策说"废弃/删除 `ChatToolCallCard`",那是基于"所有结构化内容都合并进一个 Surface"的旧模型(已被 D3 推翻)。
- 新模型(D3)下,普通工具调用(bash/搜记忆)**仍需一个 Flutter 卡片**来显示(折叠态"✅ 执行了 X",可展开看结果)。这正是 `ChatToolCallCard` 的职责。
- **决策**:`ChatToolCallCard` **保留并重做**——从现在只显示一行"调用工具中…"的简陋版,改造成:
  - 折叠态显示工具名/一句话结果(如"✅ 搜索了记忆");
  - 可展开查看工具结果(参数可不显示,用户明确说了不需要显示输入参数);
  - 数据来自 `TOOL_CALL`/`TOOL_RESULT` 消息(前端已落库,D5)。
- 注意:**A2UI 卡片工具的 `TOOL_RESULT` 不走 `ChatToolCallCard`,走 `Surface`**(D4 的 `A2uiMessage.fromJson` 判别);只有普通工具的 `TOOL_RESULT` 走 `ChatToolCallCard`。

### D15. 卡片交互数据:用 v0.9.1 原生 `sendDataModel` 发回后端落库;未提交的纯本地中间态本次不恢复

**背景(已核实 v0.9.1 规范 + genui 包 + demo)**:
- 卡片交互有三种(D6):(a) `functionCall` 本地(无数据产出);(b) 写本地 `dataModel`(ChoicePicker 选中/TextField 输入,`InMemoryDataModel` 内存 Map);(c) `event` 往返 agent。
- **surface 有两样东西要分清**:①组件树(UI 结构,`createSurface`+`updateComponents`,AI 生成,已存);②`dataModel`(数据树,一个 JSON,存各组件当前值,如 `{"choice":{"topic":["B"]}}`,用户交互写入)。
- **`sendDataModel` 是 v0.9.1 就有的原生机制**(不是 v1.0 新增,规范 `a2ui/specification/v0_9_1/docs/a2ui_protocol.md:186,580,583`):`createSurface` 设 `sendDataModel:true` 后,客户端在**每次有 action 往返时**,把该 surface 的**完整 dataModel** 作为传输层 **metadata** 附带发回后端。打字等被动变更只更新本地,不单独发网络请求,下次 action 时随之带出。**注意:它不是 v1.0 的 `actionResponse`(那是服务端同步 RPC 回复,与此无关,勿混)**。
- genui 包**没有**现成的 dataModel 整份导出方法(`DataModel` 接口只有单路径 `getValue`/`update`);demo **没有**做交互数据持久化/恢复。

**决策(用户选"用 sendDataModel 官方机制")**:
- **本项目传输是 HTTP+SSE**,卡片的 `event` 提交在本项目落地为"**用户发起的一次新聊天请求**",消息内容是"卡片里的选择"而非手打文字;`sendDataModel` 让这次请求额外带上完整 dataModel。
- **落库(分两半,后端只存不改写)**:
  1. **卡片本身**(AI 生成的 `TOOL_RESULT`):存 `createSurface`+`updateComponents` 的 A2UI JSON(D5 已覆盖)。**这条落库后不再被改写**。
  2. **用户提交的交互**:作为**一条新的 USER 侧消息**落库(`parentUuid` 挂在卡片消息之后),content 存提交时的完整 dataModel JSON——它既是喂模型的历史(模型知道用户选了什么,接 D12),又是 reload 数据来源,**还是"这张卡片是否提交过"的判据**。后续 AI 回复照常是消息链下一条。走的是既有消息链机制,不发明新存储、不改写已落库数据。
- **"提交锁定 / 未提交可改"规则(用户明确)**:
  - 卡片是否锁定 = **该 surfaceId 后面有没有一条对应的"提交交互"消息**(卡片 `createSurface` 和用户提交 `event` 带同一个 `surfaceId`,天然配对)。
  - **有** → 提交过 → 锁定(交互组件只读)+ 用交互消息里的 dataModel 定格显示。
  - **无** → 没提交 → 卡片保持可交互(用户可能过很久才回来填、提交)。
  - 这样"固化"和"锁定"都是**前端渲染时的推导**,不需要后端改写卡片 JSON,也不需要额外的锁定标记字段。("固化"= 存储层已有交互消息;"呈现最终值"= reload 时的重放显示效果——两者是因果,别混。)
- **reload 复现最终值的机制(已验证同源)**:A2UI 组件是数据绑定的(`value:{path:"/..."}`,规范 Read 契约:组件从绑定 path 拉值)。reload 时用**同步** `A2uiMessage.fromJson`+`handleMessage`(Task 1.3a 已验证的路径,在 `setState` 前灌完,首帧即最终值、无空白/闪烁)把 `createSurface → updateComponents → updateDataModel(提交的整份 dataModel)` 按序灌入。**`updateDataModel` 的 path 可用根 `/`、value 直接是 `sendDataModel` 回传的整份 dataModel blob**,一条搞定,不必拆成多条单路径(根路径是整体替换还是合并的细节留 spike 核)。
- **待 spike 验证(渲染能力,未假设)**:genui 的交互组件(ChoicePicker/TextField/Button)能否被设为**只读/禁用**以呈现锁定态——需在包里确认,PLAN 里作为 spike 项。
- **本次不做**:用户**填了一半、没触发任何 action** 的纯本地中间态,reload 后**不恢复**(回到卡片初始态)。因为 `sendDataModel` 只在 action 往返时才发,这种中间态从没离开过客户端内存;要恢复它得自建 dataModel 快照(genui 无现成支持),**本次移出范围,标为已知限制**。

## 范围边界

**本次覆盖**:
- 后端事件从 4 种粗粒度事件重设计为 AG-UI 风格的细粒度自定义事件(**不含 Reasoning,D10 已移出**)
- 后端持久化:保留 `TOOL_CALL`/`TOOL_RESULT`(D9,供 D12 跨轮历史);A2UI 卡片作为 content 为 A2UI JSON 的 `TOOL_RESULT`,**不新增 `UI_SURFACE` 类型**(D3)
- 后端修复跨轮工具历史丢失(D12):`toSpringAiMessages` 把工具消息重建喂回模型
- 后端新增"生成 A2UI 卡片"能力:fixed-schema,每业务场景一个 `@Tool`,组件 catalog 不进模型上下文(D13)
- 客户端 `ChatMessage` 渲染改为"块序列":TEXT→md、普通工具→`ChatToolCallCard`(重做,D14)、A2UI 卡片 `TOOL_RESULT`→`Surface`(D3/D4)
- 客户端工具调用(含卡片)从后端 `syncMessages` 落库,reload 复现(D5)
- 卡片交互:用 v0.9.1 原生 `sendDataModel` 把交互数据随 metadata 发回后端落库;提交后 reload 复现定格态(D15)
- 端到端可验证的分步实施(每步都能独立验证,不要求一次性完工)

**本次不覆盖(超出范围,需要另开工作)**:
- 对 AG-UI/A2UI 协议字面格式的严格合规(D1 已否决)
- 历史消息迁移(D8 已决定不做)
- Reasoning 类事件(D10 已移出,只对接 OpenAI 兼容 API)
- **流式中途降级(failover)时已发出事件序列的收尾**:现有 `AiFailoverRouter.executeChatStream` 是订阅级 `onErrorResume` 降级,引入有状态事件序列(`RunStarted`/半截 `TextMessage`...)后,若流到一半切换 provider,已发出的事件如何收尾/客户端 Surface 状态机如何恢复,**本次不处理,标为已知问题(Known Limitation)留待后续**。当前先用着。
- **卡片"未提交纯本地中间态"的 reload 恢复**(D15):用户填了一半没触发任何 action 就离开,那份本地 dataModel reload 后不恢复(回初始态)。要恢复需自建 dataModel 快照(genui 无现成支持),本次移出范围。

## 数据模型改动(客户端)

- `ChatMessage`(`mobile/lib/model/chat_message.dart`):**`role` 和 `messageType` 是两个正交字段**(`role` = USER/ASSISTANT/SYSTEM,`messageType` = TEXT/TOOL_CALL/TOOL_RESULT)。**本次不新增 messageType**(D3:卡片是 content 为 A2UI JSON 的 `TOOL_RESULT`)。ASSISTANT 文本 = `TEXT`(md 渲染),用户输入 = `TEXT`,工具调用 = `TOOL_CALL`/`TOOL_RESULT`。`content`(Isar `String`,全量存储)对 TEXT 存文本、对工具消息存工具 JSON、对卡片 `TOOL_RESULT` 存 A2UI envelope JSON。
- **前端 Isar 保留 `TOOL_CALL`/`TOOL_RESULT`**(用户确认落库并 reload 复现,D5),从后端 `syncMessages` 同步。
- 落库直接用 `content` 存最终 JSON(D5),**不要在 Isar `ChatMessage` 上新增 side-channel 字段**。注意:现有的 `ToolCallData`/`toolData` 只存在于 API 层的 `ChatMessageModel`(`chat_models.dart`),Isar 的 `ChatMessage` 本来就没有这个字段——别被"既有先例"误导去 Isar 加字段。
- 编辑/重新生成/分支(`chat_providers.dart` 的 `editMessage`/`regenerate`/`ChatBranchChip`)目前只按 `parentUuid`/`activeLeafUuid` 走,不检查 `content` 形状,理论上不受影响,但**需要在 PLAN 阶段针对"重新生成一条含卡片的回复"走一遍这些流程确认没有隐藏假设**。

## 后端事件改动

- **前置(见 D2):后端代码是从 Spring AI 1.x 迁到 2.0 的产物,部分写法未改完、迁移后未运行过。任何"改造 SseReplyService"的动作,前提是先把现有流式+工具路径跑起来验证一遍(PLAN Task 2.1)。**
- 替换现有 `ChatSseEventFactory`/`SseReplyService` 的四件套(`delta`/`done`/`paused`/`error`)为细粒度事件。**优先在保留"框架托管工具调用 + `PersistingToolCallAdvisor` 自动持久化"的前提下**,把流式返回从"仅文本"扩展到"能识别工具调用并发细粒度事件"(可能需要从 `.stream().content()` 换成 `.stream().chatClientResponse()` 之类拿到更完整的 response);只有当框架托管拿不到所需粒度时,才评估切换到"用户托管"手动聚合循环(牵扯持久化逻辑迁移,见 D9)。具体 Spring AI API 名称以 spike 时的代码/IDE 为准,不以联网文档转述为准。
- 新事件集合(字段结构对齐 `ag_ui ^0.3.0` Dart 包,见 D11,已核实):生命周期 `RUN_STARTED/FINISHED/ERROR`;文本 `TEXT_MESSAGE_START/CONTENT/END`;工具调用 `TOOL_CALL_START/ARGS/END/RESULT`(其中 `ARGS` 是否发,取决于 Task 2.1 能否拿到参数级 chunk);A2UI 内容用 `ACTIVITY_SNAPSHOT`(`activityType="a2ui-surface"`,`content` 放 A2UI envelope)。**Reasoning 事件本次不做(D10)。**
- A2UI 卡片生成走 fixed-schema 模式(D13):按业务场景定义 `@Tool` 方法(如 `recommendBooks(books)`),`execute` 返回硬编码布局的 `a2ui_operations` envelope;包装层识别返回值形状后发 `ACTIVITY_SNAPSHOT` 事件给客户端。工具返回值按 Spring AI 默认行为进入模型对话历史(D7),并作为 `TOOL_RESULT` 落库(content 是 A2UI JSON)——就是那一条,不会重复落库(D9)。组件 catalog 不进模型上下文(D13)。可交互的卡片,`createSurface` 里设 `sendDataModel:true`,交互提交时前端会把完整 dataModel 随 metadata 发回,后端据此落库(D15)。

## 客户端渲染改动

- `chat_message_widgets.dart` 的 `ChatMessageBubble` 按 D3 的块序列分支渲染:USER `TEXT` → 用户气泡;ASSISTANT `TEXT` → Markdown;`TOOL_CALL`/普通 `TOOL_RESULT` → `ChatToolCallCard`(重做,D14);A2UI 卡片 `TOOL_RESULT`(`A2uiMessage.fromJson` 判别成功)→ 绑定该消息 `SurfaceController` 的 `Surface`。
- `ChatStreamingBubble`(流式态)从"只认 `String content`"改造为:文本流实时 md 渲染;工具进度用 `TOOL_CALL_START/END` 事件显示临时提示;卡片流式到达时用临时 `SurfaceController` 实时渲染,结束后交接给该消息落库后的 controller(Task 1.3a spike 已验证交接方案)。
- Markdown 段落复用 demo 里已经写好的 `StreamingMarkdownCatalogItem`(仅用于 A2UI Surface 内的文本组件);消息级的 ASSISTANT `TEXT` 直接用现有 `StreamingTextMarkdown`。

## 项目结构(受影响文件)

```
mobile/lib/model/chat_message.dart              → 不新增 messageType(卡片=TOOL_RESULT);前端保留 TOOL_CALL/TOOL_RESULT
mobile/lib/api/models/chat_models.dart          → 新事件的 Dart 侧解析(复用 ag_ui 包事件类型)
mobile/lib/api/chat_api_service.dart            → _parseSseStream 改造
mobile/lib/service/chat_service.dart            → 透传新事件类型
mobile/lib/providers/chat_providers.dart        → _consumeStreamEvents 改造(块序列 + 工具进度提示)
mobile/lib/page/chat/widgets/chat_message_widgets.dart → 块序列渲染;ChatToolCallCard 重做(D14);A2UI TOOL_RESULT 渲染 Surface
mobile/lib/demo/a2ui/streaming_markdown_catalog_item.dart → 原样复用(可能需要移出 demo 目录到共享位置)
backend/.../ai/application/stream/ChatSseEventFactory.java → 事件重设计
backend/.../ai/application/stream/SseReplyService.java     → 流式返回从 .content() 扩展到能识别工具调用
backend/.../ai/context/PersistingToolCallAdvisor.java      → 确认 A2UI 卡片工具的 TOOL_RESULT content 存完整 A2UI JSON;TOOL_CALL/TOOL_RESULT 保留
backend/.../ai/application/AiChatService.java(toSpringAiMessages) → 修复跨轮工具历史,重建工具消息喂回模型(D12)
backend/.../(新增) A2UI 卡片生成工具类(fixed-schema,每业务场景一个 @Tool,D13)
```

## 测试策略

- 客户端:`flutter analyze` + `flutter test` 覆盖块序列的各渲染分支(TEXT→md、普通工具→`ChatToolCallCard`、A2UI 卡片 `TOOL_RESULT`→`Surface`);沿用 demo 已有的手动验证方式(在真实聊天页面里先塞假数据验证 Surface 渲染,再接后端真实事件)。
- 后端:沿用现有测试框架(`./mvnw test`),新增 Advisor/事件重设计的单元测试。
- 每一步(见下方 PLAN 阶段的任务拆分)要求独立可验证,不接受"写完一大批再统一验证"。

## 边界(Always / Ask First / Never)

- **Always**:每步改动后跑对应测试/`flutter analyze`;新事件设计先在 mock 层验证通过,再接真实后端;工具返回的 A2UI JSON 按框架默认行为进入模型对话历史,不额外拦截或改写;**后端任何流式改造前,先跑通迁移后的现有流式+工具路径(D2)**;**事件字段以 `ag_ui ^0.3.0` 包源码为准、Spring AI API 以 IDE/代码为准,不以联网文档或本 spec 的转述为准(D11)**。
- **Ask first**:后端事件字段与 `ag_ui ^0.3.0` 逐一对齐核对完成前(D11);重做 `ChatToolCallCard` 前确认改动范围(D14,保留不删);改动 `PersistingToolCallAdvisor` 持久化行为、以及 `toSpringAiMessages` 历史加载逻辑前(D9/D12)。
- **Never**:引入不存在的 AG-UI Java/Kotlin 依赖;为兼容旧版消息格式做特殊处理(D8 已决定不做);一次性大改到不可回退的中间状态;本次实现 Reasoning 事件(D10 已移出);**废弃 `TOOL_CALL`/`TOOL_RESULT` 持久化(D9/D12 需要它们做跨轮历史,前后端都不能删)**;**新增 `UI_SURFACE` messageType(D3 已定卡片就是 A2UI JSON 的 `TOOL_RESULT`)**;**为 A2UI 生成塞几十个"每组件一个"的工具或把组件 catalog 灌进模型上下文(D13,用 fixed-schema)**。

## Success Criteria

- 真实聊天里,AI 一轮回复能在文字中间插入至少一种交互卡片,顺序与 AI 生成顺序一致(块序列,D3)。
- 关闭并重新打开该聊天会话,文字、工具调用记录、卡片都原样复现,不需要重新请求后端(D5)。
- 后端新事件集合有对应的单元测试;`ChatToolCallCard` 重做为可展开查看工具结果的卡片(D14),普通工具走它、A2UI 卡片走 `Surface`。
- 功能型工具被调用时,前端能通过 `TOOL_CALL_START/END` 事件显示临时进度提示,提示不落库(过渡态)。
- **(D12)修复跨轮工具历史后:先让 AI 调一次功能型工具(如搜记忆),下一轮追问"刚才那个结果里的 X",模型能基于上一轮工具结果回答,而不是重新调工具或答不上。**
- A2UI 卡片生成用 fixed-schema,模型上下文不含组件 catalog 全表(D13)。
- **(D15)卡片交互提交后:用户在卡片里做的选择/输入随 `sendDataModel` metadata 发回后端并落库;reload 后该卡片定格在"用户已选/已填"状态且不可再改(已提交=锁定),后续 AI 基于该交互的回复也原样复现。未提交的卡片 reload 后仍可交互。**
- 整个过程分阶段交付,每个阶段都有独立可验证的产出(不是一次性大爆炸式改动)。

## Open Questions

(spec 阶段的开放问题已全部定稿)
1. ~~新 messageType 命名~~ → 已定:**不新增 messageType**(D3)。卡片是 content 为 A2UI JSON 的 `TOOL_RESULT`,前端用 `A2uiMessage.fromJson` 判别(D4);`role`/`messageType` 正交关系见"数据模型改动"。
2. ~~`ChatStreamingBubble` 流式态生命周期~~ → 已由 PLAN Task 1.3a spike 验证(同步 `A2uiMessage.fromJson` + `handleMessage` 重建、dispose 后立即置空引用),概念清晰。
