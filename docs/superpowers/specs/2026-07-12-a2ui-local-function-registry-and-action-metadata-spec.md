# Spec: A2UI 本地函数注册入口收口 + event 提交补充 actionName/actionContext

## Objective

现在 A2UI 卡片的两种交互分支(`functionCall` 本地执行 / `event` 往返后端)在协议和 genui 包里都已经实现,但 PocketMind 自己的接线有两处缺口:

1. **本地函数没有统一注册入口**:每个 `SurfaceController` 建立处各自现场拼 `BasicCatalogItems.asCatalog()`,没有任何地方合并过自定义 `ClientFunction`。以后要给卡片加"点击本地跳转""复制到剪贴板"之类的本地能力,不知道该改哪。
2. **`event` 提交时,genui 已经给出的 `action.name`/`action.context` 被客户端直接丢弃**,只发整份 `dataModel` 快照。这在"按钮的语义就是动作名本身、不反映在 dataModel 里"的场景(如已有 spec 里 D6 举的"帮我深入分析"例子)下,后端/LLM 完全无法分辨用户点的是哪个按钮。

这次只解决这两处接线缺口本身,不涉及具体新增哪个本地函数,也不涉及后端要不要按 `actionName` 做业务分流(见"本次不覆盖")。

用户是本项目维护者本人,验收方式是读代码确认改动位置符合本 spec、`flutter analyze`/相关 widget test 通过。

## 背景调研(已核实的代码现状,不是假设)

- genui 的 `Button`/`TextField`/`ChoicePicker` 等交互组件内部都实现了 `action.event`(dispatch `UserActionEvent`)vs `action.functionCall`(查 `Catalog.functions`)两分支的调度(如 `genui-0.8.0/lib/src/catalog/basic_catalog_widgets/button.dart:198-243`)。这套分支是 genui 官方实现,不需要 PocketMind 重新造。
- `Catalog.functions` 是一个 `Map<String, ClientFunction>`,`Catalog.copyWith(newFunctions: [...])`(`catalog.dart:59-88`,同名覆盖、其余合并)是官方给的"本地函数注册表"扩展点。PocketMind 目前每处 `SurfaceController` 建立(`chat_message_widgets.dart:336`、`:521`,以及 `mobile/lib/demo/a2ui/*` 各 demo 页)都只传 `BasicCatalogItems.asCatalog()` 原样,从未 `copyWith` 过。
- genui `SurfaceController.handleUiEvent`(`surface_controller.dart:255-268`)把 `UserActionEvent` 的完整信息(`name`/`sourceComponentId`/`context`)打进 `onSubmit` 流,具体形式是一条 `ChatMessage`,携带 `UiInteractionPart`,JSON 为 `{"version":"v0.9","action":{...}}`。这份信息本身是完整的。
- PocketMind 自己在 `chat_message_widgets.dart:533-541`(`_A2uiCardMessageState` 的 `onSubmit.listen`)把这条 `ChatMessage` 直接丢弃(`listen((_) { ... })`),转而读取当前 surface 的整份 `dataModel` 快照,通过 `chat_message_widgets.dart:54-66` 的默认 `onSubmitted` 回调序列化成 `{surfaceId, dataModel}`,发到 `chatSendProvider.send(...)` → `POST /{sessionUuid}/messages`(`ChatController.java:166-186`)→ 无条件进 `aiChatService.streamReply`。
- 已核实 `AiChatService.toSpringAiMessages`(`AiChatService.java:453-484`)**已经实现**了跨轮工具历史重建(把 `TOOL_CALL`/`TOOL_RESULT` 重建成 `AssistantMessage(toolCalls)` + `ToolResponseMessage` 喂回模型),不是停留在计划阶段。这意味着模型在任意后续轮次都能看到自己生成过的 A2UI 卡片的完整工具结果(如检索到的笔记列表全文),`dataModel` 快照不需要重复承载这些业务内容,它真正承载的是"用户在 UI 上做了什么选择"(选中的 id、勾选状态、输入的文本)。
- 这两点结论已和用户在对话中逐条确认,参见既有的 `2026-07-05-chat-a2ui-agui-integration-spec.md` 的 D6(本地/往返二选一逐组件写死)、D12(跨轮工具历史)、D13(fixed-schema)、D15(`sendDataModel` 机制、reload 定格回放)——本 spec 是在那份决策基础上的一个独立小增量,不修改那份文档,只引用。

## 决策

### Decision 1:新增共享 A2UI Catalog 单例,收口本地函数注册入口

- 新建一个共享的 `Catalog` 实例(建议命名 `pocketMindA2uiCatalog`,放在贴近现有 `mobile/lib/util/a2ui_card_util.dart` 的位置,或新开一个同级小文件——实施时按体量定,不强制),等于:
  ```dart
  final pocketMindA2uiCatalog =
      BasicCatalogItems.asCatalog().copyWith(newFunctions: PocketMindClientFunctions.all);
  ```
- `PocketMindClientFunctions.all` **本次新增一个用于验证的 `OpenNoteFunction`**(见 Decision 1a),不是空列表——目的除了收口入口,也顺带证明这个入口真的能跑通(genui 0.9.2 之前不导出 `ClientFunction` 类型,无法验证,见 Decision 1a)。以后再加本地函数,只改这一个列表,不用再碰任何 `SurfaceController` 建立点。
- 生产代码里构造 `SurfaceController` 的地方(`chat_message_widgets.dart:336`、`:521`)统一改传这个共享实例,不再各自现场拼 `BasicCatalogItems.asCatalog()`。
- demo/mock 页面(`mobile/lib/demo/a2ui/*`)是否也切换,由实施时视改动量决定,不强制、不影响本次验收。

### Decision 1a:genui 升级到 0.9.2,`OpenNoteFunction` 作为验证用的第一个本地函数,新开 demo 页验证

**背景(2026-07-12 补充决策,实施过程中发现并核实)**:
- 起初核实 genui `0.8.0` 时发现 `ClientFunction`/`SynchronousClientFunction`/`ExecutionContext` 这几个类型**没有从 `package:genui/genui.dart` 导出**——只存在于 `lib/src/model/client_function.dart`,`catalog.dart` 内部 `import` 但没有 `export`。这不是协议设计的限制:`a2ui/docs/guides/defining-your-own-catalog.md` 明确写"大部分生产应用会自己定义 catalog(含组件和函数)",且 TS 参考渲染器(`a2ui/renderers/web_core/src/v0_9/catalog/types.ts`)把 `FunctionApi`/`FunctionImplementation`/`createFunctionImplementation` 完整公开导出——本地函数扩展在协议和其他语言实现里都是一等公民能力,只是 genui(Flutter 这条线)当时文档写着"Flutter 详细指南还没写",导出也没跟上。
- genui `0.9.2` 已发布,`0.9.0` 的 CHANGELOG 写"**BREAKING**: Reorganized library exports (#866)"。核实后确认 `src/model.dart`(经 `genui.dart` 导出)现在包含 `export 'model/client_function.dart';`——`ClientFunction` 等类型已可以正常 `import 'package:genui/genui.dart'` 拿到,不需要再绕 `src/` 内部导入。
- 升级到 0.9.2 顺带发现一个**未在 CHANGELOG 记录的破坏性变更**:内置常量 `basicCatalogId` 的值从 `.../standard_catalog.json` 改成了 `.../basic_catalog.json`(`lib/src/primitives/constants.dart`)。PocketMind 多处(mobile 的 demo/mock/测试文件,以及**后端生产代码** `A2uiChoiceCardToolSet.java`)手写了一份重复的旧 URL 字符串,没有引用 genui 导出的常量,升级后这些地方的卡片会因 `catalogId` 对不上而渲染失败——这属于本次升级必须一并处理的回归,不是范围外的事。

**决策**:
- `mobile/pubspec.yaml` 的 `genui` 版本约束改为 `^0.9.2`。
- 所有硬编码旧 catalogId 字符串的地方,改成引用 genui 导出的 `basicCatalogId` 常量(Dart 侧)或同步更新成新字符串值并加注释说明要跟 genui 版本保持一致(Java 后端侧,因为不能跨语言直接引用 Dart 常量)。涉及文件:`mobile/lib/demo/a2ui/*`(chat_streaming_mock.dart、surface_handoff_lifecycle_demo_page.dart、chat_card_lock_mock.dart、chat_block_sequence_mock.dart、a2ui_stream_api_service.dart)、`mobile/test/**`(a2ui_card_message_lock_test.dart、a2ui_card_util_test.dart、chat_streaming_bubble_test.dart、chat_list_formatter_test.dart)、`backend/.../ai/application/tool/A2uiChoiceCardToolSet.java`、`backend/.../ai/context/PersistingToolCallAdvisorTest.java`。
- `PocketMindClientFunctions.all` 新增 `OpenNoteFunction`(`SynchronousClientFunction` 的实现):参数直接带够跳转要用的数据(`noteUuid`/`title`/`content`),不查询 Isar/Riverpod——需要什么数据,让生成这个 `functionCall` 的一方直接放进 `args`。用 `mobile/lib/router/app_router.dart:27` 现成的 `appNavigatorKey`(专门给不在 `BuildContext` 里的场景用)做真实 `go_router` 跳转,落到已有的 `RoutePaths.noteDetail`。
- 新开一个 demo 页(挂在 `genui_demo_hub_page.dart` 下),放一张硬编码卡片,列表项点击后触发 `openNote`,验证真的跳转到笔记详情页——这是验证 Decision 1 的注册入口真的生效,不是要交付"点击笔记卡片跳转"这个产品功能本身(那需要真实业务场景接入,见"本次不覆盖")。

### Decision 2:`event` 提交 payload 补充 `actionName`/`actionContext`,`dataModel` 全量回传机制不变

- `chat_message_widgets.dart:533-541` 的 `onSubmit` 监听,改成解析 genui 吐出的那条 `ChatMessage`(取出 `UiInteractionPart` 里 `action.name`/`action.context`),连同现有的整份 `dataModel` 一起,以 `{surfaceId, actionName, actionContext, dataModel}` 的形式传给 `onSubmitted` 回调,取代现在的 `{surfaceId, dataModel}`。
- **不改** `dataModel` 全量回传的机制,**不改** reload 时 `updateDataModel(path:'/')` 回放定格显示最终态的逻辑(既有 spec D15)——两者只关心 `dataModel` 本身,和 `actionName` 无关,互不干扰,是纯加字段,不是替换。
- **本次后端不做任何改动**:`ChatController.sendMessage` 照常把这段 JSON 当纯文本喂给 `aiChatService.streamReply`,LLM 自己从 JSON 里读 `actionName`。这次只是让这个字段存在并送达,不是让后端专门解析或按它分流。

## 本次不覆盖(明确排除,记录为已知扩展点)

- **`openNote` 接入真实业务场景**(比如后端检索笔记工具生成的卡片真的用上它):demo 页只验证机制,不代表这个函数已经在生产聊天卡片里被使用。真实接入需要业务场景确认(检索笔记工具返回什么数据、卡片长什么样),留到有需求时再做。
- **后端按 `actionName` 分流、可绕开 LLM 执行确定性业务动作**(例如"把这段聊天保存成笔记"直接调笔记服务,不进 LLM 对话):**不设计、不搭骨架**。目前没有真实业务场景(用户已确认这类场景目前不存在),提前设计分流 dispatcher 是纯猜测的抽象,违反 YAGNI。等出现第一个需要绕开 LLM 的确定性动作时,再单独写决策/plan——那会改到 `ChatController`/`AiChatService` 的请求处理主干,属于新范围,需要重新走一遍 spec 流程。
- 与 A2UI/genui 渲染、reload、锁定态相关的既有机制(D3-D15)一律不动。

## 项目结构(受影响文件)

```
mobile/pubspec.yaml                             → genui 版本约束升到 ^0.9.2
mobile/lib/util/pocketmind_a2ui_catalog.dart(新) → pocketMindA2uiCatalog 单例 + OpenNoteFunction
mobile/lib/page/chat/widgets/chat_message_widgets.dart → SurfaceController 建立处切换到共享 catalog;
                                                          onSubmit 监听解析 action.name/context,
                                                          onSubmitted payload 增加 actionName/actionContext
mobile/lib/demo/a2ui/*(catalogId 引用修复)、新增 openNote 验证 demo 页 + 挂到 genui_demo_hub_page.dart
mobile/test/**(catalogId 引用修复)
backend/.../ai/application/tool/A2uiChoiceCardToolSet.java → 同步 catalogId 新值(Decision 1a)
backend/.../ai/context/PersistingToolCallAdvisorTest.java  → 同步 catalogId 新值(Decision 1a)
```

## 测试策略

- `flutter analyze` 通过。
- 现有 widget test(`mobile/test/widget/a2ui_card_message_lock_test.dart`、`mobile/test/util/a2ui_card_util_test.dart`)不能回归;`onSubmitted` payload 形状变化后,补一个断言:提交时回调收到的 map 含 `actionName`(genui demo 里现成的 `event.name` 例子,如 `button_pressed`)。
- 手动验证:在真实聊天里触发一次卡片 `event` 提交,确认发给后端的 JSON content 里带 `actionName`/`actionContext` 字段,且 `dataModel` 内容和改动前一致(reload 定格态不受影响)。

## 边界(Always / Ask First / Never)

- **Always**:`onSubmitted` payload 新增字段前,确认 reload/锁定态判断逻辑(靠 `surfaceId` 是否有对应提交消息)没有被牵动。
- **Ask first**:要把 demo/mock 页面也切到共享 catalog 之前(不是本次强制项);要给 `PocketMindClientFunctions.all` 加第一个具体本地函数之前(那是新范围,需要单独确认要支持哪些函数、navigate 类函数怎么拿到 `BuildContext`/本地数据)。
- **Never**:在本 spec 范围内动 `ChatController`/`AiChatService` 的请求分流逻辑;修改 `2026-07-05-chat-a2ui-agui-integration-spec.md` 里已经定稿的决策(D1-D15);把 dataModel 全量回传替换成只发 `actionName`(两者要并存,不是二选一)。

## Success Criteria

- 所有生产代码构造 `SurfaceController` 的地方引用同一个 `pocketMindA2uiCatalog` 实例。
- 触发一次卡片 `event` 提交,发给后端的 payload 里能看到 `actionName`(和有 `context` 时的 `actionContext`),且 `dataModel` 字段内容、reload 定格显示效果与改动前一致。
- `flutter analyze` 和相关 widget test 通过。

## Open Questions

无——范围已通过对话逐条确认(注册入口本次只搭骨架不接具体函数;actionName 只加字段不改既有机制;后端分流骨架本次不做)。
