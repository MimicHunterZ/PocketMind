# Implementation Plan: 真实聊天接入 A2UI + 后端事件重设计

对应 spec: `docs/superpowers/specs/2026-07-05-chat-a2ui-agui-integration-spec.md`

## Overview

按依赖图从风险最高、最不确定的部分先做,分三个阶段:先用 mock 把客户端渲染管线(历史消息 Surface 化 + 直播态 Surface 化)在不依赖后端的情况下验证透,再独立把后端事件管线重做并用 curl 验证透,最后把两边接起来做端到端验收。每阶段结束都有可以独立验证的产出,不要求一次性打通。

## Architecture Decisions

延续 spec 的 D1-D8,本计划新增两条实施层面的决定:

- **客户端和后端解耦推进**:客户端先用demo已有的 mock 服务(或等价手写 mock)驱动真实聊天页面验证渲染,后端独立用 curl 验证事件输出,两边都验证通过后才互联。理由:这是两个独立的高风险面(客户端"Surface 塞进消息列表"没人测过;后端"Spring AI 能不能给到细粒度 chunk"是文档说的,没在这个项目里跑过),混在一起做出了问题分不清是哪边的锅。
- **`messageType` 具体设计(落实 spec Open Question 1)**:新增取值 `UI_SURFACE`。以后所有 ASSISTANT 角色的持久化消息都用这个类型,`content` 存最终态 A2UI JSON 数组的字符串。`TEXT` 保留给 USER 消息用(用户发的还是纯文字)。`TOOL_CALL`/`TOOL_RESULT` 不再产生新数据(D3 已废弃硬编码卡片),但不强制从枚举里删除,避免影响历史数据读取代码路径的类型判断——不过 D8 已经说了不用管旧数据兼容,所以如果 PLAN 执行过程中发现保留这两个值没有实际意义,可以顺手删掉,不是必须保留。

## Task List

### Phase 1: 客户端渲染管线验证(不依赖后端改动)

- [ ] **Task 1.1: `ChatMessage` 新增 `UI_SURFACE` messageType**
  - 描述:在数据模型层面支持"content 是一份 A2UI JSON"的 ASSISTANT 消息。
  - 验收:能写入并读出一条 `messageType == 'UI_SURFACE'`、`content` 为 A2UI JSON 字符串的消息,Isar 层无异常。
  - 验证:新增 repository 层单元测试(写入→读出,content 一致);`flutter test`。
  - 依赖:无
  - 文件:`mobile/lib/model/chat_message.dart`、`mobile/lib/api/models/chat_models.dart`(镜像字段)、对应 `.g.dart`(build_runner 重新生成)
  - 规模:S

- [ ] **Task 1.2: 历史消息渲染改为 `Surface`(`ChatMessageBubble`)**
  - 描述:`ChatMessageBubble` 遇到 `UI_SURFACE` 类型时,创建一个绑定该消息的 `SurfaceController`,把存储的 A2UI JSON 一次性喂进去,渲染 `Surface` widget。先不接后端/不接流式,用手写的一条固定 A2UI JSON(可以直接照抄 demo 里的选择卡片 JSON)测试消息验证。
  - 验收:在真实聊天页面里插入这条测试消息,能看到卡片正确渲染;和普通文字消息混排在同一个列表里不冲突;上下滚动、同屏多条 Surface 消息不崩溃、不明显卡顿。
  - 验证:手动在真实聊天页面跑一遍;`flutter analyze` 通过。
  - 依赖:1.1
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`
  - 规模:M(这是探索阶段标记过的最大未知风险点——"Surface 塞进滚动列表、每条消息独立生命周期"没人验证过,必须仔细过一遍多条同屏 + 滚动 + 消息删除的情况)

#### Checkpoint 1
- [ ] 静态 Surface 消息能在真实聊天列表正确渲染、滚动、和其它消息混排,不涉及流式/后端。
- [ ] 与用户一起过一遍界面效果,确认没问题再进入 1.3。

- [x] **Task 1.3a(spike,在 demo 里做,不碰真实聊天代码): 验证"临时直播 controller → 交接给持久化 controller"的生命周期**
  - 描述:demo 现在的模式是一个 `SurfaceController` 从页面 `initState()` 建一次、用到页面销毁,适合"一整页一个 Surface"。真实聊天是"每条消息各自一个 Surface,消息随时增删、列表滚动",直播时还要经历"临时 controller 实时渲染 → 流式结束 → 交接给这条消息持久化后自己的 controller"这个过程,demo 没验证过这个交接。这个实验和真实聊天的 Isar/Riverpod 数据流完全无关,直接在 `mobile/lib/demo/a2ui/` 里新增一个小场景(或者在现有 demo 页面里加一段实验代码)验证即可,不需要碰 `chat_message_widgets.dart`:手写一段固定的 `createSurface`→`updateComponents`→`updateDataModel` 序列,模拟"临时 controller 逐条喂消息、结束后 dispose、由另一个全新 controller 用同一份最终 JSON 接管渲染"这个动作,肉眼确认交接瞬间没有闪烁/重建 artifact,且临时 controller 确实被释放(不是内存泄漏)。
  - 验收:交接前后画面视觉上完全一致(无闪烁);临时 controller 在交接后被正确 dispose(可以打日志/断点确认,或用 Flutter DevTools 看 widget 树里没有残留)。
  - 验证:手动运行 + 肉眼核对;如果用 DevTools 检查,记录截图或文字确认。
  - 依赖:无(和真实聊天代码无关,可以和 1.1/1.2 并行做,甚至更早做——验证结果直接决定 1.3b 怎么写)
  - 文件:`mobile/lib/demo/a2ui/surface_handoff_lifecycle_demo_page.dart`(新场景,已挂到 demo hub + 路由)、`mobile/test/demo/a2ui/surface_handoff_lifecycle_demo_page_test.dart`(自动化验证)
  - 规模:S
  - **✅ 已完成,结论如下(2026-07-05)**:

    **结论 1——交接机制本身可行,但要用"同步灌入"而不是"流式解析"重建最终态。**
    一开始想当然地用 `A2uiTransportAdapter.addChunk()` 给交接目标(持久化 controller)灌最终 JSON——结果发现 `addChunk` 走的是异步解析管线(`StreamController` + `Transformer`,消息要等 microtask 才真正送达 `SurfaceController`),灌完立刻 `setState` 切换 widget 的话,新 controller 在下一帧渲染时数据可能还没到,存在一瞬间空白/重建的风险。改成用同步的 `A2uiMessage.fromJson()` 把存储的最终 JSON 解析成消息对象,直接循环调用 `SurfaceController.handleMessage()`——这样新 controller 在 `setState` 之前就已完全就位,交接前后是同一帧内的状态,widget 测试验证了这一点(交接那一次 `pump` 之后立刻就能看到同样的文本,没有中间空白帧)。**结论:Task 1.3b/正式实现里,"用存储的最终 JSON 重建 Surface"(不管是直播交接还是历史消息 Task 1.2 那种一次性渲染)都应该走 `A2uiMessage.fromJson` + `handleMessage` 这条同步路径,`addChunk` 只用于真正需要边解析边喂的场景(比如真的在接收 LLM 流式文本)。**

    **结论 2——测试跑出了一个真实 bug:重复 dispose 会崩。**
    第一次跑测试时,在 widget 树卸载阶段(测试收尾)炸了:`A ValueNotifier<SurfaceDefinition?> was used after being disposed`,来自 `SurfaceController.dispose()` 内部的 `SurfaceRegistry.dispose()`。根因是我在 `addPostFrameCallback` 里 dispose 了直播 controller,但没把持有它的字段置空——`State.dispose()`(widget 销毁时)又拿着同一个引用调用了一次 `.dispose()`,触发二次释放。修复方式很简单:dispose 之后立刻把字段设为 `null`。**结论:任何"提前手动 dispose 一个 controller"的地方,都必须紧跟着清空持有它的引用,否则 `State.dispose()` 的收尾逻辑会重复释放同一个对象——这是 Task 1.3b 和后续任何"消息级 controller 生命周期管理"代码都要遵守的规则,不是这次特例。**

    修完这两点后,`flutter test test/demo/a2ui/surface_handoff_lifecycle_demo_page_test.dart` 全程无异常通过:直播三条消息逐条到达 → 交接瞬间文本不变(无空白帧)→ 交接后一帧内旧 controller 正确 dispose → 之后再 pump 多次也没有任何"used after dispose"类异常冒出来。

    **副发现(不在本任务范围内,未处理)**:跑 `test/demo/` 全目录时,发现 `test/demo/a2ui/genui_demo_page_test.dart` 里已有一个失败——它断言的文案("周末读书会方案"/"继续细化"/"确认方案")和 `a2ui_stream_api_service.dart` 现在的实际内容(Java 类加载机制场景,按钮是"展开讲解"/"理解了")不匹配。确认这是这次 spike 之前就存在的、跟本任务无关的测试文案漂移,不在 Task 1.3a 范围内,记录下来但没有动它。

- [ ] **Task 1.3b: 直播态渲染改为 `Surface`(`ChatStreamingBubble`)+ 接 mock 验证完整流式建卡**
  - 描述:在 1.3a 验证过的交接方案基础上,把 demo 里已经验证过的 `A2uiStreamApiService` 风格 mock,临时接到真实聊天的发送流程上(仅用于本任务验证,不是最终形态,后面 Task 3.2 会换成真实后端)。`ChatStreamingBubble` 改造成实时驱动一个临时 `SurfaceController`,流式结束后把最终 JSON 落到一条新建的 `UI_SURFACE` `ChatMessage`。
  - 验收:从"发送消息"到"卡片一步步流式出现"到"流式结束变成历史消息"全程不崩溃;关闭重开聊天,历史消息里的卡片和刚才直播时看到的最终态一致。
  - 验证:手动跑一遍完整发送流程(接 mock);reload 页面人工核对。
  - 依赖:1.3a
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`(`ChatStreamingBubble`)、`mobile/lib/providers/chat_providers.dart`(临时接线,注明是过渡代码)
  - 规模:M

#### Checkpoint 2(人工评审点)
- [ ] 客户端渲染管线(历史 + 直播)完全用 mock 验证通过。
- [ ] **与用户核对后再推进 Phase 2**——这是本计划里唯一一个明确要求停下来给人看的节点,因为这是最花不确定性的部分,确认没问题才值得往后端投入。

### Phase 2: 后端事件重设计(与 Phase 1 完全独立,可并行开始,但建议 Checkpoint 2 通过后再投入)

- [ ] **Task 2.1: Spring AI `StreamAdvisor` 拦截能力 spike**
  - 描述:写一个最小可运行的 Advisor,只做一件事——把文本流和工具调用参数流的原始 chunk 打日志,验证"工具调用参数是分块到达、可在聚合前拿到"这个官方文档描述的行为,在本项目实际用的模型 provider 上真的成立。
  - 验收:日志里能看到工具调用参数是分多次到达的,不是一次性拿到完整 JSON。
  - 验证:手动运行观察日志。
  - 依赖:无
  - 文件:新建一个临时 Advisor 类 + 一个手动触发的测试入口
  - 规模:S
  - **风险标记**:如果这一步验证失败(比如具体模型 provider 不支持分块工具参数),`ToolCallArgs` 这个细粒度事件就做不了,需要退化成"只有 ToolCallStart + ToolCallResult",要回头改 spec 的 D2——**这是全计划里最该提前做、失败了影响面最大的一步,放在 Phase 2 最前面。**

- [ ] **Task 2.2: 定义新事件的 Java 类型 + SSE 序列化**
  - 描述:落实 spec D2 的事件分类(生命周期/文本/工具/Activity/Reasoning),定义对应 Java 事件类型。
  - 验收:每种事件类型能正确序列化成 SSE 格式,有单元测试覆盖。
  - 验证:`./mvnw test`
  - 依赖:2.1
  - 文件:后端新建事件类(具体包路径待实施时定),`ChatSseEventFactory.java`
  - 规模:M

- [ ] **Task 2.3a: 文本事件(Start/Content/End)替换旧 `delta`**
  - 描述:用 `StreamAdvisor` 把纯文本流量映射成新的文本事件三元组。
  - 验收:curl 聊天接口,SSE 输出是新的文本事件格式。
  - 验证:`./mvnw test` + 手动 curl。
  - 依赖:2.2
  - 文件:`ChatSseEventFactory.java`、`SseReplyService.java`
  - 规模:M

- [ ] **Task 2.3b: 工具调用事件(Start/Args/End/Result)替换旧 `done`/`paused`/`error` 里混杂的工具语义**
  - 描述:同上,针对工具调用流量。
  - 验收:curl 触发一次工具调用,SSE 输出能看到完整的 Start→Args→End→Result 序列。
  - 验证:`./mvnw test` + 手动 curl。
  - 依赖:2.3a
  - 文件:同上
  - 规模:M

#### Checkpoint 3
- [ ] 后端能吐出新格式的文本 + 工具事件,curl 验证通过,先不管客户端能不能解析。

- [ ] **Task 2.4: A2UI 卡片生成工具(fixed-schema `@Tool`)**
  - 描述:新建一个 `@Tool` 方法,返回值是 `a2ui_operations` envelope(参照官方 dojo 的 `a2ui-fixed.ts` 模式);包装层识别这个返回值形状,路由成一个 Activity 事件(`activityType: "a2ui-surface"`)发给客户端,同时按 Spring AI 默认行为让返回值正常进入模型对话历史(D7,不做额外拦截)。
  - 验收:调用聊天接口触发这个工具,SSE 输出里有一个 activity 事件,内容是合法的 `a2ui_operations` JSON,能通过 `a2ui-authoring` 规则做的人工检查(surface/组件/数据模型结构正确)。
  - 验证:`./mvnw test` + 手动 curl,把返回的 JSON 拿去过一遍 Task 1.2 已经验证过的客户端渲染(用 mock 数据替换成这个真实返回值,确认还能渲染)。
  - 依赖:2.3b
  - 文件:后端新建工具类
  - 规模:M

- [ ] **Task 2.5(可选,不阻塞主线): Reasoning 事件**
  - 描述:如果 2.1 的模型 provider 支持推理内容暴露,追加 Reasoning 事件类型。
  - 验收:换成支持推理的模型配置后,SSE 里能看到 reasoning 事件。
  - 验证:手动 curl,临时切换模型配置测试。
  - 依赖:2.3a
  - 文件:事件管线追加
  - 规模:S

#### Checkpoint 4
- [ ] 后端新事件管线完整跑通,curl 能验证文本、工具、A2UI 卡片(以及可选的推理)。

### Phase 3: 打通客户端和后端

- [ ] **Task 3.1: 客户端 `_parseSseStream` 改造成解析新事件**
  - 描述:把 Task 2.2-2.4 定稿的事件格式对应到客户端解析逻辑。
  - 验收:单元测试覆盖新事件解析(文本/工具/activity 三类)。
  - 验证:`flutter test`
  - 依赖:Checkpoint 4、Checkpoint 2
  - 文件:`mobile/lib/api/chat_api_service.dart`、`mobile/lib/api/models/chat_models.dart`
  - 规模:M

- [ ] **Task 3.2: `_consumeStreamEvents` 改造,替换 Task 1.3b 的临时 mock 接线**
  - 描述:把 Task 1.3b 里"临时接 mock"的代码换成真实解析出的后端事件。
  - 验收:端到端——发一条会触发 AI 生成卡片的真实消息,聊天界面里文字和卡片按 AI 实际生成顺序混排出现;关闭重开聊天,原样复现,不重新请求后端。
  - 验证:真机/模拟器手动跑一遍完整流程。
  - 依赖:3.1
  - 文件:`mobile/lib/providers/chat_providers.dart`
  - 规模:M

#### Checkpoint 5(最终验收)
- [ ] 对照 spec 的 Success Criteria 逐条勾选确认。

- [ ] **Task 3.3: 清理——删除 `ChatToolCallCard` 及废弃代码**
  - 描述:确认 `ChatToolCallCard` 及相关 `TOOL_CALL`/`TOOL_RESULT` 专用渲染逻辑无其它调用点后删除。
  - 验收:全项目搜索无引用;`flutter analyze` 干净。
  - 验证:`grep -r ChatToolCallCard mobile/lib` 无结果;`flutter analyze`。
  - 依赖:3.2
  - 文件:`mobile/lib/page/chat/widgets/chat_message_widgets.dart`
  - 规模:XS

## Risks and Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| Task 1.2 发现 `Surface`/`SurfaceController` 塞进滚动列表有生命周期问题(多个 controller 未正确释放、rebuild 导致重新创建) | 高——这是整个客户端方案的地基 | 放在 Phase 1 最前面独立验证,失败了影响范围局限在客户端,不牵连后端投入 |
| Task 1.3a 发现"临时直播 controller 交接给持久化 controller"会闪烁或漏释放 | 高——直播态是用户实际能感知到的体验 | 用最小闭环单独验证,失败了只影响 Task 1.3b 的具体实现方式,不影响已完成的 1.1/1.2 |
| Task 2.1 发现具体模型 provider 不支持分块工具调用参数 | 中——只影响 `ToolCallArgs` 这一个事件的粒度,其余事件不受影响 | 放在 Phase 2 最前面,失败了退化为 Start+Result,回头改 spec D2,不影响已完成的 Phase 1 |
| Task 1.3b 的临时 mock 接线和 Task 3.2 的真实接线之间的过渡代码遗留 | 低——代码整洁度问题 | Task 1.3b 的临时代码明确标注"过渡,Task 3.2 会替换",Task 3.2 完成后检查是否有遗留 |
| Phase 2 工作量比 Phase 1 大很多(后端事件重设计涉及面广) | 中——排期不对称 | Phase 2 内部已经按"文本→工具→A2UI→推理"拆成更小的任务,可以在 Checkpoint 3 之后先给用户看一版可用的文本+工具事件,再继续做 A2UI/推理 |

## Open Questions

无——spec 阶段的开放问题已在本计划的 Architecture Decisions 里给出具体设计(`UI_SURFACE` 命名已定)。`ChatStreamingBubble` 生命周期管理原本打算留到实现时再定,已改为 Task 1.3a 的显式 spike,不再是未验证的假设。
