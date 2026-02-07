# PocketMind Copilot Instructions

You are an expert AI coding assistant for PocketMind, a "Second Brain" application consisting of a Flutter mobile app and a Spring Boot backend.

## 🏗️ Project Architecture

### Monorepo Structure
- `mobile/`: Flutter application (Android/Windows).
- `backend/`: Spring Boot application (AI services).

### Mobile (Flutter) - Clean Architecture
The mobile app strictly follows **Clean Architecture** principles.
- **Domain Layer** (`lib/domain/`): Pure Dart. Contains `Entities` and `Repository Interfaces`.
  - **Rule**: NEVER import `isar` or `flutter` specific packages here.
- **Data Layer** (`lib/data/`): Implements Repositories.
  - Contains `Isar Models` (`lib/model/`), `Mappers` (`lib/data/mappers/`), and `Repository Implementations`.
  - **Rule**: Only this layer interacts with the database.
- **Application Layer** (`lib/service/`): Business logic.
  - **Rule**: Depends only on Domain interfaces.
- **Presentation Layer** (`lib/page/`, `lib/providers/`): UI and State Management.
  - **Rule**: Uses `Riverpod` for state management.

### Backend (Spring Boot)
- Standard Spring Boot structure (`Controller` -> `Service` -> `Repository`).
- Package: `com.doublez.pocketmindserver`.
- Uses **Spring AI** for AI features.

## 🚨 Critical Rules & Conventions

### 1. Entity vs. Model Separation (Mobile)
- **Strict Separation**: UI and Service layers MUST use **Domain Entities** (`NoteEntity`), NOT Database Models (`Note`).
- **Mappers**: Always use Mappers (`NoteMapper`) to convert between Entities and Models in the Data layer.
- **Imports**: Check imports carefully. `import 'package:pocketmind/model/...'` is forbidden in UI/Service layers.

### 2. State Management (Riverpod)
- Use manual provider definitions (`Provider`, `StateProvider`, `StreamProvider`, `StreamNotifierProvider`).
- Do NOT use `@riverpod` code generation annotations unless specifically requested to refactor.
- Prefer `ref.watch` inside `build` methods and `ref.read` inside callbacks.

### 3. Database (Isar)
- Database operations are encapsulated in `IsarNoteRepository` (or similar).
- Use `isar.writeTxn(() async { ... })` for all write operations.

### 4. 网络 & HTTP (Mobile)
- **Rule**: NEVER use `Dio` directly in business logic or utility classes.
- **HttpClient**: Always use the encapsulated `HttpClient` from `package:pocketmind/api/http_client.dart`.
- **Usage**: Access the Dio instance via `HttpClient().dio`.

### 5. Data Serialization (Mobile)
- **Rule**: NEVER write `fromJson()`, `toJson()`, or `toString()` methods manually.
- **Mutable Classes** (e.g., `ScraperTask` where fields can be modified after creation): Use `@JsonSerializable()` from `json_serializable` package.
- **Immutable Classes** (e.g., UI state models): Use `@freezed` from `freezed_annotation` package.
- **DateTime Serialization**: Use `@JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)` with helper functions:
  ```dart
  DateTime _dateTimeFromJson(int timestamp) => DateTime.fromMillisecondsSinceEpoch(timestamp);
  int _dateTimeToJson(DateTime date) => date.millisecondsSinceEpoch;
  ```
- **Code Generation**: Run `flutter pub run build_runner build --delete-conflicting-outputs` after changes.
- **part directive**: Include `part 'filename.g.dart';` for json_serializable or `part 'filename.freezed.dart';` for freezed.

### 6. Backend Development
- **ORM**: Use **MyBatis-Plus** for the persistence layer.
- **Architecture**: Strictly follow **MVC Layered Architecture** (Controller -> Service -> Repository). Do NOT write business logic in Controllers.
- **Observability**: Implement comprehensive logging for all features to ensure good observability.
- **Comments**: All comments must be in **Chinese**.
- **Dependencies**: Before adding any dependency, use `context7 mcp` to check for the latest and compatible versions.

## 🏗️ 核心架构准则 (Core Architecture Rules)

### 1. 单一职责原则 (Single Responsibility)
- **UI 层**: 仅负责展示数据和转发用户交互。严禁包含路径解析、网络请求或复杂的业务逻辑。
- **Service 层**: 业务逻辑的编排者。负责调度 Manager 和 Repository，处理跨实体的业务流程。
- **Manager 层**: 专门的数据加工厂（如 `MetadataManager`）。负责具体的协议解析、资源本地化等，不直接操作数据库。

### 2. 持久化驱动展示 (Persistence Driven)
- UI 必须通过订阅数据库（Isar）的变化来更新。
- 严禁在 UI 内存中维护复杂的临时状态，所有业务结果必须先落库，再通过流（Stream）反馈给 UI。

### 3. 失败静默与重试机制
- 元数据抓取或资源本地化失败时，**严禁**向数据库写入错误占位数据（如 "No Title" 或错误提示文字）。
- 数据库字段应保持为 `null`。UI 层根据字段为 `null` 且非加载状态，显示“预览失败，请检查网络连接”。
- 这种设计确保了数据的纯净性，并允许用户在下次进入页面时自动或手动触发重试。

## 🛠️ Developer Workflows

### Mobile
- **Run**: `cd mobile && flutter run`
- **Code Generation**: `cd mobile && flutter pub run build_runner build --delete-conflicting-outputs` (Run this after changing Isar models or Mockito mocks).
- **Tests**: `flutter test` (Unit), `flutter test integration_test` (Integration).

### Backend
- **Run**: `cd backend && ./mvnw spring-boot:run`

## 🧪 Testing Strategy
- **Unit Tests**: Mock Repositories to test Services.
- **Widget Tests**: Test UI components.
- **Integration Tests**: Test full flows.
