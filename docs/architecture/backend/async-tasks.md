# JDK 21 虚拟线程使用规范

## 概述

PocketMind 后端使用 **JDK 21 虚拟线程 (Virtual Threads)** 处理异步任务。虚拟线程是轻量级线程,适合 IO 密集型操作。

## 基础使用

### Fire-and-Forget 模式

适用于不需要等待结果的后台任务。

```java
Thread.ofVirtual()
    .name("task-name")
    .start(() -> {
        // 异步任务逻辑
        log.info("任务执行中...");
    });
```

**示例**:
```java
private void triggerBackgroundTask(long userId, UUID taskId) {
    Thread.ofVirtual()
        .name("background-task-" + taskId)
        .start(() -> {
            try {
                performTask(userId, taskId);
                log.info("任务完成: taskId={}", taskId);
            } catch (Exception e) {
                log.error("任务失败: taskId={}", taskId, e);
            }
        });
}
```

### 等待结果模式

使用 `CompletableFuture` 配合虚拟线程获取异步结果。

```java
CompletableFuture<String> future = CompletableFuture.supplyAsync(
    () -> {
        // 任务逻辑
        return "result";
    },
    Executors.newVirtualThreadPerTaskExecutor()
);

// 等待结果
String result = future.join();

// 或设置超时
String result = future.get(5, TimeUnit.SECONDS);
```

## 在 RabbitMQ 中使用虚拟线程

### 配置虚拟线程执行器

```java
@Bean
public SimpleRabbitListenerContainerFactory myContainerFactory(ConnectionFactory connectionFactory) {
    // 创建虚拟线程执行器
    SimpleAsyncTaskExecutor virtualExecutor = new SimpleAsyncTaskExecutor("my-worker-");
    virtualExecutor.setVirtualThreads(true);  // 启用虚拟线程
    
    SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
    factory.setConnectionFactory(connectionFactory);
    factory.setTaskExecutor(virtualExecutor);  // 注入虚拟线程执行器
    
    return factory;
}
```

### 使用虚拟线程消费消息

```java
@RabbitListener(
    queues = "my-queue",
    containerFactory = "myContainerFactory"  // 指定使用虚拟线程的工厂
)
public void handleMessage(MyMessage message) {
    // 消息处理逻辑
    // 每个消息在独立的虚拟线程中执行
}
```

## 最佳实践

### 1. 适用场景

**✅ 适合使用虚拟线程**:
- IO 密集型操作 (数据库查询、HTTP 请求、文件读写)
- 需要高并发的场景 (如消息队列消费)
- Fire-and-forget 后台任务

**❌ 不适合使用虚拟线程**:
- CPU 密集型计算
- 使用 `synchronized` 的代码块

### 2. 避免使用 synchronized

虚拟线程在 `synchronized` 块中会占用平台线程,失去轻量级优势。

```java
// ❌ 错误 - 使用 synchronized
Thread.ofVirtual().start(() -> {
    synchronized (lock) {  // 会阻塞平台线程!
        // ...
    }
});

// ✅ 正确 - 使用 ReentrantLock
Thread.ofVirtual().start(() -> {
    lock.lock();
    try {
        // ...
    } finally {
        lock.unlock();
    }
});
```

### 3. 异常处理

虚拟线程中的异常不会传播,需要在线程内部捕获处理。

```java
Thread.ofVirtual().start(() -> {
    try {
        performTask();
    } catch (Exception e) {
        log.error("任务执行失败", e);
        // 根据需要决定是否重试或补偿
    }
});
```

### 4. 线程命名

为虚拟线程指定有意义的名称,便于调试和监控。

```java
Thread.ofVirtual()
    .name("order-process-" + orderId)  // 包含业务标识
    .start(() -> processOrder(orderId));
```

## 注意事项

1. **虚拟线程数量**: 可以创建数百万个虚拟线程,无需担心资源耗尽
2. **线程池**: 虚拟线程无需使用传统线程池,每个任务创建一个虚拟线程即可
3. **ThreadLocal**: 每个虚拟线程有独立的 ThreadLocal,注意清理避免内存泄漏
4. **阻塞 API**: 虚拟线程会自动将阻塞 IO 操作转换为非阻塞,无需手动优化

## 相关文档

- [后端分层架构](./layered-architecture.md)
- [后端编码规约](../../conventions/backend-coding-standards.md)
