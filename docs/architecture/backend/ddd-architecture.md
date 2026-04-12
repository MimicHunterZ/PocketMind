# 后端 DDD 架构规范

## 概述

PocketMind 后端采用**务实的 DDD 风格分层架构 (Pragmatic DDD-Inspired Layered Architecture)**,吸收了 DDD 的核心思想(分层、Repository 模式、值对象、实体封装业务逻辑),但未完全实现所有 DDD 战术模式。

**当前架构状态**: 60% DDD 实现度
- ✅ 已实现: 分层架构、Repository 模式、值对象、Entity-Model 分离
- ⚠️ 部分实现: 实体封装业务逻辑、Outbox 模式
- ❌ 待实现: 聚合根显式标识、领域服务、标准领域事件

> **重要**: 本文档描述的是**目标架构**。实际代码正在渐进式演进中,详见 [docs/todo.json](../../todo.json) 记录的待改进项。

## DDD 分层架构

```
┌─────────────────────────────────────┐
│   用户接口层 (User Interface)        │  Controller, DTO, VO
├─────────────────────────────────────┤
│   应用层 (Application)               │  应用服务, 编排领域服务
├─────────────────────────────────────┤
│   领域层 (Domain)                    │  聚合根, 实体, 值对象, 领域服务
├─────────────────────────────────────┤
│   基础设施层 (Infrastructure)        │  Repository 实现, Mapper, 外部服务
└─────────────────────────────────────┘
```

## 包结构设计

```
com.doublez.pocketmindserver
├── api                           # 用户接口层
│   └── controller                # REST Controller
│       ├── NoteController
│       └── UserController
│
├── application                   # 应用层
│   ├── service                   # 应用服务
│   │   ├── NoteApplicationService
│   │   └── UserApplicationService
│   ├── dto                       # 数据传输对象
│   │   ├── request
│   │   │   ├── NoteCreateDTO
│   │   │   └── NoteUpdateDTO
│   │   └── response
│   │       └── NoteVO
│   └── assembler                 # DTO-领域对象转换器
│       └── NoteDTOAssembler
│
├── domain                        # 领域层
│   ├── note                      # Note 限界上下文
│   │   ├── model                 # 领域模型
│   │   │   ├── Note              # 聚合根
│   │   │   ├── NoteContent       # 值对象
│   │   │   └── NoteStatus        # 枚举/值对象
│   │   ├── service               # 领域服务
│   │   │   └── NoteSharingService
│   │   ├── repository            # Repository 接口
│   │   │   └── NoteRepository
│   │   └── event                 # 领域事件
│   │       ├── NoteCreatedEvent
│   │       └── NoteSharedEvent
│   │
│   ├── user                      # User 限界上下文
│   │   ├── model
│   │   │   ├── User              # 聚合根
│   │   │   ├── Email             # 值对象
│   │   │   └── Password          # 值对象
│   │   ├── repository
│   │   │   └── UserRepository
│   │   └── service
│   │       └── UserAuthenticationService
│   │
│   └── shared                    # 共享内核
│       ├── valueobject           # 共享值对象
│       │   ├── Money
│       │   └── CreateTime
│       └── exception             # 领域异常
│           └── DomainException
│
└── infrastructure                # 基础设施层
    ├── persistence               # 持久化
    │   ├── mapper                # MyBatis Mapper
    │   │   ├── NoteMapper
    │   │   └── UserMapper
    │   ├── po                    # 持久化对象 (与数据库表对应)
    │   │   ├── NotePO
    │   │   └── UserPO
    │   └── repository            # Repository 实现
    │       ├── NoteRepositoryImpl
    │       └── UserRepositoryImpl
    │
    ├── ai                        # AI 集成
    │   ├── AIFailoverRouter
    │   └── PromptBuilder
    │
    └── messaging                 # 消息中间件
        └── DomainEventPublisher
```

## 战术设计模式

### 1. 聚合根 (Aggregate Root)

聚合根是领域模型的核心,负责维护业务不变性规则。

```java
package com.doublez.pocketmindserver.domain.note.model;

/**
 * 笔记聚合根
 * 
 * 负责维护笔记的完整性和业务规则
 */
@Getter
public class Note {
    
    private final NoteId id;
    private NoteTitle title;
    private NoteContent content;
    private NoteStatus status;
    private final UserId authorId;
    private final CreateTime createTime;
    private UpdateTime updateTime;
    
    // 聚合根禁止使用 public 构造函数,通过工厂方法创建
    private Note(NoteId id, NoteTitle title, NoteContent content, UserId authorId) {
        this.id = id;
        this.title = title;
        this.content = content;
        this.status = NoteStatus.DRAFT;
        this.authorId = authorId;
        this.createTime = CreateTime.now();
        this.updateTime = UpdateTime.now();
    }
    
    /**
     * 工厂方法: 创建新笔记
     */
    public static Note create(NoteTitle title, NoteContent content, UserId authorId) {
        // 业务规则校验
        Objects.requireNonNull(title, "标题不能为空");
        Objects.requireNonNull(content, "内容不能为空");
        Objects.requireNonNull(authorId, "作者不能为空");
        
        return new Note(NoteId.generate(), title, content, authorId);
    }
    
    /**
     * 业务方法: 更新标题
     */
    public void updateTitle(NoteTitle newTitle) {
        Objects.requireNonNull(newTitle, "标题不能为空");
        this.title = newTitle;
        this.updateTime = UpdateTime.now();
    }
    
    /**
     * 业务方法: 发布笔记
     */
    public void publish() {
        if (this.status == NoteStatus.PUBLISHED) {
            throw new DomainException("笔记已发布,无法重复发布");
        }
        this.status = NoteStatus.PUBLISHED;
        this.updateTime = UpdateTime.now();
        
        // 发布领域事件
        DomainEventPublisher.publish(new NotePublishedEvent(this.id));
    }
    
    /**
     * 业务规则: 判断是否为作者
     */
    public boolean isAuthor(UserId userId) {
        return this.authorId.equals(userId);
    }
}
```

### 2. 值对象 (Value Object)

值对象是不可变的,通过值相等性判断。

```java
package com.doublez.pocketmindserver.domain.note.model;

/**
 * 笔记标题值对象
 */
@Value
public class NoteTitle {
    
    private static final int MAX_LENGTH = 100;
    
    String value;
    
    private NoteTitle(String value) {
        this.value = value;
    }
    
    public static NoteTitle of(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("标题不能为空");
        }
        if (value.length() > MAX_LENGTH) {
            throw new IllegalArgumentException("标题长度不能超过 " + MAX_LENGTH + " 字符");
        }
        return new NoteTitle(value.trim());
    }
}
```

```java
package com.doublez.pocketmindserver.domain.shared.valueobject;

/**
 * 邮箱值对象
 */
@Value
public class Email {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
    
    String value;
    
    private Email(String value) {
        this.value = value;
    }
    
    public static Email of(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("邮箱不能为空");
        }
        if (!EMAIL_PATTERN.matcher(value).matches()) {
            throw new IllegalArgumentException("邮箱格式不正确");
        }
        return new Email(value.toLowerCase());
    }
}
```

### 3. 领域服务 (Domain Service)

当业务逻辑不适合放在单个聚合根中时,使用领域服务。

```java
package com.doublez.pocketmindserver.domain.note.service;

/**
 * 笔记分享领域服务
 * 
 * 处理跨聚合的业务逻辑
 */
@DomainService
public class NoteSharingService {
    
    private final NoteRepository noteRepository;
    private final UserRepository userRepository;
    
    /**
     * 分享笔记给用户
     */
    public void shareNote(NoteId noteId, UserId fromUserId, UserId toUserId) {
        // 1. 查询笔记
        Note note = noteRepository.findById(noteId)
            .orElseThrow(() -> new NotFoundException("笔记不存在"));
        
        // 2. 验证权限
        if (!note.isAuthor(fromUserId)) {
            throw new ForbiddenException("无权分享此笔记");
        }
        
        // 3. 验证目标用户
        User targetUser = userRepository.findById(toUserId)
            .orElseThrow(() -> new NotFoundException("目标用户不存在"));
        
        // 4. 执行分享逻辑
        note.shareTo(targetUser.getId());
        
        // 5. 持久化
        noteRepository.save(note);
        
        // 6. 发布领域事件
        DomainEventPublisher.publish(new NoteSharedEvent(noteId, fromUserId, toUserId));
    }
}
```

### 4. Repository 接口

Repository 定义在领域层,实现在基础设施层。

```java
package com.doublez.pocketmindserver.domain.note.repository;

/**
 * 笔记仓储接口
 * 
 * 提供领域对象的持久化抽象
 */
public interface NoteRepository {
    
    /**
     * 保存笔记
     */
    void save(Note note);
    
    /**
     * 根据 ID 查询笔记
     */
    Optional<Note> findById(NoteId id);
    
    /**
     * 查询用户的笔记列表
     */
    List<Note> findByAuthorId(UserId authorId);
    
    /**
     * 删除笔记
     */
    void delete(NoteId id);
    
    /**
     * 判断笔记是否存在
     */
    boolean exists(NoteId id);
}
```

### 5. Repository 实现

```java
package com.doublez.pocketmindserver.infrastructure.persistence.repository;

/**
 * 笔记仓储实现
 * 
 * 负责领域对象与持久化对象的转换
 */
@Repository
public class NoteRepositoryImpl implements NoteRepository {
    
    private final NoteMapper noteMapper;
    
    @Override
    public void save(Note note) {
        NotePO po = toNotePO(note);
        
        if (noteMapper.selectById(po.getId()) == null) {
            noteMapper.insert(po);
        } else {
            noteMapper.updateById(po);
        }
    }
    
    @Override
    public Optional<Note> findById(NoteId id) {
        NotePO po = noteMapper.selectById(id.getValue());
        return Optional.ofNullable(po).map(this::toNote);
    }
    
    @Override
    public List<Note> findByAuthorId(UserId authorId) {
        LambdaQueryWrapper<NotePO> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NotePO::getAuthorId, authorId.getValue())
               .select(NotePO::getId, NotePO::getTitle, NotePO::getCreateTime);
        
        return noteMapper.selectList(wrapper).stream()
            .map(this::toNote)
            .toList();
    }
    
    // 领域对象 → 持久化对象
    private NotePO toNotePO(Note note) {
        return NotePO.builder()
            .id(note.getId().getValue())
            .title(note.getTitle().getValue())
            .content(note.getContent().getValue())
            .status(note.getStatus().name())
            .authorId(note.getAuthorId().getValue())
            .build();
    }
    
    // 持久化对象 → 领域对象
    private Note toNote(NotePO po) {
        return Note.reconstitute(
            NoteId.of(po.getId()),
            NoteTitle.of(po.getTitle()),
            NoteContent.of(po.getContent()),
            NoteStatus.valueOf(po.getStatus()),
            UserId.of(po.getAuthorId()),
            CreateTime.of(po.getCreateTime()),
            UpdateTime.of(po.getUpdateTime())
        );
    }
}
```

### 6. 应用服务

应用服务负责编排领域服务和仓储,处理事务边界。

```java
package com.doublez.pocketmindserver.application.service;

/**
 * 笔记应用服务
 * 
 * 编排领域对象和领域服务,处理事务
 */
@Service
@RequiredArgsConstructor
public class NoteApplicationService {
    
    private final NoteRepository noteRepository;
    private final NoteSharingService noteSharingService;
    private final NoteDTOAssembler noteDTOAssembler;
    
    /**
     * 创建笔记
     */
    @Transactional(rollbackFor = Exception.class)
    public NoteVO createNote(NoteCreateDTO dto, Long currentUserId) {
        // 1. DTO → 领域对象
        Note note = Note.create(
            NoteTitle.of(dto.getTitle()),
            NoteContent.of(dto.getContent()),
            UserId.of(currentUserId)
        );
        
        // 2. 持久化
        noteRepository.save(note);
        
        // 3. 领域对象 → VO
        return noteDTOAssembler.toVO(note);
    }
    
    /**
     * 分享笔记
     */
    @Transactional(rollbackFor = Exception.class)
    public void shareNote(Long noteId, Long toUserId, Long currentUserId) {
        noteSharingService.shareNote(
            NoteId.of(noteId),
            UserId.of(currentUserId),
            UserId.of(toUserId)
        );
    }
}
```

### 7. 领域事件

```java
package com.doublez.pocketmindserver.domain.note.event;

/**
 * 笔记已发布事件
 */
@Value
public class NotePublishedEvent implements DomainEvent {
    NoteId noteId;
    Instant occurredOn = Instant.now();
}
```

## DDD 最佳实践

### 1. 聚合边界

- ✅ 一个事务只修改一个聚合
- ✅ 聚合间通过 ID 引用,不直接持有对象引用
- ✅ 小聚合优于大聚合

### 2. 值对象使用

- ✅ 优先使用值对象而非基本类型
- ✅ 值对象封装业务规则和验证逻辑
- ✅ 值对象不可变

### 3. Repository 职责

- ✅ Repository 只处理聚合根
- ✅ Repository 接口定义在领域层
- ✅ Repository 实现在基础设施层

### 4. 领域服务 vs 应用服务

| 类型 | 职责 | 事务 |
| :--- | :--- | :--- |
| 领域服务 | 跨聚合业务逻辑 | 无事务 |
| 应用服务 | 编排领域对象,处理 DTO 转换 | 有事务 |

### 5. 领域事件

- ✅ 使用领域事件解耦聚合间的依赖
- ✅ 事件命名使用过去式 (如 NoteCreatedEvent)
- ✅ 事件包含最小必要信息

## 与分层架构的对应关系

| DDD 层次 | 传统分层 | 说明 |
| :--- | :--- | :--- |
| 用户接口层 | Controller | HTTP 适配器 |
| 应用层 | Application Service | 编排和事务 |
| 领域层 | Domain Model | 业务逻辑 |
| 基础设施层 | Repository Impl, Mapper | 技术实现 |

## 相关文档

- [后端分层架构](./layered-architecture.md)
- [后端编码规约](../../conventions/backend-coding-standards.md)
- [AI 集成规范](./ai-integration.md)
