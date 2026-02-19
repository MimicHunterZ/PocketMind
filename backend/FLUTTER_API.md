# PocketMind Backend API（给 Flutter 前端）

## 约定

### Base URL
- 本地开发：`http://localhost:8080`
- 所有接口统一前缀：`/api`

### 鉴权
- 除 `/api/auth/**` 之外，`/api/**` 都需要携带 JWT。
- Header：`Authorization: Bearer <token>`

### Content-Type
- 请求：`Content-Type: application/json`

### 统一响应结构（所有成功响应都会被包装）
后端会把所有 Controller 返回值统一包装为：

```json
{
  "code": 200,
  "message": "success",
  "data": {},
  "traceId": "..."
}
```

- `code`：数字业务码（`200` 表示成功）
- `message`：提示文案（成功时一般为 `success`；失败时为错误提示）
- `data`：业务数据（不同接口不同）
- `traceId`：后端日志链路标识（排查问题用）

### 常见错误码（节选）
- `400001`：参数校验失败
- `401001`：未授权（缺 token / token 无效）
- `401002`：用户名或密码错误
- `409001`：用户名已存在
- `500000`：服务器内部错误

> 备注：HTTP Status 仍可能返回 4xx/5xx，但前端应优先使用 `code/message` 做业务判断与展示。

---

## Auth

### 1) 注册
- `POST /api/auth/register`

Request:
```json
{
  "username": "test",
  "password": "123456"
}
```

Response `data`:
```json
{
  "userId": "...",
  "token": "...",
  "expiresInSeconds": 86400
}
```

cURL:
```bash
curl -X POST "http://localhost:8080/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456"}'
```

### 2) 登录
- `POST /api/auth/login`

Request:
```json
{
  "username": "test",
  "password": "123456"
}
```

Response `data`（同注册）：
```json
{
  "userId": "...",
  "token": "...",
  "expiresInSeconds": 86400
}
```

---

## Resource

> 需要鉴权：`Authorization: Bearer <token>`

### 1) 提交资源 URL
- `POST /api/resource/submit`

Request:
```json
{
  "url": "https://example.com/article"
}
```

Response `data`:
```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000"
}
```

cURL:
```bash
curl -X POST "http://localhost:8080/api/resource/submit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"url":"https://example.com/article"}'
```

### 2) 查询处理状态（批量）
- `POST /api/resource/status`

Request:
```json
{
  "urls": [
    "https://example.com/article",
    "https://x.com/someone/status/123"
  ]
}
```

Response `data`：数组，每项 data 结构如下(后端没有对应url的值那么返回就是空的)：
```json
{
  "url": "https://example.com/article",
  "title": "...",
  "previewContent": "...",
  "aiSummary": "...",
  "status": "PENDING"
}
```

`status` 枚举值：
- `PENDING`：已提交，等待处理
- `CRAWLED`：已抓取
- `EMBEDDED`：已完成（可理解为最终完成态）
- `FAILED`：处理失败

> 说明：如果抓取/处理失败，相关字段可能为 `null`，前端可根据 `status` + 字段是否为空展示“预览失败/可重试”。

---

## AI Analyse Stream

> 需要鉴权：`Authorization: Bearer <token>`

### 流式分析网页（SSE）
- `POST /api/ai/analyze/stream`

Request:
```json
{
  "url": "https://example.com/article",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "previewTitle": "...",
  "previewContent": "...",
  "userQuestion": "我想问：这篇文章的核心观点是什么？"
}
```

- `url` 必传。
- `uuid/previewTitle/previewContent/userQuestion` 可选。
- `userQuestion` 为空：按总结模式输出。
- `userQuestion` 不为空：创建 chat session + user/assistant 两条 message，并边输出边增量落库。

返回：`text/event-stream`，事件约定：
- `meta`：初始化元信息（`mode`，QA 模式下包含 `threadId/sessionUuid/userMessageUuid/assistantMessageUuid`）
- `delta`：AI 输出增量（字符串）
- `done`：结束
- `error`：异常（包含 `code/message`）

---

## Health

> 需要鉴权（当前配置）：`Authorization: Bearer <token>`

- `GET /api/health/check`

Response `data`:
```json
"OK"
```
