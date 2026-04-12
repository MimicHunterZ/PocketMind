# 后端分层架构规范

## 概述

PocketMind 后端采用严格的分层架构,基于 Spring Boot 4.x 构建。本文档定义了各层的职责边界、依赖关系和最佳实践。

**包路径**: `com.doublez.pocketmindserver`

## 架构分层

```
┌─────────────────┐
│   Controller    │  协议适配层 - HTTP 请求处理
├─────────────────┤
│    Service      │  业务逻辑层 - 核心业务实现
├─────────────────┤
│   Repository    │  持久化抽象层 - 存储中立
├─────────────────┤
│     Mapper      │  数据访问层 - MyBatis-Plus
└─────────────────┘
```

## Controller 层 - API 调度规范

### 职责定位
Controller 是极薄的"协议适配层",严禁涉及任何业务逻辑。

### 依赖约束

#### ✅ 允许
- 注入 `Service` 接口

#### ❌ 强禁令
- 禁止注入 `Mapper`
- 禁止注入 `Repository`
- 禁止编写业务逻辑

### 核心职责

1. **参数校验**
   - 使用 JSR-303/JSR-380 注解进行入参合法性检查
   - 常用注解: `@Validated`, `@NotBlank`, `@NotNull`, `@Min`, `@Max`

2. **流量分发**
   - 仅负责调用 Service 执行业务
   - 处理 HTTP 响应包装

### 设计原则

- **简洁性**: 单个 API 方法代码原则上不应超过 30 行
- **单一职责**: 一个方法只处理一个 HTTP 端点
- **无状态**: 禁止在 Controller 中保存状态

### 示例代码

```java
@RestController
@RequestMapping("/api/notes")
@Validated
public class NoteController {
    
    private final NoteService noteService;
    
    @PostMapping
    public R<NoteVO> create(@Validated @RequestBody NoteCreateDTO dto) {
        return R.ok(noteService.createNote(dto));
    }
    
    @GetMapping("/{id}")
    public R<NoteVO> get(@PathVariable Long id) {
        return R.ok(noteService.getNoteById(id));
    }
}
```

## Service 层 - 核心业务规范

### 接口规范

**必须采用 `Interface + Impl` 模式**

- ✅ 便于 AOP 代理
- ✅ 便于 Mock 测试
- ✅ 便于未来扩展

### 事务管理

#### 事务标注规则
```java
@Transactional(rollbackFor = Exception.class)
public void complexBusinessLogic() {
    // 多表操作
    // 跨服务调用
}
```

#### 事务边界控制

**必须标注事务的场景**:
- 多表操作
- 跨服务调用
- 需要保证原子性的业务

**禁止开启大事务的场景**:
- AI 调用 (使用虚拟线程异步处理)
- 文件上传 (先上传后入库)
- 长耗时操作 (拆分为多个小事务)

### 数据流转规范

```
DTO (from Controller)
  ↓
Service (业务处理)
  ↓
Repository.findById() → Entity
  ↓
业务逻辑处理
  ↓
Entity → VO/DTO (to Controller)
```

### 解耦要求

**严禁直接调用 `BaseMapper`**

```java
// ❌ 错误示例
@Service
public class NoteServiceImpl implements NoteService {
    @Autowired
    private NoteMapper noteMapper; // 禁止!
}

// ✅ 正确示例
@Service
public class NoteServiceImpl implements NoteService {
    @Autowired
    private NoteRepository noteRepository; // 正确
}
```

### 示例代码

```java
public interface NoteService {
    NoteVO createNote(NoteCreateDTO dto);
    NoteVO getNoteById(Long id);
}

@Service
public class NoteServiceImpl implements NoteService {
    
    private final NoteRepository noteRepository;
    
    @Override
    @Transactional(rollbackFor = Exception.class)
    public NoteVO createNote(NoteCreateDTO dto) {
        // 1. 构建实体
        Note note = Note.builder()
            .title(dto.getTitle())
            .content(dto.getContent())
            .build();
        
        // 2. 持久化
        noteRepository.save(note);
        
        // 3. 转换为 VO
        return NoteVO.from(note);
    }
    
    @Override
    public NoteVO getNoteById(Long id) {
        Note note = noteRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("笔记不存在"));
        return NoteVO.from(note);
    }
}
```

## Repository 层 - 持久化抽象

### 设计理念

引入 Repository 层实现"存储中立",屏蔽 MyBatis-Plus 实现细节。

### 核心职责

1. **抽象数据访问**
   - Service 只需关心 `findById`、`save`、`delete` 等语义化方法
   - 不关心底层是 LambdaQuery 还是 XML

2. **封装查询逻辑**
   - 将复杂的 `QueryWrapper` 封装在 Repository 内部
   - 提供领域语言风格的查询方法

3. **缓冲带**
   - 作为 Service 与 Mapper 之间的缓冲层
   - 便于未来切换持久化框架

### 示例代码

```java
public interface NoteRepository {
    Optional<Note> findById(Long id);
    List<Note> findByUserId(Long userId);
    void save(Note note);
    void deleteById(Long id);
}

@Repository
public class NoteRepositoryImpl implements NoteRepository {
    
    private final NoteMapper noteMapper;
    
    @Override
    public Optional<Note> findById(Long id) {
        return Optional.ofNullable(noteMapper.selectById(id));
    }
    
    @Override
    public List<Note> findByUserId(Long userId) {
        LambdaQueryWrapper<Note> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Note::getUserId, userId)
               .select(Note::getId, Note::getTitle, Note::getCreateTime);
        return noteMapper.selectList(wrapper);
    }
    
    @Override
    public void save(Note note) {
        if (note.getId() == null) {
            noteMapper.insert(note);
        } else {
            noteMapper.updateById(note);
        }
    }
    
    @Override
    public void deleteById(Long id) {
        noteMapper.deleteById(id);
    }
}
```

## Mapper 层 - 数据访问

### 实体映射规范

#### 必须使用的注解

```java
@Data
@Accessors(chain = true)
@TableName("notes")
public class Note {
    @TableId(type = IdType.AUTO)
    private Long id;
    
    private String title;
    
    private String content;
    
    @TableField("user_id")
    private Long userId;
    
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
    
    @TableLogic
    private Integer deleted;
}
```

#### 关键注解说明

- `@TableName`: **必须指定**,避免类名修改导致的 SQL 错误
- `@TableId`: 主键策略
- `@TableField`: 字段映射、自动填充
- `@TableLogic`: 逻辑删除标记

### SQL 优化强制规范

#### ❌ 严禁 `SELECT *`

```java
// ❌ 错误 - 会查询所有字段
List<Note> notes = noteMapper.selectList(null);

// ✅ 正确 - 明确指定字段
LambdaQueryWrapper<Note> wrapper = new LambdaQueryWrapper<>();
wrapper.select(Note::getId, Note::getTitle, Note::getCreateTime);
List<Note> notes = noteMapper.selectList(wrapper);
```

#### 索引覆盖优化

- 使用数据库分析工具 (EXPLAIN) 确认索引命中
- 查询字段尽量在索引覆盖范围内
- 避免在 `WHERE` 子句中使用函数

### MyBatis-Plus 配置

**版本要求**: 与 Spring Boot 4.x 对齐

获取最新配置文档:
```bash
# 使用 Context7 MCP 获取 MyBatis-Plus 最新文档
```

## 技术栈集成

### Spring Boot 4.x 特性

#### 虚拟线程 (Project Loom)

优先使用虚拟线程优化 IO 密集型操作:

```java
@Configuration
public class AsyncConfig {
    
    @Bean
    public Executor taskExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }
}
```

#### 自动填充 (MetaObjectHandler)

**强制实现**:

```java
@Component
public class MyMetaObjectHandler implements MetaObjectHandler {
    
    @Override
    public void insertFill(MetaObject metaObject) {
        this.strictInsertFill(metaObject, "createTime", LocalDateTime.class, LocalDateTime.now());
        this.strictInsertFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());
    }
    
    @Override
    public void updateFill(MetaObject metaObject) {
        this.strictUpdateFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());
    }
}
```

#### 逻辑删除配置

**核心业务表必须使用逻辑删除**:

```yaml
mybatis-plus:
  global-config:
    db-config:
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
```

## 相关文档

- [AI 模块规范](./ai-integration.md)
- [异步任务处理](./async-tasks.md)
- [数据库设计规范](./database-design.md)
