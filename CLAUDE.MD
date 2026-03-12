# PocketMind Copilot Instructions

你是 PocketMind 项目的专家级 AI 架构师。PocketMind 是一个“第二大脑”生态系统，包含 Flutter 移动端 和 Spring Boot 后端。

## 🏗️ 项目架构与职责定义

### 1. 后端 (Spring Boot) - 严格分层规范

* **包路径**: `com.doublez.pocketmindserver`
#### Controller 层 (API 调度规范)
Controller 应作为极薄的“协议适配层”，严禁涉及任何业务逻辑。

* **依赖约束**:
    * **强禁令**: 禁止注入 `Mapper` 或 `Repository`。
    * **准入**: 仅允许注入 `Service` 接口。
* **核心职责**:
    1.  **参数校验**: 使用 JSR-303/JSR-380 注解（如 `@Validated`, `@NotBlank`）进行入参合法性检查。
    2.  **流量分发**: 仅负责调用 Service 执行业务。
* **设计原则**: 保持方法纯粹，单个 API 逻辑代码原则上不应超过 30 行。

#### Service 层 (核心业务规范)
* **接口规范**: 必须采用 `Interface + Impl` 模式，便于 AOP 代理及 Mock 测试。
* **事务管理**: 
    * 多表操作、跨服务调用必须标注 `@Transactional(rollbackFor = Exception.class)`。
    * 禁止在长耗时（如 AI 调用、文件上传）方法上开启大事务，应采用声明式事务细化边界。
* **数据流转**: 
    * 接收 `DTO`，向 Repository 请求 `Entity`。
    * 业务逻辑处理完成后，将 `Entity` 转换为 `VO/DTO` 返回给 Controller。
* **解耦要求**: 禁止直接调用 `BaseMapper` 的方法，必须通过 `Repository` 获取数据。

#### Persistence 层 (持久化与 Repository 模式)
为了实现“存储中立”并优化 MyBatis-Plus 的使用，引入 Repository 抽象。
* mybatis-plus 需要和 springboot4.0 对齐，文档使用  `Context7 MCP` 获取
* **Repository 职责**:
    * 作为 Service 与 Mapper 之间的缓冲带。
    * 屏蔽 MyBatis-Plus 的 `QueryWrapper` 等原生 API 侵入 Service 层。
    * Service 仅调用如 `userRepository.findById(id)`，而不关心底层是 LambdaQuery 还是 XML。
* **实体映射**:
    * `Entity` 类必须开启 `Lombok` 注解（`@Data`, `@Accessors(chain = true)`）。
    * 必须使用 `@TableName` 指定表名，避免由于类名修改导致的 SQL 错误。
* **SQL 优化禁令**:
    * **严禁 `SELECT *`**: 必须在 Mapper 或 Wrapper 中通过 `.select("id", "name", ...)` 或 `LambdaQueryWrapper.select()` 明确字段。
    * **索引覆盖**: 数据库分析工具确认索引命中情况。

#### 技术栈交互细节 (Spring Boot 4.x & MP)
* **响应式支持**: 结合 Spring Boot 4.x，优先考虑使用 `Project Loom` (虚拟线程) 优化 IO 密集型操作。
* **自动填充**: 强制实现 `MetaObjectHandler`，自动处理 `create_time` 和 `update_time`。
* **物理删除隔离**: 核心业务表必须使用 `logic-delete`（逻辑删除），配置 `mybatis-plus.global-config.db-config.logic-delete-field`。

#### **AI 模块**:
* 基于 **Spring AI**。
1. 提示词工程
  语法强制：所有动态变量必须使用 <variable_name> 格式。严禁使用 {{ }} 或 { }。
  外部化管理：禁止在 Java 类中硬编码 String。
  路径：src/main/resources/prompts/{biz_domain}/{scene_name}.st
  注入方式：使用 org.springframework.core.io.Resource 配合 @Value 注入，不能硬编码。
2. 流式传输协议 (SSE Standard)
响应式流处理需严格遵守 W3C SSE 规范，确保前端解析不掉帧、不报错：
返回类型：必须声明为 Flux<ServerSentEvent<String>>。
事件生命周期：
  [Data]: 业务增量内容，通过 .data(chunk) 发送。
  [Control]: 必须处理结束标识，发送 [DONE] 信号或特定事件类型，避免前端长连接挂死。
  [Error]: 发生异常时，包装为 event: error 类型的 SSE 消息，而非直接抛出 HTTP 500。
  字符编码：强制 Content-Type: text/event-stream; charset=UTF-8。
3. ai调用使用项目封装的 aifailoverRouter 进行调用。
4. prompt 构建使用 PromptBuilder 工具类进行构建，禁止直接字符串拼接。

#### 异步任务与调度
1. 使用 JDK21 的虚拟线程处理高并发 AI 调用，避免传统线程池资源耗尽。


### 2. 移动端 (Flutter)
#### 视觉语言与 UI 审美 (The Soul)
追求“杂志感”不仅仅是排版，更是对留白与光影的精确控制。
所有相关ui设计字段必须在 theme_data.dart 中定义，禁止在组件中硬编码颜色、字体大小等设计元素。
使用系统组件前请先查看项目里是否已有封装（mobile\lib\page\widget），禁止直接使用原生组件（如 TextField、Container）进行复杂 UI 构建。

#### 数据架构与序列化 (Data & State)
拒绝样板代码，强制使用自动化工具链确保不可变性。

| 场景 | 推荐方案 | 核心理由 |
| :--- | :--- | :--- |
| **状态/模型** | `@freezed` | 提供完美的 `copyWith`、`union types` 及值相等性判断。 |
| **简单 DTO** | `@JsonSerializable` | 轻量级序列化，适用于不需要不可变特性的临时对象。 |
| **时间处理** | `TimestampConverter` | 强制统一。禁止在 UI 层处理 `DateTime` 逻辑，后端下发与本地存储均使用 **毫秒时间戳**。 |

任何涉及 @freezed、@JsonSerializable 或 Riverpod 刷新的操作，必须触发构建：
`flutter pub run build_runner watch --delete-conflicting-outputs`
* **禁止项**: 严禁手动编写 `fromJson` / `toJson`。任何手动修改产生的 Mapping 错误在 Code Review 中将被视为一级 Bug。

#### 网络层抽象
依赖注入: 必须通过 Riverpod Provider 注入 API Service。

拦截器隔离: 认证令牌（Auth Token）、日志记录、多语言 Header 必须在 Dio 拦截器中统一实现。

路径: 所有接口定义存放于 lib/api/，禁止在 UI 逻辑中出现 dio.get('/url')。
* **状态管理 (使用 Riverpod3.0 不清楚具体改动查看 context7 mcp)**:

* **数据库 (Isar)**:
* 遵循“持久化驱动展示”原则：UI 订阅 Isar 的 `Watch` 流，业务操作直接修改数据库，UI 自动响应变化。
* 所有写操作必须封装在 `isar.writeTxn` 中。


## 🚨 核心开发规约

### 1. 编码风格

* **注释**: 所有的代码注释、文档注释必须使用 **中文**，并且注释中不能出现 'phase xxx','适合 DAY1'等ai撰写的适合会出现的注释内容

## 🛠️ Developer Workflows

### Mobile
- **Run**: `cd mobile && flutter run`
- **Code Generation**: `cd mobile && flutter pub run build_runner watch --delete-conflicting-outputs` (Run once this after changing Isar models or Mockito mocks).
- **Tests**: `flutter test` (Unit), `flutter test integration_test` (Integration).

### Backend
- **Run**: `cd backend && ./mvnw spring-boot:run`
- **Tests**: `./mvnw test` 确保代码可以编译以及可以启动

## 🧪 Testing Strategy
- **Unit Tests**: Mock Repositories to test Services.
- **Widget Tests**: Test UI components.
- **Integration Tests**: Test full flows.
