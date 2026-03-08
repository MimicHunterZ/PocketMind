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




## Health

> 需要鉴权（当前配置）：`Authorization: Bearer <token>`

- `GET /api/health/check`

Response `data`:
```json
"OK"
```
