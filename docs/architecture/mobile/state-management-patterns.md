# Flutter 状态管理最佳实践

## 概述

PocketMind 移动端基于 **Riverpod 3.0** 进行状态管理,本文档定义最佳实践和常见模式。

## 核心原则

### 1. Provider 优先

- 所有状态通过 Provider 管理
- 避免直接使用 StatefulWidget (除非是纯 UI 状态如动画)
- 依赖注入通过 Provider 实现

### 2. 不可变状态

- 使用 `@freezed` 定义状态类
- 通过 `copyWith` 更新状态
- 避免可变集合

### 3. 单一数据流

- 数据单向流动: 用户操作 → Notifier → 状态更新 → UI 重建
- 避免双向绑定
- 状态变化通过 `ref.watch` 自动触发 UI 更新

## Provider 类型选择

### Provider

**用途**: 不可变的依赖注入 (Service、Repository、工具类)

```dart
// API Service 注入
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});

// Repository 注入
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return NoteRepository(isar);
});

// 工具类注入
final dateFormatterProvider = Provider<DateFormatter>((ref) {
  return DateFormatter();
});
```

**特点**:
- ✅ 只创建一次,全局共享
- ✅ 适合无状态的服务和工具
- ❌ 不能用于可变状态

### StateProvider

**用途**: 简单的可变状态 (计数器、开关、选中项)

```dart
// 当前选中的 Tab
final selectedTabProvider = StateProvider<int>((ref) => 0);

// 是否显示已完成项
final showCompletedProvider = StateProvider<bool>((ref) => true);

// 搜索关键词
final searchQueryProvider = StateProvider<String>((ref) => '');

// 使用
class SettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCompleted = ref.watch(showCompletedProvider);
    
    return SwitchListTile(
      title: const Text('显示已完成'),
      value: showCompleted,
      onChanged: (value) {
        // 更新状态
        ref.read(showCompletedProvider.notifier).state = value;
      },
    );
  }
}
```

**特点**:
- ✅ 简单直接,适合布尔值、数字、字符串
- ✅ 可以直接修改 `.state` 属性
- ❌ 不适合复杂对象

### FutureProvider

**用途**: 一次性异步数据加载

```dart
// 加载用户信息
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getUserProfile();
});

// 使用
class ProfilePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    
    return userProfileAsync.when(
      data: (profile) => ProfileView(profile: profile),
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

**特点**:
- ✅ 自动处理加载、成功、错误状态
- ✅ 使用 `.when()` 方法优雅处理三种状态
- ❌ 只能加载一次,不能主动刷新

### StreamProvider

**用途**: 订阅流式数据 (Isar Watch、WebSocket、Firebase)

```dart
// 订阅笔记列表 (Isar Watch)
final noteListStreamProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchAllNotes();
});

// 使用
class NoteListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(noteListStreamProvider);
    
    return notesAsync.when(
      data: (notes) => ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) => NoteCard(note: notes[index]),
      ),
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

**特点**:
- ✅ 自动订阅和取消订阅
- ✅ 数据变化自动触发 UI 更新
- ✅ 适合 Isar Watch、实时数据同步

### NotifierProvider

**用途**: 复杂状态逻辑 (可变状态 + 业务方法)

```dart
// 笔记状态
@freezed
class NoteListState with _$NoteListState {
  const factory NoteListState({
    @Default([]) List<Note> notes,
    @Default(false) bool loading,
    String? error,
  }) = _NoteListState;
}

// Notifier (Riverpod 3.0 语法)
@riverpod
class NoteListNotifier extends _$NoteListNotifier {
  @override
  NoteListState build() {
    return const NoteListState();
  }
  
  Future<void> loadNotes() async {
    state = state.copyWith(loading: true, error: null);
    
    try {
      final noteService = ref.read(noteServiceProvider);
      final notes = await noteService.fetchNotes();
      state = state.copyWith(notes: notes, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
  
  Future<void> addNote(Note note) async {
    final noteService = ref.read(noteServiceProvider);
    await noteService.createNote(note);
    
    // 重新加载
    await loadNotes();
  }
  
  Future<void> deleteNote(String id) async {
    final noteService = ref.read(noteServiceProvider);
    await noteService.deleteNote(id);
    
    // 乐观更新
    state = state.copyWith(
      notes: state.notes.where((note) => note.id != id).toList(),
    );
  }
}

// 使用
class NoteListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteListState = ref.watch(noteListNotifierProvider);
    
    if (noteListState.loading) {
      return const AppLoadingIndicator();
    }
    
    if (noteListState.error != null) {
      return ErrorWidget(noteListState.error!);
    }
    
    return ListView.builder(
      itemCount: noteListState.notes.length,
      itemBuilder: (context, index) {
        return NoteCard(
          note: noteListState.notes[index],
          onDelete: () {
            ref.read(noteListNotifierProvider.notifier)
              .deleteNote(noteListState.notes[index].id);
          },
        );
      },
    );
  }
}
```

**特点**:
- ✅ 适合复杂业务逻辑
- ✅ 状态和方法封装在一起
- ✅ 可以读取其他 Provider

### AsyncNotifierProvider

**用途**: 异步初始化的复杂状态

```dart
@riverpod
class NoteDetailNotifier extends _$NoteDetailNotifier {
  @override
  Future<Note> build(String noteId) async {
    // 异步加载初始状态
    final noteService = ref.read(noteServiceProvider);
    return noteService.fetchNote(noteId);
  }
  
  Future<void> updateTitle(String title) async {
    final currentNote = state.value!;
    
    // 乐观更新
    state = AsyncValue.data(currentNote.copyWith(title: title));
    
    try {
      final noteService = ref.read(noteServiceProvider);
      await noteService.updateNote(currentNote.id, title: title);
    } catch (e) {
      // 失败后回滚
      state = AsyncValue.data(currentNote);
      rethrow;
    }
  }
}

// 使用
class NoteDetailPage extends ConsumerWidget {
  final String noteId;
  
  const NoteDetailPage({required this.noteId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailNotifierProvider(noteId));
    
    return noteAsync.when(
      data: (note) => NoteView(
        note: note,
        onTitleChanged: (title) {
          ref.read(noteDetailNotifierProvider(noteId).notifier)
            .updateTitle(title);
        },
      ),
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => ErrorWidget(error.toString()),
    );
  }
}
```

**特点**:
- ✅ 适合需要异步加载初始数据的场景
- ✅ 自动处理 AsyncValue 状态
- ✅ 支持参数化 Provider

## 最佳实践

### 1. 使用 autoDispose

**自动清理不再使用的 Provider**:

```dart
// ✅ 正确 - 自动清理
@riverpod
class NoteDetailNotifier extends _$NoteDetailNotifier {
  // 默认就是 autoDispose
}

// 或显式指定
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  // ...
});
```

**何时不使用 autoDispose**:
- 全局共享的 Provider (如 Dio、Isar)
- 需要缓存的数据

### 2. Provider 组合

**复用其他 Provider 的状态**:

```dart
// 依赖其他 Provider
@riverpod
class FilteredNoteNotifier extends _$FilteredNoteNotifier {
  @override
  List<Note> build() {
    // 读取原始笔记列表
    final allNotes = ref.watch(noteListNotifierProvider).notes;
    
    // 读取搜索关键词
    final searchQuery = ref.watch(searchQueryProvider);
    
    // 过滤
    if (searchQuery.isEmpty) return allNotes;
    return allNotes.where((note) => note.title.contains(searchQuery)).toList();
  }
}
```

### 3. 乐观更新

**先更新 UI,后台同步**:

```dart
Future<void> toggleComplete(String noteId) async {
  // 1. 立即更新 UI (乐观更新)
  state = state.copyWith(
    notes: state.notes.map((note) {
      if (note.id == noteId) {
        return note.copyWith(completed: !note.completed);
      }
      return note;
    }).toList(),
  );
  
  // 2. 后台同步
  try {
    await noteService.updateNote(noteId, completed: true);
  } catch (e) {
    // 3. 失败后回滚
    state = state.copyWith(
      notes: state.notes.map((note) {
        if (note.id == noteId) {
          return note.copyWith(completed: !note.completed);
        }
        return note;
      }).toList(),
    );
    rethrow;
  }
}
```

### 4. 错误处理

**使用 AsyncValue.guard**:

```dart
Future<void> loadNotes() async {
  state = const AsyncValue.loading();
  
  state = await AsyncValue.guard(() async {
    final notes = await noteService.fetchNotes();
    return notes;
  });
}
```

### 5. 生命周期管理

**监听 Provider 创建和销毁**:

```dart
@riverpod
class NoteDetailNotifier extends _$NoteDetailNotifier {
  @override
  Future<Note> build(String noteId) async {
    // 监听销毁
    ref.onDispose(() {
      print('NoteDetailNotifier disposed');
    });
    
    return noteService.fetchNote(noteId);
  }
}
```

### 6. 局部状态 vs 全局状态

**原则**:
- ✅ 局部状态: 仅影响单个页面的状态 (如表单输入、展开/折叠)
- ✅ 全局状态: 跨页面共享的状态 (如用户信息、主题设置)

```dart
// ❌ 错误 - 按钮展开状态不应该用 Provider
final expandedProvider = StateProvider<bool>((ref) => false);

// ✅ 正确 - 使用 StatefulWidget
class ExpandableCard extends StatefulWidget {
  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool _expanded = false;
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

## 常见模式

### 分页加载

```dart
@riverpod
class NoteListNotifier extends _$NoteListNotifier {
  @override
  NoteListState build() {
    return const NoteListState(page: 1, hasMore: true);
  }
  
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    
    state = state.copyWith(loading: true);
    
    try {
      final notes = await noteService.fetchNotes(page: state.page);
      state = state.copyWith(
        notes: [...state.notes, ...notes],
        page: state.page + 1,
        hasMore: notes.length == pageSize,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
```

### 下拉刷新

```dart
Future<void> refresh() async {
  state = const NoteListState();  // 重置状态
  await loadNotes();
}
```

### 搜索防抖

```dart
@riverpod
class SearchNotifier extends _$SearchNotifier {
  Timer? _debounceTimer;
  
  @override
  SearchState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const SearchState();
  }
  
  void updateQuery(String query) {
    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }
  
  Future<void> _performSearch(String query) async {
    state = state.copyWith(query: query, loading: true);
    
    try {
      final results = await searchService.search(query);
      state = state.copyWith(results: results, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
```

## 相关文档

- [Flutter 架构规范](./flutter-architecture.md)
- [移动端编码规约](../../conventions/mobile-coding-standards.md)
