# 移动端编码规约

## 概述

本文档定义 PocketMind 移动端 (Flutter/Dart) 的编码标准、命名规范和注释要求。

## 通用规约

### 注释语言

**所有代码注释、文档注释必须使用中文**

```dart
// ✅ 正确
/// 创建笔记
/// 
/// [note] 要创建的笔记对象
/// 
/// 返回创建成功的笔记,如果失败抛出 [DioException]
Future<Note> createNote(Note note) async {
  // 业务逻辑
}

// ❌ 错误
/// Create a new note
/// 
/// [note] note object to create
/// 
/// Returns created note, throws [DioException] on failure
Future<Note> createNote(Note note) async {
  // Business logic
}
```

### 禁止的注释内容

**不能出现以下 AI 生成痕迹的表述**:

- ❌ `phase 1`, `phase 2`, `phase xxx`
- ❌ `适合 DAY1`, `适合第一天`, `第一阶段完成`
- ❌ `TODO: 后续优化`, `TODO: 待实现` (除非有明确的 Issue 编号)
- ❌ 过于冗长的解释性注释

```dart
// ❌ 错误示例
/// 笔记服务类
/// Phase 1: 基础 CRUD 功能
/// 适合 DAY1 完成
/// TODO: 后续添加更多功能
class NoteService {
}

// ✅ 正确示例
/// 笔记服务类
/// 
/// 提供笔记的网络请求和数据转换功能
class NoteService {
}
```

## 命名规范

### 文件命名

**使用 `snake_case`**

```
note_service.dart
note_list_page.dart
note_card_widget.dart
```

### 类命名

**使用 `PascalCase`**

| 类型 | 规范 | 示例 |
| :--- | :--- | :--- |
| Widget | `XxxPage`, `XxxWidget`, `XxxCard` | `NotePage`, `NoteCard` |
| Service | `XxxService` | `NoteService` |
| Repository | `XxxRepository` | `NoteRepository` |
| Provider | `xxxProvider` | `noteServiceProvider` |
| Model | 业务名词 | `Note`, `User` |
| State | `XxxState` | `NoteState` |
| Notifier | `XxxNotifier` | `NoteNotifier` |

### 方法命名

**使用 `camelCase`**

```dart
// 查询
Note getById(String id)
List<Note> getAll()
Future<Note> fetchById(String id)
Future<List<Note>> fetchAll()

// 新增
Future<void> create(Note note)
Future<void> save(Note note)

// 更新
Future<void> update(Note note)

// 删除
Future<void> delete(String id)

// 判断
bool exists(String id)
bool isValid()

// 监听
Stream<List<Note>> watchAll()
Stream<Note?> watchById(String id)
```

### 变量命名

```dart
// 私有变量前缀 _
final _dio = Dio();

// 常量使用 lowerCamelCase
const defaultPadding = 16.0;

// 全局常量使用 k 前缀
const kDefaultPadding = 16.0;
const kAnimationDuration = Duration(milliseconds: 300);
```

### 目录结构

```
lib/
├── api/              # 网络请求层
├── models/           # 数据模型
├── providers/        # Riverpod Providers
├── repositories/     # 数据仓储层
├── services/         # 业务服务层
├── pages/            # 页面
│   └── widgets/      # 可复用组件
├── theme/            # 主题配置
│   └── theme_data.dart
└── utils/            # 工具类
```

## 注释规范

### 类注释

```dart
/// 笔记服务类
/// 
/// 提供笔记的网络请求和数据转换功能
class NoteService {
  final ApiService _apiService;
  
  NoteService(this._apiService);
}
```

### 方法注释

```dart
/// 创建笔记
/// 
/// [note] 要创建的笔记对象
/// 
/// 返回创建成功的笔记,如果失败抛出 [DioException]
Future<Note> createNote(Note note) async {
  // 实现逻辑
}
```

### Widget 注释

```dart
/// 笔记卡片组件
/// 
/// 显示笔记的标题、预览内容和创建时间
class NoteCard extends StatelessWidget {
  /// 笔记数据
  final Note note;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: ListTile(
          title: Text(note.title),
          subtitle: Text(note.content),
        ),
      ),
    );
  }
}
```

## 代码风格

### 导入顺序

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 第三方包
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// 4. 项目内部
import 'package:pocketmind/models/note.dart';
import 'package:pocketmind/services/note_service.dart';
```

### 常量定义

```dart
// ✅ 正确 - 使用 const
const kDefaultPadding = 16.0;
const kAnimationDuration = Duration(milliseconds: 300);

// ❌ 错误 - 使用 var/final
var defaultPadding = 16.0;
final animationDuration = Duration(milliseconds: 300);
```

### Widget 构建

**提取复杂 Widget 为私有方法**

```dart
// ✅ 正确
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: _buildAppBar(),
    body: _buildBody(),
    floatingActionButton: _buildFAB(),
  );
}

Widget _buildAppBar() {
  return AppBar(
    title: const Text('笔记'),
  );
}

Widget _buildBody() {
  return ListView.builder(
    itemCount: notes.length,
    itemBuilder: (context, index) => NoteCard(note: notes[index]),
  );
}

Widget _buildFAB() {
  return FloatingActionButton(
    onPressed: _onAddNote,
    child: const Icon(Icons.add),
  );
}

// ❌ 错误 - 所有逻辑堆在 build 方法中
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('笔记'),
    ),
    body: ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => _onTap(notes[index]),
        child: Card(
          child: ListTile(
            title: Text(notes[index].title),
            subtitle: Text(notes[index].content),
          ),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _onAddNote,
      child: const Icon(Icons.add),
    ),
  );
}
```

### 空行规范

```dart
class NoteService {
  final ApiService _apiService;
  
  NoteService(this._apiService);
  
  Future<Note> createNote(Note note) async {
    // 方法实现
  }
  
  Future<Note> getNote(String id) async {
    // 方法实现
  }
}
```

### 使用 const 构造函数

```dart
// ✅ 正确
const Text('标题')
const SizedBox(height: 16)
const EdgeInsets.all(16)

// ❌ 错误
Text('标题')
SizedBox(height: 16)
EdgeInsets.all(16)
```

## 数据模型规约

### Freezed 使用

**状态和领域模型必须使用 @freezed**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';
part 'note.g.dart';

@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
    required String content,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime updatedAt,
  }) = _Note;
  
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
```

### 禁止手动序列化

```dart
// ❌ 错误 - 手动编写
class Note {
  final String id;
  final String title;
  
  Note({required this.id, required this.title});
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
  
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
    );
  }
}

// ✅ 正确 - 使用代码生成
@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
  }) = _Note;
  
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
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
git commit -m "fix: 修复笔记列表滚动卡顿问题"
git commit -m "refine: 优化笔记卡片渲染性能"
git commit -m "doc: 更新 Flutter 架构文档"
```

### 禁止内容

- ❌ `phase 1 完成`
- ❌ `适合第一天`
- ❌ `TODO 实现`
- ❌ 英文提交信息

## 代码审查检查清单

### UI 层面
- [ ] 是否使用项目封装的组件
- [ ] 是否从 `theme_data.dart` 获取设计元素
- [ ] 是否避免硬编码颜色、字体大小
- [ ] 是否使用 const 构造函数

### 数据层面
- [ ] 是否使用 `@freezed` 定义模型
- [ ] 是否禁止手动编写 `fromJson`/`toJson`
- [ ] 时间是否使用 `TimestampConverter`
- [ ] 是否避免在 UI 层处理 DateTime 逻辑

### 架构层面
- [ ] 是否通过 Provider 注入依赖
- [ ] 是否在拦截器中统一处理认证
- [ ] UI 层是否直接调用 Dio (应该通过 Service)
- [ ] 是否使用 Repository 模式访问本地数据

### 代码质量
- [ ] 注释是否使用中文
- [ ] 是否包含 AI 生成痕迹
- [ ] 是否提取复杂 Widget
- [ ] 是否有适当的异常处理

### 测试覆盖
- [ ] 是否编写单元测试
- [ ] 关键 Widget 是否有 Widget 测试
- [ ] 关键流程是否有集成测试

## 相关文档

- [Flutter 架构规范](../architecture/mobile/flutter-architecture.md)
- [开发工作流](../workflows/development-workflow.md)
