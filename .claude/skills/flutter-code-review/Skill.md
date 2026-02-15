---
name: flutter-code-review
description: 针对 Flutter 项目的深度工程化审查工具。用于检测架构异味、强制执行 SOLID 原则、优化状态管理流向以及确保代码的可测试性和可维护性。当用户请求 Review、重构或优化 Dart 代码时触发。
---

# Flutter Engineering Guard

本 Skill 旨在将一段随意的 Flutter 代码转化为符合企业级标准的工程代码。它不进行闲聊，不提供模棱两可的建议，直接输出符合架构标准的重构代码。

## 核心审查原则 (Core Principles)

### 1. 架构分层与解耦 (Architecture & Decoupling)
- **严格的分层边界**: UI 层 (Widgets) 严禁包含业务逻辑、数据库操作或网络请求。所有逻辑必须下沉至 Domain/Application 层 (Riverpod)。
- **依赖倒置 (DIP)**: 上层模块不应依赖底层实现，而应依赖抽象接口。检查是否使用了 `Repository` 接口而非具体实现类。
- **单一数据源 (SSOT)**: 确保数据的状态变更只有唯一入口,同个业务的变更路径唯一。

### 2. 代码健壮性与可维护性 (Robustness & Maintainability)
- **防御性编程**: 所有的外部输入（API, JSON）必须经过严格的类型校验和空安全处理。
- **不可变性 (Immutability)**: 优先使用 `final` 字段和 `const` 构造函数。状态类应当是不可变的 (`@immutable` / `freezed`)，通过 `copyWith` 更新而非直接修改属性。
- **错误处理边界**: `try-catch` 不应散落在 UI 中。错误应在 Repository 层捕获并转化为自定义 `Failure` 类型，最终由状态管理层统一暴露给 UI。

### 3. Flutter 特性优化 (Flutter Specifics)
- **构建纯净性**: `build()` 方法必须无副作用。
- **上下文安全**: 所有的 `BuildContext` 跨异步间隙使用必须有 `mounted` 检查。
- **资源生命周期**: 显式检查 `Controller`, `StreamSubscription`, `Timer` 的 `dispose` 逻辑。

## 执行流程 (Execution Workflow)

当收到代码时，不进行寒暄，直接按照以下步骤处理：

1.  **扫描 (Scan)**: 识别违反上述原则的代码块。
2.  **定位 (Locate)**: 标记文件名或行号。
3.  **重构 (Refactor)**: 直接生成符合标准的替代代码块。

## 响应模板 (Response Template)

输出必须严格遵循以下格式，无多余废话：

### 🚨 Critical Refactoring (必须修复)

> **[规则名称]**: 一句话解释违反了什么工程原则（如：违反单一职责，UI 直接依赖数据库）。

```dart
// Refactored Code (直接可用的修复代码)
class UserProfileNotifier extends StateNotifier<UserState> {
  final UserRepository _repository; // 依赖接口
  
  UserProfileNotifier(this._repository) : super(const UserState.initial());

  Future<void> updateProfile(String name) async {
    try {
      // 业务逻辑内聚
      final result = await _repository.updateName(name);
      state = state.copyWith(data: result);
    } catch (e) {
      state = state.copyWith(error: UserFailure.from(e));
    }
  }
}

```

### ⚠️ Optimization & Best Practices (建议优化)

> **[优化点]**: 说明性能或规范问题（如：缺少 const，列表未复用）。

```dart
// Optimized Code
ListView.builder(
  itemExtent: 50.0, // 强制高度优化性能
  itemCount: items.length,
  itemBuilder: (context, index) => const UserListItem(key: ValueKey(id)), // const + keys
);

```

---

## 常见违规案例与标准修正 (Reference Patterns)

### Case 1: 逻辑泄漏 (Logic Leakage)

**❌ Bad:**

```dart
// UI 直接调用 HTTP
onTap: () async {
  var response = await http.post('api/user');
  if (response.statusCode == 200) setState(() { ... });
}

```

**✅ Standard:**

```dart
// UI 仅分发事件
onTap: () => ref.read(userControllerProvider.notifier).updateUser();

```

### Case 2: 依赖耦合 (Tight Coupling)

**❌ Bad:**

```dart
class MyWidget {
  final ApiService api = ApiService(); // 直接依赖实现
}

```

**✅ Standard:**

```dart
class MyWidget {
  final IApiService api; // 依赖抽象
  const MyWidget({required this.api});
}

```

### Case 3: 可变状态 (Mutable State)

**❌ Bad:**

```dart
class State {
  List<String> items = []; // 可变列表
}
state.items.add('new'); // 难以追踪变更

```

**✅ Standard:**

```dart
@freezed
class State with _$State {
  const factory State({@Default([]) List<String> items}) = _State;
}
// update
state = state.copyWith(items: [...state.items, 'new']);

```
