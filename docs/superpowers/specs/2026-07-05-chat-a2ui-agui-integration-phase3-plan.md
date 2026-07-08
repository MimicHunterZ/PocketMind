# Phase 3 实施方案:打通客户端和后端

对应 spec/plan: `2026-07-05-chat-a2ui-agui-integration-spec.md`(D1–D15)、`...-plan.md`(Phase 3)

## 出发点:Phase 3 的真实工作量比 plan 预想的小

探索后确认,Phase 1/2 已经把两端各自做完了,只差一层翻译:

- **后端(Phase 2 已完成)**:`SseReplyService` + `PersistingToolCallAdvisor` 已经输出对齐 `ag_ui ^0.3.0` 的细粒度事件(camelCase 字段):
  `RUN_STARTED` / `TEXT_MESSAGE_START` / `TEXT_MESSAGE_CONTENT` / `TEXT_MESSAGE_END` / `TOOL_CALL_START` / `TOOL_CALL_END` / `TOOL_CALL_RESULT` / `ACTIVITY_SNAPSHOT` / `RUN_FINISHED` / `RUN_ERROR` / `CUSTOM`(name=`chat.paused`)。
- **前端消费层(Task 1.5 已完成)**:`chat_providers.dart` 的 `_consumeStreamEvents` 已经 switch 处理内部 sealed `ChatStreamEvent`(`ChatDeltaEvent`/`ChatToolCallStartEvent`/`ChatToolCallEndEvent`/`ChatA2uiChunkEvent`/`ChatDoneEvent`/`ChatPausedEvent`/`ChatErrorEvent`),生产 `send()` 走的就是这条路(mock 只在 demo 预览页 `override`,没污染生产)。
- **唯一缺口 = `_parseSseStream`(`chat_api_service.dart:290`)**:仍然只解析旧的 `delta`/`done`/`paused`/`error` 四件套,而后端已经不发这些了。这层负责把新 wire 格式翻译成内部 sealed 事件。

因此 Phase 3 = **改一层解析 + 修几个端到端才暴露的契约错配**,不是大改。

## 端到端才暴露的契约错配(必须处理)

mock 阶段两端各自用"裸 envelope + 内部 sealed 事件"验证过,以下错配只有真接后端才暴露:

### E1. `RUN_FINISHED` 不带 assistant messageUuid(已决策:后端补)

- 内部 `ChatDoneEvent` 需要 `messageUuid`(分支/重新生成场景要 `syncMessages(leafUuid)` + 切 `activeLeaf`)。
- 后端 `RunFinished(threadId, runId)` 不带。`ag_ui` 的 `RunFinishedEvent.result` 是 `z.any().optional()`,合法。
- **决策(已确认)**:后端 `handleDoneTerminal` 已知 `assistantMsgUuid`,放进 `RunFinished` 的 `result`。前端 `RUN_FINISHED` → `ChatDoneEvent(messageId, requestId=runId)`。

### E2. A2UI reload 判别失败:持久化 content 是"工具结果包装",不是裸 envelope

- 后端 `PersistingToolCallAdvisor.toToolResultJson` 落库的 `TOOL_RESULT` content 形如:
  `{"toolCallId":"...","name":"renderChoiceCard","result":"<转义的 A2UI envelope JSON 字符串>"}`
- 但前端 `tryParseA2uiCard`(`a2ui_card_util.dart`)直接对 content 试解析**裸 envelope**。mock 阶段 content 就是裸 envelope,所以没暴露;**reload 时会判别失败,A2UI 卡片退化成 `ChatToolCallCard`**。
- `result` 字段被 `writeJson` 整体再序列化,是**转义字符串**,剥包装后还要再 `jsonDecode` 一次才是 envelope(可能是单条 Map 或多条数组)。
- ⚠️ 不能改用 `ChatMessageModel.toolData.result`:后端 `parseToolCallData` 对它做了 **500 字符截断**(`ChatController.java:329`),envelope 通常超长会拿到坏 JSON。**必须用完整 `content` 字段**。
- **修法(前端,不动后端两处依赖)**:`tryParseA2uiCard` 增加"先尝试剥工具结果包装"的前置分支——若 content 解析出的 Map 恰好是 `{toolCallId, name, result}` 形状,取 `result`(再 `jsonDecode`)作为待判别的 envelope;否则按原逻辑直接判别(兼容流式裸 envelope 落库的可能形状)。判别成功=A2UI 卡片,失败=普通工具。
  - 后端 `parseToolResult`(D12 跨轮历史)和 `parseToolCallData`(响应映射)都依赖这个包装形状,**保持不动**。

### E3. `ACTIVITY_SNAPSHOT.content` 是对象/数组,内部 `ChatA2uiChunkEvent` 期望单条消息 JSON 字符串

- 后端 emit `ActivitySnapshot(uuid, "a2ui-surface", a2uiEnvelope)`,`content` 是**已解析的 List<Map>**(operations 数组),一次一张完整卡片。
- 内部 `ChatA2uiChunkEvent(String json)` 期望**单条** A2UI 消息的 JSON 字符串(`_LiveA2uiCardMessage` 用 `addChunk` 逐条喂,一条一条 `A2uiMessage.fromJson`)。
- **修法(解析层)**:`ACTIVITY_SNAPSHOT` → 把 `content`(数组或单对象)拆成逐条,每条 `jsonEncode` 成字符串,依次 yield `ChatA2uiChunkEvent`。这样流式态 `_LiveA2uiCardMessage` 的现有逻辑不用改。

### E4. 流式 A2UI 卡片"交接"到持久化消息:两条判别入口要统一

- 流式态用裸 envelope 逐条喂(`ChatA2uiChunkEvent` → `_LiveA2uiCardMessage`);reload/落库后走 `ChatMessageBubble` → `tryParseA2uiCard`(E2 修好后能识别)。
- Task 1.4 已验证交接机制;这里只需保证 E2 修好后,流结束 `syncMessages` 落库的那条 `TOOL_RESULT` 能被 `tryParseA2uiCard` 正确识别成卡片,视觉上无缝交接。

## Task 拆分

### Task 3.0(后端,E1):`RUN_FINISHED` 带 assistant messageId

- 改 `SseReplyService.handleDoneTerminal`:`new AgUiEvent.RunFinished(sessionUuid, requestId, assistantMsgUuid.toString())`。
- `AgUiEvent.RunFinished` 已支持带 `result` 字段(`fields()` 里 `result != null` 才 put),无需改协议类。
- 验收:curl 一轮回复,`RUN_FINISHED` 事件 data 里含 `result: "<uuid>"`。
- 验证:`./mvnw test`(补/改 `SseReplyServiceTest` 或 `AgUiEventTest` 断言 result 存在)+ 手动 curl。
- 文件:`SseReplyService.java`
- 规模:S

### Task 3.1(前端,E2):`tryParseA2uiCard` 兼容工具结果包装

- 在 `a2ui_card_util.dart` 的 `tryParseA2uiCard` 前置一步:content 解析成 Map 且形如 `{toolCallId,name,result}` 时,取 `result` 字符串再 `jsonDecode` 得到待判别对象;否则用原始 decoded。后续判别逻辑不变。
- 验收:对"后端包装形状的 TOOL_RESULT content"(result 里嵌套 A2UI 数组)返回卡片 operations;对"普通工具包装"(result 是纯文本)返回 null;对"裸 envelope"(mock 老形状)仍返回卡片(向后兼容)。
- 验证:`flutter test`(扩充 `test/util/a2ui_card_util_test.dart`,加后端包装形状用例)。
- 文件:`mobile/lib/util/a2ui_card_util.dart`、`mobile/test/util/a2ui_card_util_test.dart`
- 规模:S

### Task 3.2(前端,E3 + 解析层):`_parseSseStream` 改造为解析新 AG-UI 事件

- 重写 `chat_api_service.dart` 的 `_parseSseStream` 的 `emitCurrentEvent`,按 `event:` 名称映射(SSE `event` 帧名 = AG-UI type,大写下划线):
  - `TEXT_MESSAGE_CONTENT` → `ChatDeltaEvent(data.delta)`
  - `TEXT_MESSAGE_START` / `TEXT_MESSAGE_END` / `RUN_STARTED` / `STEP_*` → 忽略(内部块序列不需要,文本块靠 delta 累积)
  - `TOOL_CALL_START` → `ChatToolCallStartEvent(toolCallId, toolCallName)`
  - `TOOL_CALL_END` → `ChatToolCallEndEvent(toolCallId)`
  - `TOOL_CALL_RESULT` → 忽略(普通工具结果的最终态靠流结束后 `syncMessages` 落库复现,过渡态不需要;与 spec D5/D9"结果最终态不走流式回放"一致)
  - `ACTIVITY_SNAPSHOT` → 把 `content`(数组/对象)拆成逐条 `ChatA2uiChunkEvent`(每条 `jsonEncode`)
  - `RUN_FINISHED` → `ChatDoneEvent(result 里的 messageId, requestId=runId)`
  - `RUN_ERROR` → `ChatErrorEvent(message)`
  - `CUSTOM` + `value.name == "chat.paused"` → `ChatPausedEvent(requestId, messageUuid)`(注:后端 `Custom(name, value)`,value 里是 `{requestId, messageUuid}`)
- **判别是否复用 `ag_ui` 包的 `BaseEvent.fromJson`(D11)**:倾向**不引入** `BaseEvent.fromJson` 到解析主路径——`_parseSseStream` 已有成熟的行缓冲/UTF-8 分块/多行 data 处理(现存测试覆盖 markdown 结构),事件 payload 是扁平小 JSON,直接 `jsonDecode` + 取字段最省(ponytail:已装的解析器够用,不为一层薄映射引入包类型转换)。`ag_ui` 包留给需要它的场景(demo)。若评审希望严格对齐,可在 `emitCurrentEvent` 里改用 `BaseEvent.fromJson` 再 switch 具体事件类型——两种都列,推荐前者。
- 保留旧 `delta`/`done`/`paused`/`error` 分支?**删除**(D8 不做兼容;后端已不发)。同步更新 `test/api/chat_api_service_sse_parse_test.dart`:markdown 结构类用例改用 `TEXT_MESSAGE_CONTENT` 帧;`done` 用例改 `RUN_FINISHED`。`assets/mock/response`(旧 delta 格式)对应的回放测试改造或替换为新格式样本。
- 验收:单测覆盖新事件解析(文本累积、工具 start/end、activity 拆条、run_finished 取 messageId、paused、error)。
- 验证:`flutter test test/api/chat_api_service_sse_parse_test.dart`。
- 文件:`mobile/lib/api/chat_api_service.dart`、`mobile/lib/api/models/chat_models.dart`(`ChatDoneEvent` 已有 messageUuid/requestId,无需改;确认即可)、`mobile/test/api/chat_api_service_sse_parse_test.dart`
- 规模:M

### Task 3.3:端到端手动验收 + 字段对齐核对(D11 / plan Task 3.3)

- 起后端 + 真机/模拟器,跑 spec Success Criteria 里本轮范围内的条目:
  1. AI 一轮回复文字中间插入至少一种卡片,顺序符合生成顺序(块序列)。
  2. 关闭重开会话,文字/工具记录/卡片原样复现(E2 验证点:卡片 reload 不退化成工具卡)。
  3. 功能型工具被调用时显示 `TOOL_CALL_START/END` 临时进度提示,不落库。
  4. (D12,已在 Phase 2 做)多轮追问"刚才那个结果里的 X",模型能基于上轮工具结果回答。
- 逐字段核对后端 SSE 输出与 `ag_ui ^0.3.0` 事件类(camelCase),重点:`RUN_FINISHED.result`、`ACTIVITY_SNAPSHOT.content`、`CUSTOM.value`。
- `grep` 确认无 Task 1.5 遗留过渡代码进入生产路径(已确认 mock 仅在 demo 预览页 override,复核)。
- 验证:真机手动 + `flutter analyze`。
- 规模:S

## 本轮不做(留下一轮,已与用户确认)

- **卡片交互提交往返(D15 的"提交发回后端落库")**:生产环境 `a2uiCardSubmitHandlerProvider` 暂仍为空实现(卡片可交互、可本地写 dataModel,但点"确认"不发请求、不落库)。需要给后端 `SendMessageRequest` 加 `dataModel` 字段并落库为新 USER 消息——单独一轮做。
- 因此本轮"reload 复现"验证的是 **AI 生成的卡片**原样复现(E2/E4),不含"用户提交后定格锁定"的端到端(那条链的后端落库还没接)。锁定态渲染规则(Task 1.6)已实现,mock 已验证,接后端提交后自然生效。

## 边界(Always / Ask First / Never)

- **Always**:每步跑对应测试;后端改 `RunFinished` 后先 curl 看 wire 输出再动前端;前端事件字段以 `ag_ui ^0.3.0` 包源码为准。
- **Ask First**:若 Task 3.2 评审倾向"必须用 `BaseEvent.fromJson` 严格对齐"而非直接取字段(两种方案已在 Task 3.2 列出)。
- **Never**:改动后端 `toToolResultJson` 包装形状 / `parseToolResult`(D12 跨轮历史)/ `parseToolCallData`(E2 用前端剥包装规避,不动后端);为兼容旧 `delta`/`done` 事件保留死代码(D8);本轮接卡片提交往返(移出范围)。

## 依赖顺序

Task 3.0(后端 result)→ Task 3.1(前端剥包装)+ Task 3.2(解析层,可与 3.1 并行)→ Task 3.3(端到端验收)。
