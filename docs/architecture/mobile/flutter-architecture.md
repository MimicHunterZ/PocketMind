# Flutter 移动端架构规范

## 概述

PocketMind 移动端基于 Flutter 3.24+ / Dart 3.5+ 构建,追求"杂志感"的视觉体验与工程化的代码质量。

## 技术栈

- **框架**: Flutter 3.24+
- **语言**: Dart 3.5+
- **状态管理**: Riverpod 3.0
- **本地存储**: Isar
- **网络**: Dio
- **代码生成**: freezed, json_serializable, build_runner

## 视觉语言与 UI 审美

### 设计理念

追求"杂志感"不仅仅是排版,更是对**留白与光影的精确控制**。

### 主题系统

**所有 UI 设计字段必须在 `theme_data.dart` 中定义**

```dart
// ✅ 正确 - 从主题系统获取
final textStyle = Theme.of(context).textTheme.bodyLarge;
final primaryColor = Theme.of(context).colorScheme.primary;

// ❌ 错误 - 硬编码
final textStyle = TextStyle(fontSize: 16, color: Colors.black);
final color = Color(0xFF000000);
```

#### theme_data.dart 示例

```dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: Color(0xFF1A1A1A),
      secondary: Color(0xFF757575),
      surface: Color(0xFFFAFAFA),
      background: Color(0xFFFFFFFF),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.15,
      ),
    ),
    extensions: [
      AppSpacing(),
      AppShadows(),
    ],
  );
}

class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs = 4.0;
  final double sm = 8.0;
  final double md = 16.0;
  final double lg = 24.0;
  final double xl = 32.0;
  
  @override
  ThemeExtension<AppSpacing> copyWith() => this;
  
  @override
  ThemeExtension<AppSpacing> lerp(ThemeExtension<AppSpacing>? other, double t) => this;
}
```

### 组件封装

**使用系统组件前必须先查看项目封装**

路径: `mobile/lib/page/widget/`

**禁止直接使用原生组件进行复杂 UI 构建**:

```dart
// ❌ 错误 - 直接使用原生组件
TextField(
  decoration: InputDecoration(
    border: OutlineInputBorder(),
    hintText: '请输入...',
  ),
)

// ✅ 正确 - 使用项目封装
AppTextField(
  hint: '请输入...',
  onChanged: (value) {},
)
```

#### 常用封装组件

- `AppTextField`: 统一风格的输入框
- `AppButton`: 统一风格的按钮
- `AppCard`: 卡片容器
- `AppLoadingIndicator`: 加载指示器
- `AppEmptyState`: 空状态占位

## 数据架构与序列化

### 核心原则

**拒绝样板代码,强制使用自动化工具链确保不可变性**

### 技术选型

| 场景 | 推荐方案 | 核心理由 |
| :--- | :--- | :--- |
| **状态/模型** | `@freezed` | 提供完美的 `copyWith`、`union types` 及值相等性判断 |
| **简单 DTO** | `@JsonSerializable` | 轻量级序列化,适用于不需要不可变特性的临时对象 |
| **时间处理** | `TimestampConverter` | 强制统一。禁止在 UI 层处理 `DateTime` 逻辑 |

### Freezed 使用规范

#### 完整示例

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

#### Union Types (联合类型)

```dart
@freezed
class NoteState with _$NoteState {
  const factory NoteState.initial() = _Initial;
  const factory NoteState.loading() = _Loading;
  const factory NoteState.loaded(List<Note> notes) = _Loaded;
  const factory NoteState.error(String message) = _Error;
}

// 使用
noteState.when(
  initial: () => Text('初始状态'),
  loading: () => CircularProgressIndicator(),
  loaded: (notes) => NoteList(notes: notes),
  error: (message) => ErrorWidget(message: message),
);
```

### 时间处理规范

**后端下发与本地存储均使用毫秒时间戳**

```dart
class TimestampConverter implements JsonConverter<DateTime, int> {
  const TimestampConverter();
  
  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);
  
  @override
  int toJson(DateTime object) => object.millisecondsSinceEpoch;
}
```

**禁止在 UI 层处理 DateTime 逻辑**:

```dart
// ❌ 错误 - UI 层处理时间
Text('创建时间: ${DateTime.parse(note.createdAt).toString()}')

// ✅ 正确 - 使用工具类
Text('创建时间: ${DateFormatter.format(note.createdAt)}')
```

### 代码生成

**任何涉及 @freezed、@JsonSerializable 或 Riverpod 的修改,必须触发构建**:

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 禁止项

**严禁手动编写 `fromJson` / `toJson`**

任何手动修改产生的 Mapping 错误在 Code Review 中将被视为 **一级 Bug**。

## 网络层抽象

### 依赖注入

**必须通过 Riverpod Provider 注入 API Service**

```dart
// api_service.dart
class ApiService {
  final Dio _dio;
  
  ApiService(this._dio);
  
  Future<Note> getNote(String id) async {
    final response = await _dio.get('/api/notes/$id');
    return Note.fromJson(response.data);
  }
}

// providers.dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.pocketmind.app',
    connectTimeout: Duration(seconds: 10),
  ));
  
  // 添加拦截器
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LoggingInterceptor());
  
  return dio;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});
```

### 拦截器隔离

**认证令牌、日志记录、多语言 Header 必须在 Dio 拦截器中统一实现**

```dart
class AuthInterceptor extends Interceptor {
  final Ref ref;
  
  AuthInterceptor(this.ref);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(authTokenProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    final locale = ref.read(localeProvider);
    options.headers['Accept-Language'] = locale.languageCode;
    
    handler.next(options);
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('→ ${options.method} ${options.uri}');
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('✗ ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}
```

### 路径规范

**所有接口定义存放于 `lib/api/`**

**禁止在 UI 逻辑中出现 `dio.get('/url')`**:

```dart
// ❌ 错误 - UI 层直接调用
class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/api/notes'); // 禁止!
  }
}

// ✅ 正确 - 通过 Service 层
final noteServiceProvider = Provider<NoteService>((ref) {
  return NoteService(ref.watch(apiServiceProvider));
});

class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteService = ref.watch(noteServiceProvider);
    // 使用 noteService 的方法
  }
}
```

## 状态管理 (Riverpod 3.0)

### 文档获取

**不清楚具体改动时,使用 `Context7 MCP` 获取最新文档**

### Provider 类型选择

| Provider 类型 | 使用场景 |
| :--- | :--- |
| `Provider` | 不可变的依赖注入 (Service、Repository) |
| `StateProvider` | 简单状态 (计数器、开关) |
| `FutureProvider` | 异步数据加载 |
| `StreamProvider` | 流式数据订阅 |
| `NotifierProvider` | 复杂状态逻辑 |
| `AsyncNotifierProvider` | 异步状态逻辑 |

### NotifierProvider 示例

```dart
@riverpod
class NoteNotifier extends _$NoteNotifier {
  @override
  FutureOr<List<Note>> build() async {
    return ref.watch(noteServiceProvider).fetchNotes();
  }
  
  Future<void> addNote(Note note) async {
    state = AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(noteServiceProvider).createNote(note);
      return ref.read(noteServiceProvider).fetchNotes();
    });
  }
  
  Future<void> deleteNote(String id) async {
    state = AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(noteServiceProvider).deleteNote(id);
      return state.value!.where((note) => note.id != id).toList();
    });
  }
}
```

### 监听 Provider

```dart
class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteState = ref.watch(noteNotifierProvider);
    
    return noteState.when(
      data: (notes) => NoteList(notes: notes),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

## 数据库 (Isar)

### 设计原则

**遵循"持久化驱动展示"原则**:

- UI 订阅 Isar 的 `Watch` 流
- 业务操作直接修改数据库
- UI 自动响应变化

### 实体定义

```dart
@collection
class Note {
  Id id = Isar.autoIncrement;
  
  @Index()
  late String title;
  
  late String content;
  
  @Index()
  late DateTime createdAt;
  
  late DateTime updatedAt;
}
```

### 写操作规范

**所有写操作必须封装在 `isar.writeTxn` 中**:

```dart
class NoteRepository {
  final Isar isar;
  
  NoteRepository(this.isar);
  
  Future<void> saveNote(Note note) async {
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
  }
  
  Future<void> deleteNote(int id) async {
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });
  }
  
  Stream<List<Note>> watchAllNotes() {
    return isar.notes
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }
}
```

### UI 订阅示例

```dart
@riverpod
class LocalNoteNotifier extends _$LocalNoteNotifier {
  @override
  Stream<List<Note>> build() {
    final repo = ref.watch(noteRepositoryProvider);
    return repo.watchAllNotes();
  }
}

class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteStream = ref.watch(localNoteNotifierProvider);
    
    return noteStream.when(
      data: (notes) => ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) => NoteCard(note: notes[index]),
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

## 相关文档

- [UI 组件库](./ui-components.md)
- [状态管理最佳实践](./state-management-patterns.md)
- [本地存储策略](./local-storage.md)
- [网络层设计](./networking.md)
