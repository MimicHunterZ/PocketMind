# 后端编码规约

## 概述

本文档定义 PocketMind 后端 (Java/Spring Boot) 的编码标准、命名规范和注释要求。

## 通用规约

### 注释语言

**所有代码注释、文档注释必须使用中文**

```java
// ✅ 正确
/**
 * 创建笔记
 * @param dto 笔记创建请求
 * @return 笔记视图对象
 */
public NoteVO createNote(NoteCreateDTO dto) {
    // 业务逻辑
}

// ❌ 错误
/**
 * Create a new note
 * @param dto note creation request
 * @return note view object
 */
public NoteVO createNote(NoteCreateDTO dto) {
    // Business logic
}
```

### 禁止的注释内容

**不能出现以下 AI 生成痕迹的表述**:

- ❌ `phase 1`, `phase 2`, `phase xxx`
- ❌ `适合 DAY1`, `适合第一天`, `第一阶段完成`
- ❌ `TODO: 后续优化`, `TODO: 待实现` (除非有明确的 Issue 编号)
- ❌ 过于冗长的解释性注释

```java
// ❌ 错误示例
/**
 * 笔记服务实现类
 * Phase 1: 基础 CRUD 功能
 * 适合 DAY1 完成
 * TODO: 后续添加更多功能
 */
public class NoteServiceImpl implements NoteService {
}

// ✅ 正确示例
/**
 * 笔记服务实现类
 * 提供笔记的创建、查询、更新、删除功能
 */
public class NoteServiceImpl implements NoteService {
}
```

## 命名规范

### 类命名

| 类型 | 规范 | 示例 |
| :--- | :--- | :--- |
| Controller | `XxxController` | `NoteController` |
| Service 接口 | `XxxService` | `NoteService` |
| Service 实现 | `XxxServiceImpl` | `NoteServiceImpl` |
| Repository 接口 | `XxxRepository` | `NoteRepository` |
| Repository 实现 | `XxxRepositoryImpl` | `NoteRepositoryImpl` |
| Mapper | `XxxMapper` | `NoteMapper` |
| Entity | 业务名词 | `Note`, `User` |
| DTO | `XxxDTO`, `XxxCreateDTO`, `XxxUpdateDTO` | `NoteCreateDTO` |
| VO | `XxxVO` | `NoteVO` |
| 异常 | `XxxException` | `NotFoundException` |
| 领域服务 | `XxxDomainService` | `NoteSharingDomainService` |
| 值对象 | 业务名词 | `Money`, `Email` |

### 方法命名

```java
// 查询
public Note getById(Long id)
public List<Note> listByUserId(Long userId)
public Page<Note> pageByCondition(NoteQueryDTO dto)

// 新增
public Note create(NoteCreateDTO dto)
public void save(Note note)

// 更新
public Note update(Long id, NoteUpdateDTO dto)
public void updateById(Note note)

// 删除
public void delete(Long id)
public void deleteById(Long id)

// 判断
public boolean exists(Long id)
public boolean isOwner(Long noteId, Long userId)
```

### 包命名规范

```
com.doublez.pocketmindserver
├── api                    # 应用层 (Application Layer)
│   └── controller        # Controller
├── application           # 应用服务层
│   ├── service          # 应用服务
│   └── dto              # 数据传输对象
├── domain                # 领域层 (Domain Layer)
│   ├── model            # 聚合根、实体、值对象
│   ├── service          # 领域服务
│   └── repository       # Repository 接口
├── infrastructure        # 基础设施层 (Infrastructure Layer)
│   ├── persistence      # 持久化实现
│   │   ├── mapper       # MyBatis Mapper
│   │   └── repository   # Repository 实现
│   └── ai               # AI 集成实现
└── common                # 公共模块
    ├── exception        # 异常定义
    └── util             # 工具类
```

## 注释规范

### 类注释

```java
/**
 * 笔记服务实现类
 * 
 * 提供笔记的创建、查询、更新、删除功能
 * 
 * @author Your Name
 * @since 2026-04-12
 */
@Service
public class NoteServiceImpl implements NoteService {
}
```

### 方法注释

```java
/**
 * 创建笔记
 * 
 * @param dto 笔记创建请求,包含标题和内容
 * @return 创建成功的笔记视图对象
 * @throws IllegalArgumentException 当标题或内容为空时
 */
@Override
@Transactional(rollbackFor = Exception.class)
public NoteVO createNote(NoteCreateDTO dto) {
    // 实现逻辑
}
```

### 复杂逻辑注释

```java
public void complexMethod() {
    // 1. 验证用户权限
    validatePermission();
    
    // 2. 查询相关数据
    List<Note> notes = fetchNotes();
    
    // 3. 批量处理
    notes.forEach(note -> {
        // 处理单个笔记
        processNote(note);
    });
    
    // 4. 持久化结果
    saveResults();
}
```

## 代码风格

### 空行规范

```java
public class NoteServiceImpl implements NoteService {
    
    private final NoteRepository noteRepository;
    private final UserRepository userRepository;
    
    @Override
    public NoteVO createNote(NoteCreateDTO dto) {
        // 方法实现
    }
    
    @Override
    public NoteVO getById(Long id) {
        // 方法实现
    }
}
```

### 大括号风格

```java
// ✅ 正确 - K&R 风格
if (condition) {
    doSomething();
} else {
    doOtherThing();
}

// ❌ 错误 - Allman 风格
if (condition)
{
    doSomething();
}
```

### 导入顺序

```java
// 1. JDK
import java.util.List;
import java.time.LocalDateTime;

// 2. Spring
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 3. 第三方
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;

// 4. 项目内部
import com.doublez.pocketmindserver.domain.model.Note;
import com.doublez.pocketmindserver.domain.repository.NoteRepository;
```

## Git 提交规约

### Commit Message 格式

```
<type>: <subject>
```

### Type 类型

- `feat`: 新增功能
- `fix`: 修复 Bug
- `refine`: 代码优化/重构
- `doc`: 文档更新
- `test`: 测试相关
- `chore`: 构建/工具链相关

### 示例

```bash
git commit -m "feat: 新增笔记分享功能"
git commit -m "fix: 修复笔记保存失败的问题"
git commit -m "refine: 优化笔记列表查询性能"
git commit -m "doc: 更新 DDD 架构文档"
```

### 禁止内容

- ❌ `phase 1 完成`
- ❌ `适合第一天`
- ❌ `TODO 实现`
- ❌ 英文提交信息

## 代码审查检查清单

### 架构层面
- [ ] Controller 层是否只做参数校验和流量分发
- [ ] Service 层是否正确使用事务
- [ ] 是否通过 Repository 访问数据,而非直接使用 Mapper
- [ ] 领域逻辑是否放在 Domain 层

### 数据访问
- [ ] Entity 是否标注 `@TableName`
- [ ] 是否避免 `SELECT *`
- [ ] 查询是否使用索引
- [ ] 是否存在 N+1 查询问题

### 代码质量
- [ ] 注释是否使用中文
- [ ] 是否包含 AI 生成痕迹
- [ ] 方法是否符合单一职责
- [ ] 是否有适当的异常处理

### 测试覆盖
- [ ] 是否编写单元测试
- [ ] 关键业务逻辑是否有集成测试
- [ ] 测试用例是否覆盖边界情况

## 相关文档

- [后端分层架构](../architecture/backend/layered-architecture.md)
- [后端 DDD 架构](../architecture/backend/ddd-architecture.md)
- [AI 集成规范](../architecture/backend/ai-integration.md)
