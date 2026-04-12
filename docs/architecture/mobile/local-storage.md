# Flutter 本地存储策略

## 概述

PocketMind 移动端使用 **Isar** 作为本地数据库,本文档定义本地存储的最佳实践。

## 技术选型

### Isar 优势

- ✅ **高性能**: 比 Hive/SQLite 更快
- ✅ **类型安全**: 强类型,编译时检查
- ✅ **响应式**: `watch()` 方法实时监听数据变化
- ✅ **全文搜索**: 内置全文索引
- ✅ **关系支持**: 支持一对多、多对多关系
- ✅ **跨平台**: 支持 iOS/Android/Desktop/Web

## 核心原则

### 1. 持久化驱动展示

**数据流**:
```
用户操作 → 写入 Isar → Watch 流触发 → UI 自动更新
```

**优势**:
- ✅ 数据库是单一事实来源 (Single Source of Truth)
- ✅ 无需手动管理状态同步
- ✅ 离线优先,本地数据即时可用

### 2. 写操作事务化

**所有写操作必须在事务中**:
```dart
// ✅ 正确
await isar.writeTxn(() async {
  await isar.notes.put(note);
});

// ❌ 错误 - 没有事务
await isar.notes.put(note);
```

### 3. 查询优化

- 使用索引加速查询
- 避免加载不需要的字段
- 批量操作使用批量 API

## 实体定义

### 基础实体

```dart
import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  /// 自增主键
  Id id = Isar.autoIncrement;
  
  /// UUID (用于跨设备同步)
  @Index(unique: true)
  late String uuid;
  
  /// 用户 ID
  @Index()
  late int userId;
  
  /// 标题
  @Index(type: IndexType.value)  // 全文索引
  late String title;
  
  /// 内容
  late String content;
  
  /// 创建时间
  @Index()
  late DateTime createdAt;
  
  /// 更新时间
  late DateTime updatedAt;
  
  /// 服务器版本 (用于同步)
  late int serverVersion;
  
  /// 是否已删除 (逻辑删除)
  @Index()
  @Default(false)
  late bool isDeleted;
}
```

### 索引策略

| 索引类型 | 用途 | 示例 |
| :--- | :--- | :--- |
| `@Index()` | 精确匹配查询 | `userId`, `uuid` |
| `@Index(type: IndexType.value)` | 全文搜索 | `title`, `content` |
| `@Index(unique: true)` | 唯一约束 | `uuid` |
| `@Index(composite: [...])`| 组合索引 | `[userId, createdAt]` |

### 关系定义

#### 一对多关系

```dart
@collection
class Category {
  Id id = Isar.autoIncrement;
  late String name;
  
  // 反向链接 (自动维护)
  @Backlink(to: 'category')
  final notes = IsarLinks<Note>();
}

@collection
class Note {
  Id id = Isar.autoIncrement;
  late String title;
  
  // 多对一关系
  final category = IsarLink<Category>();
}
```

#### 多对多关系

```dart
@collection
class Note {
  Id id = Isar.autoIncrement;
  late String title;
  
  // 多对多关系
  final tags = IsarLinks<Tag>();
}

@collection
class Tag {
  Id id = Isar.autoIncrement;
  late String name;
  
  @Backlink(to: 'tags')
  final notes = IsarLinks<Note>();
}
```

## Repository 模式

### Repository 接口

```dart
abstract class NoteRepository {
  /// 保存笔记
  Future<void> save(Note note);
  
  /// 批量保存
  Future<void> saveAll(List<Note> notes);
  
  /// 根据 ID 查询
  Future<Note?> findById(int id);
  
  /// 根据 UUID 查询
  Future<Note?> findByUuid(String uuid);
  
  /// 查询所有笔记
  Future<List<Note>> findAll();
  
  /// 查询用户的笔记
  Future<List<Note>> findByUserId(int userId);
  
  /// 全文搜索
  Future<List<Note>> search(String query);
  
  /// 删除笔记
  Future<void> delete(int id);
  
  /// 监听所有笔记
  Stream<List<Note>> watchAll();
  
  /// 监听单个笔记
  Stream<Note?> watchById(int id);
}
```

### Repository 实现

```dart
class NoteRepositoryImpl implements NoteRepository {
  final Isar isar;
  
  NoteRepositoryImpl(this.isar);
  
  @override
  Future<void> save(Note note) async {
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
  }
  
  @override
  Future<void> saveAll(List<Note> notes) async {
    await isar.writeTxn(() async {
      await isar.notes.putAll(notes);
    });
  }
  
  @override
  Future<Note?> findById(int id) async {
    return isar.notes.get(id);
  }
  
  @override
  Future<Note?> findByUuid(String uuid) async {
    return isar.notes.filter().uuidEqualTo(uuid).findFirst();
  }
  
  @override
  Future<List<Note>> findAll() async {
    return isar.notes
        .filter()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }
  
  @override
  Future<List<Note>> findByUserId(int userId) async {
    return isar.notes
        .filter()
        .userIdEqualTo(userId)
        .and()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }
  
  @override
  Future<List<Note>> search(String query) async {
    return isar.notes
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .and()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }
  
  @override
  Future<void> delete(int id) async {
    await isar.writeTxn(() async {
      // 逻辑删除
      final note = await isar.notes.get(id);
      if (note != null) {
        note.isDeleted = true;
        await isar.notes.put(note);
      }
    });
  }
  
  @override
  Stream<List<Note>> watchAll() {
    return isar.notes
        .filter()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }
  
  @override
  Stream<Note?> watchById(int id) {
    return isar.notes
        .watchObject(id, fireImmediately: true);
  }
}
```

## 查询最佳实践

### 1. 使用索引

```dart
// ✅ 正确 - 使用索引字段
final notes = await isar.notes
    .filter()
    .userIdEqualTo(userId)  // userId 有索引
    .findAll();

// ❌ 错误 - 未使用索引
final notes = await isar.notes
    .filter()
    .contentContains('flutter')  // content 没有索引
    .findAll();
```

### 2. 限制返回字段

```dart
// ✅ 正确 - 只查询需要的字段
final titles = await isar.notes
    .where()
    .findAll()
    .then((notes) => notes.map((n) => n.title).toList());

// ❌ 错误 - 加载所有字段
final notes = await isar.notes.where().findAll();
```

### 3. 批量操作

```dart
// ✅ 正确 - 批量插入
await isar.writeTxn(() async {
  await isar.notes.putAll(notes);  // 一次事务
});

// ❌ 错误 - 逐个插入
for (final note in notes) {
  await isar.writeTxn(() async {
    await isar.notes.put(note);  // 多次事务
  });
}
```

### 4. 分页查询

```dart
Future<List<Note>> findByPage(int page, int pageSize) async {
  return isar.notes
      .filter()
      .isDeletedEqualTo(false)
      .sortByCreatedAtDesc()
      .offset(page * pageSize)
      .limit(pageSize)
      .findAll();
}
```

### 5. 聚合查询

```dart
// 统计笔记数量
final count = await isar.notes
    .filter()
    .userIdEqualTo(userId)
    .and()
    .isDeletedEqualTo(false)
    .count();

// 查询最新笔记
final latestNote = await isar.notes
    .filter()
    .isDeletedEqualTo(false)
    .sortByCreatedAtDesc()
    .findFirst();
```

## 数据同步策略

### 同步状态管理

```dart
@collection
class Note {
  Id id = Isar.autoIncrement;
  
  // ... 其他字段
  
  /// 服务器版本号
  late int serverVersion;
  
  /// 本地修改时间戳
  late int localModifiedAt;
  
  /// 同步状态
  @enumerated
  late SyncStatus syncStatus;
}

enum SyncStatus {
  synced,       // 已同步
  pending,      // 待上传
  conflict,     // 冲突
}
```

### 增量同步

```dart
class SyncService {
  final NoteRepository noteRepository;
  final ApiService apiService;
  
  /// 拉取服务器更新
  Future<void> pullFromServer(int userId) async {
    // 1. 获取本地最大版本号
    final maxVersion = await _getMaxServerVersion(userId);
    
    // 2. 请求增量数据
    final serverNotes = await apiService.fetchNotesSince(
      userId: userId,
      sinceVersion: maxVersion,
    );
    
    // 3. 保存到本地
    await noteRepository.saveAll(serverNotes);
  }
  
  /// 推送本地修改
  Future<void> pushToServer(int userId) async {
    // 1. 查询待上传的笔记
    final pendingNotes = await isar.notes
        .filter()
        .userIdEqualTo(userId)
        .and()
        .syncStatusEqualTo(SyncStatus.pending)
        .findAll();
    
    // 2. 上传到服务器
    for (final note in pendingNotes) {
      try {
        final serverNote = await apiService.updateNote(note);
        
        // 3. 更新本地状态
        note.serverVersion = serverNote.serverVersion;
        note.syncStatus = SyncStatus.synced;
        await noteRepository.save(note);
      } catch (e) {
        // 处理冲突
        note.syncStatus = SyncStatus.conflict;
        await noteRepository.save(note);
      }
    }
  }
  
  Future<int> _getMaxServerVersion(int userId) async {
    final notes = await isar.notes
        .filter()
        .userIdEqualTo(userId)
        .findAll();
    
    if (notes.isEmpty) return 0;
    return notes.map((n) => n.serverVersion).reduce(math.max);
  }
}
```

## 数据迁移

### Schema 版本管理

```dart
// 初始版本
final isar = await Isar.open(
  [NoteSchema, TagSchema],
  directory: dir.path,
  version: 1,
);

// 升级到版本 2
if (isar.version < 2) {
  await _migrateToV2(isar);
}

Future<void> _migrateToV2(Isar isar) async {
  await isar.writeTxn(() async {
    // 添加默认值
    final notes = await isar.notes.where().findAll();
    for (final note in notes) {
      note.serverVersion = note.serverVersion ?? 0;
      await isar.notes.put(note);
    }
  });
}
```

## 性能优化

### 1. 使用 Lazy Loading

```dart
// ✅ 正确 - 延迟加载关系
final note = await isar.notes.get(id);
await note.category.load();  // 需要时才加载

// ❌ 错误 - 预加载所有关系
final notes = await isar.notes.where().findAll();
for (final note in notes) {
  await note.category.load();  // N+1 查询
}
```

### 2. 使用缓存

```dart
class CachedNoteRepository implements NoteRepository {
  final NoteRepositoryImpl _repository;
  final _cache = <String, Note>{};
  
  @override
  Future<Note?> findByUuid(String uuid) async {
    // 先查缓存
    if (_cache.containsKey(uuid)) {
      return _cache[uuid];
    }
    
    // 缓存未命中,查询数据库
    final note = await _repository.findByUuid(uuid);
    if (note != null) {
      _cache[uuid] = note;
    }
    return note;
  }
}
```

### 3. 后台线程

```dart
// Isar 查询默认在 isolate 中执行,无需手动处理
final notes = await isar.notes.where().findAll();  // 自动后台执行
```

## 调试工具

### Isar Inspector

```dart
// 开发环境启用 Inspector
if (kDebugMode) {
  final isar = await Isar.open(
    [NoteSchema],
    directory: dir.path,
    inspector: true,  // 启用 Inspector
  );
}

// 访问 http://localhost:8080 查看数据
```

## 相关文档

- [Flutter 架构规范](./flutter-architecture.md)
- [状态管理最佳实践](./state-management-patterns.md)
- [移动端编码规约](../../conventions/mobile-coding-standards.md)
