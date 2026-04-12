# AI 模块集成规范

## 概述

PocketMind 后端基于 **Spring AI** 构建 AI 能力,涵盖提示词工程、流式传输、故障转移等核心特性。

## 技术栈

- **框架**: Spring AI
- **传输协议**: Server-Sent Events (SSE)
- **并发模型**: JDK 21 虚拟线程

## 提示词工程 (Prompt Engineering)

### 语法强制规范

**所有动态变量必须使用 `<variable_name>` 格式**

```
// ✅ 正确
请根据用户输入 <user_input> 生成摘要

// ❌ 错误 - 禁止使用
请根据用户输入 {{ user_input }} 生成摘要
请根据用户输入 { user_input } 生成摘要
```

### 外部化管理

**禁止在 Java 类中硬编码 Prompt 字符串**

#### 文件路径规范
```
src/main/resources/prompts/
├── note/
│   ├── summarize.st
│   └── generate_title.st
├── chat/
│   ├── context_enhance.st
│   └── stream_reply.st
└── common/
    └── system_message.st
```

路径模式: `prompts/{biz_domain}/{scene_name}.st`

#### 注入方式

```java
@Service
public class NoteSummaryService {
    
    // ✅ 正确 - 使用 @Value 注入
    @Value("classpath:prompts/note/summarize.st")
    private Resource promptTemplate;
    
    public String summarize(String content) {
        String template = loadTemplate(promptTemplate);
        return PromptBuilder.build(template)
            .variable("content", content)
            .execute();
    }
    
    private String loadTemplate(Resource resource) {
        try {
            return new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new RuntimeException("Failed to load prompt template", e);
        }
    }
}
```

### Prompt 示例

**summarize.st**:
```
你是一个专业的内容总结助手。

用户的笔记内容如下:
<content>

请生成一个简洁的摘要,不超过 100 字。
```

## 流式传输协议 (SSE Standard)

### 规范要求

响应式流处理必须严格遵守 **W3C SSE 规范**,确保前端解析不掉帧、不报错。

### 返回类型

**必须声明为 `Flux<ServerSentEvent<String>>`**

```java
@GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<String>> streamResponse(@RequestParam String prompt) {
    return chatService.streamChat(prompt);
}
```

### 事件生命周期

#### 1. Data 事件 - 业务增量内容

```java
ServerSentEvent.<String>builder()
    .data(chunk)  // AI 返回的文本片段
    .build()
```

#### 2. Control 事件 - 结束标识

**必须发送结束信号**,避免前端长连接挂死:

```java
// 方式一: 发送 [DONE] 信号
ServerSentEvent.<String>builder()
    .event("done")
    .data("[DONE]")
    .build()

// 方式二: 使用特定事件类型
ServerSentEvent.<String>builder()
    .event("complete")
    .data("Stream completed")
    .build()
```

#### 3. Error 事件 - 异常处理

**发生异常时,包装为 `event: error` 类型的 SSE 消息,而非直接抛出 HTTP 500**

```java
public Flux<ServerSentEvent<String>> streamWithErrorHandling(String prompt) {
    return aiService.stream(prompt)
        .map(chunk -> ServerSentEvent.<String>builder()
            .data(chunk)
            .build())
        .concatWith(Mono.just(ServerSentEvent.<String>builder()
            .event("done")
            .data("[DONE]")
            .build()))
        .onErrorResume(ex -> Mono.just(
            ServerSentEvent.<String>builder()
                .event("error")
                .data("处理失败: " + ex.getMessage())
                .build()
        ));
}
```

### 字符编码

**强制声明 UTF-8 编码**:

```java
@GetMapping(value = "/stream", produces = "text/event-stream; charset=UTF-8")
```

### 完整示例

```java
@RestController
@RequestMapping("/api/ai")
public class AIController {
    
    private final ChatService chatService;
    
    @GetMapping(value = "/chat/stream", produces = "text/event-stream; charset=UTF-8")
    public Flux<ServerSentEvent<String>> streamChat(@RequestParam String message) {
        return chatService.streamChat(message)
            .map(chunk -> ServerSentEvent.<String>builder()
                .id(UUID.randomUUID().toString())
                .event("message")
                .data(chunk)
                .build())
            .concatWith(Mono.just(ServerSentEvent.<String>builder()
                .event("done")
                .data("[DONE]")
                .build()))
            .onErrorResume(ex -> {
                log.error("Stream chat error", ex);
                return Mono.just(ServerSentEvent.<String>builder()
                    .event("error")
                    .data("处理失败: " + ex.getMessage())
                    .build());
            });
    }
}
```

## AI 调用规范

### 使用 AIFailoverRouter

**项目封装的故障转移路由器,禁止直接调用 ChatClient**

```java
@Service
public class ChatService {
    
    private final AIFailoverRouter aiFailoverRouter;
    
    public Flux<String> streamChat(String message) {
        // ✅ 正确 - 使用封装的路由器
        return aiFailoverRouter.stream(message);
    }
    
    // ❌ 错误 - 禁止直接调用
    // private final ChatClient chatClient;
}
```

### Prompt 构建

**使用 `PromptBuilder` 工具类,禁止直接字符串拼接**

```java
// ✅ 正确
String prompt = PromptBuilder.build(templateContent)
    .variable("user_input", userInput)
    .variable("context", contextData)
    .build();

// ❌ 错误
String prompt = "请根据 " + userInput + " 生成内容...";
```

#### PromptBuilder 示例

```java
public class PromptBuilder {
    private String template;
    private Map<String, String> variables = new HashMap<>();
    
    public static PromptBuilder build(String template) {
        PromptBuilder builder = new PromptBuilder();
        builder.template = template;
        return builder;
    }
    
    public PromptBuilder variable(String key, String value) {
        variables.put(key, value);
        return this;
    }
    
    public String build() {
        String result = template;
        for (Map.Entry<String, String> entry : variables.entrySet()) {
            result = result.replace("<" + entry.getKey() + ">", entry.getValue());
        }
        return result;
    }
}
```

## 异步任务与并发

### 虚拟线程处理

**使用 JDK 21 虚拟线程处理高并发 AI 调用**

避免传统线程池资源耗尽:

```java
@Configuration
public class AIAsyncConfig {
    
    @Bean("aiTaskExecutor")
    public Executor aiTaskExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }
}

@Service
public class BatchAIService {
    
    @Async("aiTaskExecutor")
    public CompletableFuture<String> processAsync(String input) {
        return CompletableFuture.completedFuture(
            aiFailoverRouter.call(input)
        );
    }
    
    public List<String> processBatch(List<String> inputs) {
        List<CompletableFuture<String>> futures = inputs.stream()
            .map(this::processAsync)
            .toList();
        
        return futures.stream()
            .map(CompletableFuture::join)
            .toList();
    }
}
```

### 事务边界控制

**禁止在 AI 调用方法上开启大事务**:

```java
// ❌ 错误 - AI 调用不应在事务内
@Transactional
public String generateWithAI(String input) {
    noteRepository.save(note);
    return aiService.call(input); // 长耗时操作在事务内!
}

// ✅ 正确 - 拆分事务边界
public String generateWithAI(String input) {
    saveNoteInTransaction(note);
    return aiService.call(input); // 在事务外执行
}

@Transactional(rollbackFor = Exception.class)
private void saveNoteInTransaction(Note note) {
    noteRepository.save(note);
}
```

## 最佳实践

### 1. 超时控制

```java
public Mono<String> callWithTimeout(String prompt) {
    return aiFailoverRouter.call(prompt)
        .timeout(Duration.ofSeconds(30))
        .onErrorReturn("AI 调用超时,请稍后重试");
}
```

### 2. 重试策略

```java
public Mono<String> callWithRetry(String prompt) {
    return aiFailoverRouter.call(prompt)
        .retryWhen(Retry.backoff(3, Duration.ofSeconds(1))
            .filter(ex -> ex instanceof TimeoutException));
}
```

### 3. 日志记录

```java
public Flux<String> streamWithLogging(String prompt) {
    return aiFailoverRouter.stream(prompt)
        .doOnSubscribe(sub -> log.info("开始 AI 流式调用: {}", prompt))
        .doOnNext(chunk -> log.debug("接收到数据块: {}", chunk))
        .doOnComplete(() -> log.info("AI 流式调用完成"))
        .doOnError(ex -> log.error("AI 流式调用失败", ex));
}
```

## 相关文档

- [分层架构规范](./layered-architecture.md)
- [异步任务处理](./async-tasks.md)
- [Spring AI 官方文档](https://docs.spring.io/spring-ai/reference/)
