# Markdown 渲染能力测试

本文档用于测试流式 Markdown 渲染,覆盖各类常见语法并进行组合输出。

## 1. 标题层级

# 一级标题
## 二级标题
### 三级标题
#### 四级标题

## 2. 文本样式

这是一段普通文本,包含 **加粗**、*斜体*、***加粗斜体***、~~删除线~~ 以及 `行内代码`。

还可以组合:**加粗中包含 `代码`** 和 *斜体中包含 [链接](https://example.com)*。

## 3. 列表

### 无序列表
- 第一项
- 第二项
  - 嵌套子项 A
  - 嵌套子项 B
    - 更深一层
- 第三项

### 有序列表
1. 步骤一
2. 步骤二
   1. 子步骤 2.1
   2. 子步骤 2.2
3. 步骤三

### 任务列表
- [x] 已完成的任务
- [ ] 待办的任务
- [ ] 另一个待办

## 4. 引用

> 这是一段引用文本。
>
> > 这是嵌套引用,用于测试多层级。

## 5. 代码块

行内代码:`flutter pub get`

Dart 代码块:

```dart
void main() {
  final greeting = 'Hello, Markdown!';
  for (var i = 0; i < 3; i++) {
    print('$greeting ($i)');
  }
}
```

JSON 代码块:

```json
{
  "name": "PocketMind",
  "version": "1.0.0",
  "features": ["stream", "markdown", "a2ui"]
}
```

## 6. 表格

| 功能 | 状态 | 优先级 |
|------|------|--------|
| 流式输出 | ✅ 完成 | 高 |
| 速度调节 | 🔄 进行中 | 中 |
| 语法覆盖 | ⏳ 待开始 | 低 |

## 7. 链接与分隔线

访问 [PocketMind 文档](https://example.com/docs) 了解更多。

---

## 8. 组合场景

> **提示**:下面是一段综合示例,模拟真实的 AI 回复。

实现流式渲染通常包含以下要点:

1. **数据源**:从 SSE 或本地 mock 逐块读取文本
2. **缓冲累积**:将增量片段写入 `StringBuffer`
3. **触发重建**:通过 `setState` 更新 `text`

```dart
final step = _nextStep(fullText, cursor);
buffer.write(fullText.substring(cursor, cursor + step));
setState(() => streamingText = buffer.toString());
```

| 阶段 | 说明 |
|------|------|
| 读取 | 按字符或标记切分 |
| 渲染 | 交给 `gpt_markdown` 处理 |

完成 ✅
