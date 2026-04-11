# GenUI 真实流样例

本文档记录 `/api/ai/genui/sessions/{sessionUuid}/stream` 的标准事件样例，用于移动端联调与真实链路对齐。

## 请求示例

```http
POST /api/ai/genui/sessions/demo-genui-mixed-stream/stream HTTP/1.1
Content-Type: application/json
Accept: text/event-stream
X-Request-Id: req-demo-001

{"query":"请分析跨端同步并给出执行计划"}
```

## 响应事件序列（关键帧）

1. `event: delta` + `createSurface(main)`
2. `event: delta` + 初始化 `streamMessage/questionEcho/root`
3. 多次 `event: delta` + `updateDataModel(/md/content)`（Markdown 增量）
4. `event: delta` + `updateComponents(SourceReferenceCard)`
5. 继续 `updateDataModel(/md/content)`
6. `event: delta` + `updateComponents(TaskChecklist)`
7. 继续 `updateDataModel(/md/content)`
8. `event: delta` + `updateComponents(ActionButtonGroup)`
9. `event: delta` + `streamMessage isLoading=false`
10. `event: done` + `{"messageUuid":"...","requestId":"req-demo-001"}`

## SSE 解析约束

- 支持同一事件内多行 `data:`，客户端需合并后再解析。
- 空行表示单个事件帧结束。
- 行尾可能为 `\n` 或 `\r\n`。

## 设计说明

- 文本与生成式 UI 必须在同一个 surface 内按事件顺序混合输出。
- 不允许一次性提前下发全部组件，避免“UI 先出、叙事后到”的割裂体验。
- 移动端必须消费同一 `delta/done/error` 协议，禁止本链路 fallback 到 mock 数据源。
