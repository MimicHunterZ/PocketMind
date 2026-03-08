# 数据职责边界

## Note
`Note` 是客户端主读模型。

保留职责：
- 用户纯文本内容
- 分享入口信息
- 展示投影字段
- 同步字段

过渡期保留字段：
- `previewTitle`
- `previewDescription`
- `previewContent`
- `summary`
- `resourceStatus`
- `memoryPath`

其中：
- `preview*` 是资源展示投影
- `summary` 是 AI/Memory 展示投影
- `memoryPath` 是上下文根指针候选

## Asset
`Asset` 只负责物理文件与媒体原件。

典型对象：
- PDF 原件
- Markdown 文件原件
- 图片
- 音频
- 视频

## Resource
`Resource` 是 AI 可读内容层。

典型对象：
- 网页抓取正文
- OCR 文本
- PDF 提取文本
- Markdown 规范化文本
- 聊天归档文本

## Memory
`Memory` 是从 Resource 与 Chat 提取出的用户长期知识。

首版分类：
- `profile`
- `preferences`
- `entities`
- `events`

## Skill
`Skill` 是多租户 AI skills。

典型内容：
- Prompt 模板
- Tool 使用策略
- 系统能力定义
- 工作流说明

## 重要约束
- 不要把 `Note` 整体迁成文件系统读取模型
- 不要把 `Asset` 直接当成 Resource 正文来源
- 不要把 `summary` 当成长期记忆真相源
