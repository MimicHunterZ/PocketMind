# Implementation Plan: 真实聊天接入 A2UI + 后端事件重设计

对应 spec: `docs/superpowers/specs/2026-07-05-chat-a2ui-agui-integration-spec.md`(决策 D1–D15)

## Overview

按依赖图从风险最高、最不确定的部分先做,分三个阶段:先用 mock 把客户端渲染管线(块序列渲染 + 流式态)在不依赖后端的情况下验证透,再独立把后端事件管线重做并用 curl 验证透,最后把两边接起来做端到端验收。每阶段结束都有可以独立验证的产出,不要求一次性打通。

**核心模型(spec D3,贯穿全 plan)**:一轮 AI 回复 = 按 `parentUuid` 有序的**块序列**,每块按消息类型各自渲染:

| 块 | 消息类型 | 渲染 |
|---|---|---|
| 用户输入 | USER `TEXT` | 用户气泡 |
| AI 文本 | ASSISTANT `TEXT` | Markdown(现有 `StreamingTextMarkdown`) |
| 普通工具(bash/搜记忆) | `TOOL_CALL`/`TOOL_RESULT` | `ChatToolCallCard`(折叠可展开,D14) |
| A2UI 卡片工具 | `TOOL_RESULT`(content 是 A2UI JSON) | A2UI `Surface`(`A2uiMessage.fromJson` 判别,D4) |

**不新增 messageType**(D3);`TOOL_CALL`/`TOOL_RESULT` 前后端都保留(D9);卡片交互提交靠 v0.9.1 原生 `sendDataModel`(D15)。

## Architecture Decisions

延续 spec 的 D1–D15,本计划新增两条实施层面的决定:

- **客户端和后端解耦推进**:客户端先用 demo 已有的 mock 服务(或等价手写 mock)驱动真实聊天页面验证渲染,后端独立用 curl 验证事件输出,两边都验证通过后才互联。理由:这是两个独立的高风险面(客户端"块序列 + Surface 塞进消息列表"没人测过;后端"迁移后 Spring AI 2.0 流式+工具能不能跑、能不能给到细粒度 chunk"没在这个项目里跑过),混在一起做出了问题分不清是哪边的锅。
- **消息模型不新增类型**(落实 spec D3):不新增 `UI_SURFACE`。ASSISTANT 文本用 `TEXT`,工具调用用 `TOOL_CALL`/`TOOL_RESULT`,卡片是 content 为 A2UI JSON 的 `TOOL_RESULT`。前端用 `A2uiMessage.fromJson` 试解析来判别一条 `TOOL_RESULT` 走 `ChatToolCallCard` 还是 `Surface`。

## Task List

### Phase 1: 客户端渲染管线验证(不依赖后端改动)

- [ ] **Task 1.1: 前端消息模型确认 + A2UI 判别辅助**
  - 描述:确认 `ChatMessage`(Isar)保留 `TEXT`/`TOOL_CALL`/`TOOL_RESULT`,**不新增 messageType**(D3)。实现一个判别辅助:给定一条 `TOOL_RESULT` 的 `content`,用 `A2uiMessage.fromJson` 试解析——成功则是 A2UI 卡片,失败(抛 `A2uiValidationException`)则是普通工具结果(D4)。
  - 验收:辅助方法对"合法 A2UI JSON"返回真、对"普通文本/普通工具 JSON"返回假,单测覆盖;`ChatMessage` 读写 `TOOL_CALL`/`TOOL_RESULT` 无异常。
  - 验证:`flutter test`(新增 repository/判别单元测试)。
  - 依赖:无
  - 文件:`mobile/lib/model/chat_message.dart`(确认字段,可能无需改)、`mobile/lib/api/models/chat_models.dart`、新增判别工具方法(位置待定,可放共享 util)
  - 规模:S

- [ ] **Task 1.2: 块序列渲染(`ChatMessageBubble`)接 mock 数据**
  - 描述:`ChatMessageBubble` 按 D3 块序列分支渲染:USER `TEXT`→气泡;ASSISTANT `TEXT`→`StreamingTextMarkdown`;`TOOL_CALL`/普通 `TOOL_RESULT`→`ChatToolCallCard`(暂用现状简陋版,重做见 Task 1.3);A2UI 卡片 `TOOL_RESULT`(判别成功)→ 绑定该消息 `SurfaceController` 的 `Surface`。用手写的多条 mock 消息(照抄 demo 的 A2UI JSON + 几条普通文本/工具消息)验证,先不接后端/不接流式。
  - 验收:真实聊天页面里插入这批 mock 消息,能看到文字、工具卡片、A2UI 卡片按 `parentUuid` 顺序正确混排;上下滚动、同屏多条 Surface 消息不崩溃、不明显卡顿;消息增删不出错。
  - 验证:手动在真实聊天页面跑一遍;`flutter analyze`。
  - 依赖:1.1
  - 规模:M(**最大未知风险点**——"多个 Surface 各自独立生命周期塞进滚动列表"没人验证过,必须仔细过一遍多条同屏 + 滚动 + 消息删除的情况)
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`

- [ ] **Task 1.3: `ChatToolCallCard` 重做(D14)**
  - 描述:把现在只显示一行"调用工具中…"的 `ChatToolCallCard` 改造成:折叠态显示工具名/一句话结果(如"✅ 搜索了记忆");可展开查看工具结果(参数不显示,D14);数据来自 `TOOL_CALL`/`TOOL_RESULT` 消息。**A2UI 卡片的 `TOOL_RESULT` 不走这里**(走 Surface)。
  - 验收:普通工具消息渲染成可折叠/展开的卡片,展开能看到结果内容;A2UI 卡片消息不误入这个分支。
  - 验证:mock 数据手动验证;`flutter analyze`。
  - 依赖:1.2
  - 规模:S
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`

#### Checkpoint 1
- [ ] 静态块序列(文本 + 工具卡片 + A2UI 卡片)能在真实聊天列表正确渲染、滚动、混排,不涉及流式/后端。
- [ ] 与用户一起过一遍界面效果,确认没问题再进入流式态改造。

- [x] **Task 1.4(原 Task 1.3a,spike,已完成): 验证"临时流式 controller → 交接给持久化 controller"的生命周期**
  - 描述:demo 现在的模式是一个 `SurfaceController` 从页面 `initState()` 建一次、用到页面销毁,适合"一整页一个 Surface"。真实聊天是"每条消息各自一个 Surface,消息随时增删、列表滚动",流式时还要经历"临时 controller 实时渲染 → 流式结束 → 交接给这条消息持久化后自己的 controller"这个过程,demo 没验证过这个交接。这个实验在 `mobile/lib/demo/a2ui/` 里独立验证,不碰真实聊天代码。
  - 依赖:无
  - 文件:`mobile/lib/demo/a2ui/surface_handoff_lifecycle_demo_page.dart`、`mobile/test/demo/a2ui/surface_handoff_lifecycle_demo_page_test.dart`
  - 规模:S
  - **✅ 已完成,结论如下(2026-07-05)**:

    **结论 1——交接机制本身可行,但要用"同步灌入"而不是"流式解析"重建最终态。**
    一开始想当然地用 `A2uiTransportAdapter.addChunk()` 给交接目标(持久化 controller)灌最终 JSON——结果发现 `addChunk` 走的是异步解析管线(`StreamController` + `Transformer`,消息要等 microtask 才真正送达 `SurfaceController`),灌完立刻 `setState` 切换 widget 的话,新 controller 在下一帧渲染时数据可能还没到,存在一瞬间空白/重建的风险。改成用同步的 `A2uiMessage.fromJson()` 把存储的最终 JSON 解析成消息对象,直接循环调用 `SurfaceController.handleMessage()`——这样新 controller 在 `setState` 之前就已完全就位,交接前后是同一帧内的状态,widget 测试验证了这一点(交接那一次 `pump` 之后立刻就能看到同样的文本,没有中间空白帧)。**结论:正式实现里,"用存储的最终 JSON 重建 Surface"(不管是流式交接还是历史消息 Task 1.2 那种一次性渲染)都应该走 `A2uiMessage.fromJson` + `handleMessage` 这条同步路径,`addChunk` 只用于真正需要边解析边喂的场景(比如真的在接收 LLM 流式文本)。**

    **结论 2——测试跑出了一个真实 bug:重复 dispose 会崩。**
    第一次跑测试时,在 widget 树卸载阶段(测试收尾)炸了:`A ValueNotifier<SurfaceDefinition?> was used after being disposed`,来自 `SurfaceController.dispose()` 内部的 `SurfaceRegistry.dispose()`。根因是我在 `addPostFrameCallback` 里 dispose 了流式 controller,但没把持有它的字段置空——`State.dispose()`(widget 销毁时)又拿着同一个引用调用了一次 `.dispose()`,触发二次释放。修复方式很简单:dispose 之后立刻把字段设为 `null`。**结论:任何"提前手动 dispose 一个 controller"的地方,都必须紧跟着清空持有它的引用,否则 `State.dispose()` 的收尾逻辑会重复释放同一个对象——这是后续任何"消息级 controller 生命周期管理"代码都要遵守的规则,不是这次特例。**

    修完这两点后,`flutter test test/demo/a2ui/surface_handoff_lifecycle_demo_page_test.dart` 全程无异常通过:流式三条消息逐条到达 → 交接瞬间文本不变(无空白帧)→ 交接后一帧内旧 controller 正确 dispose → 之后再 pump 多次也没有任何"used after dispose"类异常冒出来。

    **副发现(不在本任务范围内,未处理)**:跑 `test/demo/` 全目录时,发现 `test/demo/a2ui/genui_demo_page_test.dart` 里已有一个失败——它断言的文案和 `a2ui_stream_api_service.dart` 现在的实际内容不匹配。确认这是这次 spike 之前就存在的、跟本任务无关的测试文案漂移,不在本任务范围内,记录下来但没有动它。

- [ ] **Task 1.5(原 Task 1.3b): 流式态渲染改造(`ChatStreamingBubble`)+ 接 mock 验证完整流式**
  - 描述:在 Task 1.4 验证过的交接方案基础上,把 demo 里已经验证过的 `A2uiStreamApiService` 风格 mock 临时接到真实聊天发送流程(仅用于本任务验证,不是最终形态,Task 3.2 会换真实后端)。`ChatStreamingBubble` 改造成驱动块序列流式:文本流实时 md 渲染;工具进度用 `TOOL_CALL_START/END` 事件显示临时提示(过渡态,不落库,D9);卡片流式到达时用临时 `SurfaceController` 实时渲染,流式结束后按 Task 1.4 的同步交接方案落到持久化消息。
  - 验收:从"发送消息"到"文字/工具提示/卡片一步步流式出现"到"流式结束变成历史消息"全程不崩溃;关闭重开聊天,历史里的文字、工具记录、卡片和刚才流式时的最终态一致。
  - 验证:手动跑完整发送流程(接 mock);reload 页面人工核对。
  - 依赖:1.4、1.2
  - 规模:M
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`(`ChatStreamingBubble`)、`mobile/lib/providers/chat_providers.dart`(临时接线,注明过渡代码)

- [ ] **Task 1.6: 卡片交互 + 锁定态(D6/D15)接 mock 验证**
  - 描述:在 mock 场景下验证卡片交互三态(D6):`functionCall` 本地(如开链接)、写本地 `dataModel`(ChoicePicker 选中)、`event` 往返(触发一次新的往返)。并实现 D15 的"提交锁定"渲染规则:某卡片(按 `surfaceId`)后面存在对应"提交交互"消息 → 卡片锁定(交互组件只读)+ 用交互消息里的 dataModel 定格显示;无 → 保持可交互。**先做一个 spike 确认 genui 的交互组件(ChoicePicker/TextField/Button)能否被设成只读/禁用**(D15 待验证项),再据此实现锁定态。
  - 验收:mock 一张可交互卡片,选择后触发 `event`(mock 生成一条"提交交互"消息);reload/重建后该卡片定格在已选状态且不可再改;另一张未提交的卡片 reload 后仍可交互。
  - 验证:手动跑 mock;`flutter analyze` + 可能的 widget 测试。
  - 依赖:1.5
  - 规模:M
  - 风险标记:**若 spike 发现 genui 组件无法设只读**,则"锁定态"退化为"重放定格值但仍可点击"(或在卡片外层包一层拦截),需回来和用户确认降级方案。
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`、`mobile/lib/providers/chat_providers.dart`、必要时 demo 里加 spike 场景

#### Checkpoint 2(人工评审点)
- [ ] 客户端渲染管线(块序列历史 + 流式 + 交互/锁定)完全用 mock 验证通过。
- [ ] **与用户核对后再推进 Phase 2**——这是本计划里最花不确定性的部分,确认没问题才值得往后端投入。

### Phase 2: 后端事件重设计(与 Phase 1 独立,可并行,但建议 Checkpoint 2 后再投入)

- [ ] **Task 2.1: Spring AI 2.0 流式 + 工具"能不能跑"spike(最高优先,D2)**
  - 描述:spec D2 已说明后端是从 Spring AI 1.x 迁到 2.0、部分写法未改完、迁移后从未运行。**本 spike 首要目标是先把现有"流式 + 工具"路径跑起来**:发一条会触发功能型工具(如 `MemoryToolSet`)的消息,确认 `SseReplyService` 的流式路径能正常执行工具、`PersistingToolCallAdvisor` 能正常持久化,而不是先纠结事件粒度。跑通之后,再观察:工具调用参数是不是分块到达(为 `TOOL_CALL_ARGS` 事件铺路)、能否在保留框架托管的前提下从 `.stream().content()` 扩展到拿更完整的 response。具体 Spring AI API 名以 IDE/代码为准,不信联网文档转述(D2)。
  - 验收:流式聊天触发工具调用能正常完成并持久化(不报错、不卡死);日志能看清工具调用的时机与数据形状;记录"框架托管下能否拿到工具调用中间状态/参数级 chunk"的结论。
  - 验证:手动运行观察日志 + 数据库。
  - 依赖:无
  - 规模:M
  - **风险标记(全计划影响面最大的一步,放最前)**:
    - 若"迁移后流式+工具跑不起来" → 先修到能跑,这是后续一切的地基。
    - 若"框架托管下拿不到参数级 chunk" → `TOOL_CALL_ARGS` 退化为只发 `TOOL_CALL_START`/`END`,回头改 spec D11 的(b)项。
    - 若"框架托管完全拿不到工具调用信息、必须切用户托管手动聚合" → 评估 `PersistingToolCallAdvisor` 迁移代价(spec D2/D9),这是最坏情况,需回来和用户确认。

- [ ] **Task 2.2: 定义新事件 Java 类型 + SSE 序列化(对齐 `ag_ui ^0.3.0`,D11)**
  - 描述:按 spec D11(已核实包源码)定义事件类型,SSE 输出用标准 AG-UI 大写下划线格式:`RUN_STARTED/FINISHED/ERROR`、`TEXT_MESSAGE_START/CONTENT/END`、`TOOL_CALL_START/ARGS/END/RESULT`、`ACTIVITY_SNAPSHOT`。字段名对齐 `ag_ui ^0.3.0` 各事件类(camelCase 或 snake_case 选一种,包都认)。**不做 Reasoning 事件(D10)**。
  - 验收:每种事件类型能正确序列化成对应 SSE 格式,字段与 `ag_ui ^0.3.0` 对应事件类逐一对齐,单元测试覆盖。
  - 验证:`./mvnw test`。
  - 依赖:2.1
  - 规模:M
  - 文件:后端新建事件类(包路径待定)、`ChatSseEventFactory.java`

- [ ] **Task 2.3a: 文本事件(`TEXT_MESSAGE_START/CONTENT/END`)替换旧 `delta`**
  - 描述:把纯文本流量映射成新的文本事件三元组。
  - 验收:curl 聊天接口,SSE 输出是新文本事件格式。
  - 验证:`./mvnw test` + 手动 curl。
  - 依赖:2.2
  - 规模:M
  - 文件:`ChatSseEventFactory.java`、`SseReplyService.java`

- [ ] **Task 2.3b: 工具调用事件(`TOOL_CALL_START/ARGS/END/RESULT`)**
  - 描述:针对工具调用流量发细粒度事件(`ARGS` 是否发取决于 2.1 结论)。功能型工具的进度提示靠 `TOOL_CALL_START/END`,结果靠 `TOOL_CALL_RESULT`。
  - 验收:curl 触发一次功能型工具调用,SSE 输出能看到 Start→(Args)→End→Result 序列。
  - 验证:`./mvnw test` + 手动 curl。
  - 依赖:2.3a
  - 规模:M
  - 文件:同上

#### Checkpoint 3
- [ ] 后端能吐出新格式的文本 + 工具事件,curl 验证通过,先不管客户端能不能解析。

- [ ] **Task 2.4: A2UI 卡片生成工具(fixed-schema,D13)+ `ACTIVITY_SNAPSHOT` 事件**
  - 描述:按 spec D13 新建业务型 `@Tool`(如 `recommendBooks(books)`),`execute` 返回硬编码布局的 `a2ui_operations` envelope(照 A2UI v0.9.1,D6);包装层识别返回值形状后发 `ACTIVITY_SNAPSHOT` 事件(`activityType="a2ui-surface"`,`content` 放 envelope)。组件 catalog 不进模型上下文(D13)。可交互卡片在 `createSurface` 里设 `sendDataModel:true`(D15)。工具返回值按 Spring AI 默认行为进入模型对话历史(D7),并作为 `TOOL_RESULT` 落库。
  - 验收:调用聊天接口触发该工具,SSE 里有一个 `ACTIVITY_SNAPSHOT` 事件,`content` 是合法 `a2ui_operations` JSON(能过 `a2ui-authoring` 规则的人工检查:surface/组件/dataModel 结构正确);模型上下文里没有组件 catalog 全表。
  - 验证:`./mvnw test` + 手动 curl,把返回的 A2UI JSON 拿去过一遍 Task 1.2 已验证的客户端渲染(mock 替换成这个真实返回值,确认能渲染)。
  - 依赖:2.3b
  - 规模:M
  - 文件:后端新建工具类

- [ ] **Task 2.5: 持久化核对(D9/D15 后端侧)**
  - 描述:(a) 核对 A2UI 卡片工具的 `TOOL_RESULT` content 存的是完整 A2UI JSON,且不会重复落库(D9:卡片就是那条 tool_result,没有第二条)。(b) 卡片交互提交请求(带 `sendDataModel` metadata 的完整 dataModel)作为一条新 USER 侧消息落库,`parentUuid` 挂在卡片消息之后(D15);后端**不改写**已落库的卡片消息。
  - 验收:触发一次卡片生成 + 一次模拟交互提交,数据库里:卡片是一条 `TOOL_RESULT`(A2UI JSON);交互是一条新消息(dataModel JSON);卡片消息未被改写。
  - 验证:`./mvnw test` + 手动 curl + 查库。
  - 依赖:2.4
  - 规模:M
  - 文件:`PersistingToolCallAdvisor.java`、SSE/交互接收接口

- [ ] **Task 2.6: 修复跨轮工具历史丢失(D12)**
  - 描述:改 `AiChatService.toSpringAiMessages`(或等价历史加载逻辑),把 `TOOL_CALL`/`TOOL_RESULT`(含 A2UI 卡片的 tool_result)按 Spring AI 的 `AssistantMessage`(带 toolCalls)+ `ToolResponseMessage` 形状重建喂回模型,让工具历史跨轮连续。注意 `toolCallId` 配对(否则 OpenAI 兼容网关报 400)、与 `PersistingPruningToolCallAdvisor` 裁剪的 token 预算交互(spec D12 风险项)。
  - 验收:先调一次功能型工具,下一轮追问"刚才那个结果里的 X",模型能基于上一轮工具结果回答(不重新调工具、不答不上)。
  - 验证:`./mvnw test` + 手动多轮 curl。
  - 依赖:无(可独立于事件重设计,失败不牵连前端;建议 2.1 之后择机做)
  - 规模:M
  - 文件:`AiChatService.java`

#### Checkpoint 4
- [ ] 后端新事件管线完整跑通,curl 能验证文本、工具、A2UI 卡片;卡片/交互/跨轮历史持久化正确。

### Phase 3: 打通客户端和后端

- [ ] **Task 3.1: 客户端 `_parseSseStream` 改造(复用 `ag_ui` 包解析,D11)**
  - 描述:把 Task 2.2–2.4 的事件格式对应到客户端解析。**复用 `ag_ui ^0.3.0` 的事件类型(`BaseEvent.fromJson`)**,不手写重复解析(D11)。覆盖文本/工具/`ACTIVITY_SNAPSHOT` 三类。
  - 验收:单元测试覆盖新事件解析(文本/工具/activity)。
  - 验证:`flutter test`。
  - 依赖:Checkpoint 4、Checkpoint 2
  - 规模:M
  - 文件:`mobile/lib/api/chat_api_service.dart`、`mobile/lib/api/models/chat_models.dart`

- [ ] **Task 3.2: `_consumeStreamEvents` 接真实后端,替换 Task 1.5 的临时 mock**
  - 描述:把 Task 1.5 里"临时接 mock"的代码换成真实解析出的后端事件,驱动块序列流式(文本/工具提示/卡片)。
  - 验收:端到端——发一条会触发 AI 生成卡片的真实消息,聊天界面里文字、工具记录、卡片按 AI 实际生成顺序混排出现;关闭重开聊天,原样复现,不重新请求后端。
  - 验证:真机/模拟器手动跑完整流程。
  - 依赖:3.1
  - 规模:M
  - 文件:`mobile/lib/providers/chat_providers.dart`

- [ ] **Task 3.3: 事件字段对齐核对 + 端到端验收清单(D11)**
  - 描述:对照 spec D11,逐字段核对后端 SSE 输出与 `ag_ui ^0.3.0` 各事件类;跑 spec Success Criteria 全部条目。检查 Task 1.5 的过渡代码是否已被 3.2 完全替换、无遗留。
  - 验收:对照 spec 的 Success Criteria 逐条勾选确认;无 mock 过渡代码遗留。
  - 验证:真机手动 + `flutter analyze` + `grep` 检查过渡代码。
  - 依赖:3.2
  - 规模:S

#### Checkpoint 5(最终验收)
- [ ] 对照 spec 的 Success Criteria 逐条勾选确认。

## Risks and Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| Task 1.2 发现多个 `Surface`/`SurfaceController` 塞进滚动列表有生命周期问题(未正确释放、rebuild 重建) | 高——客户端方案的地基 | 放 Phase 1 最前独立验证;Task 1.4 已沉淀"同步灌入 + dispose 后置空引用"两条规则 |
| Task 1.6 发现 genui 交互组件无法设只读(锁定态做不了) | 中——影响"已提交锁定"体验 | 先 spike 确认;做不到则退化为"重放定格值但仍可点"或外层拦截,回来和用户确认 |
| Task 2.1 发现迁移后流式+工具跑不起来 | 高——后端一切的地基 | 放 Phase 2 最前;首要目标就是"先跑起来",跑不通先修 |
| Task 2.1 发现框架托管拿不到参数级 chunk | 中——只影响 `TOOL_CALL_ARGS` | 退化为 Start+End,改 spec D11(b) |
| Task 2.1 发现必须切用户托管手动聚合 | 高 | 评估 `PersistingToolCallAdvisor` 迁移代价,回来和用户确认 |
| Task 2.6 跨轮历史重建导致 toolCallId 配对错、网关报 400 | 中 | 独立 task,可单独 curl 多轮验证;失败不牵连前端 |
| Task 1.5 临时 mock 接线与 Task 3.2 真实接线的过渡代码遗留 | 低 | Task 1.5 明确标注"过渡",Task 3.3 检查清理 |

## Open Questions

无——spec 阶段的开放问题(D1–D15)已全部定稿。实施层面待验证的点已显式落到对应 task 的风险标记(Task 2.1 的流式+工具、Task 1.6 的 genui 只读能力、Task 2.6 的 toolCallId 配对),不再是隐藏假设。
