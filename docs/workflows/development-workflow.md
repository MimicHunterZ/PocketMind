# 开发工作流指南

## 概述

本文档定义 PocketMind 项目的标准开发流程、命令行工具使用和测试策略。

## 移动端工作流

### 环境要求

- **Flutter**: 3.24+
- **Dart**: 3.5+
- **IDE**: VS Code / Android Studio

### 常用命令

#### 运行应用

```bash
cd mobile
flutter run
```

可选参数:
```bash
# 指定设备
flutter run -d chrome
flutter run -d <device-id>

# 指定模式
flutter run --debug
flutter run --profile
flutter run --release
```

#### 代码生成

**触发场景**:
- 修改 Isar 模型
- 修改 @freezed 类
- 修改 @JsonSerializable 类
- 添加/修改 Riverpod Provider

**执行命令**:
```bash
cd mobile
flutter pub run build_runner watch --delete-conflicting-outputs
```

**一次性构建** (不监听文件变化):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 测试

##### 单元测试
```bash
flutter test
```

测试特定文件:
```bash
flutter test test/services/note_service_test.dart
```

##### Widget 测试
```bash
flutter test test/widgets/
```

##### 集成测试
```bash
flutter test integration_test
```

在真机上运行集成测试:
```bash
flutter test integration_test -d <device-id>
```

#### 依赖管理

```bash
# 安装依赖
flutter pub get

# 升级依赖
flutter pub upgrade

# 清理缓存
flutter clean
flutter pub get
```

#### 代码质量

```bash
# 代码分析
flutter analyze

# 代码格式化
dart format lib test

# 检查未使用的文件
flutter pub run dart_code_metrics:metrics check-unused-files lib
```

### 开发流程

1. **创建功能分支**
   ```bash
   git checkout -b feature/xxx
   ```

2. **编写代码**
   - 修改代码
   - 触发代码生成 (如果需要)
   - 运行应用验证

3. **运行测试**
   ```bash
   flutter test
   ```

4. **提交代码**
   ```bash
   git add .
   git commit -m "feat: 新增xxx功能"
   ```

5. **推送并创建 PR**
   ```bash
   git push origin feature/xxx
   ```

## 后端工作流

### 环境要求

- **JDK**: 21+
- **Maven**: 3.8+
- **IDE**: IntelliJ IDEA / VS Code

### 常用命令

#### 运行应用

```bash
cd backend
./mvnw spring-boot:run
```

Windows:
```bash
.\mvnw.cmd spring-boot:run
```

指定 Profile:
```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

#### 测试

```bash
# 运行所有测试
./mvnw test

# 运行特定测试类
./mvnw test -Dtest=NoteServiceTest

# 运行特定测试方法
./mvnw test -Dtest=NoteServiceTest#shouldCreateNote
```

#### 构建

```bash
# 编译
./mvnw compile

# 打包
./mvnw package

# 跳过测试打包
./mvnw package -DskipTests
```

#### 依赖管理

```bash
# 查看依赖树
./mvnw dependency:tree

# 更新依赖
./mvnw versions:display-dependency-updates
```

#### 代码质量

```bash
# 代码格式化 (使用 Spotless)
./mvnw spotless:apply

# 检查代码风格
./mvnw spotless:check

# 静态代码分析
./mvnw checkstyle:check
```

### 开发流程

1. **创建功能分支**
   ```bash
   git checkout -b feature/xxx
   ```

2. **编写代码**
   - 编写业务逻辑
   - 编写单元测试
   - 本地运行验证

3. **运行测试**
   ```bash
   ./mvnw test
   ```

4. **确保编译成功**
   ```bash
   ./mvnw compile
   ```

5. **提交代码**
   ```bash
   git add .
   git commit -m "feat: 新增xxx功能"
   ```

## Git 提交规范

### Commit Message 格式

```
<type>: <subject>

[optional body]
```

### Type 类型

| Type | 说明 |
| :--- | :--- |
| `feat` | 新增功能 |
| `fix` | 修复 Bug |
| `refine` | 代码优化/重构 |
| `doc` | 文档更新 |
| `test` | 测试相关 |
| `chore` | 构建/工具链相关 |
| `style` | 代码格式调整 (不影响逻辑) |

### 示例

```bash
# 新增功能
git commit -m "feat: 新增笔记分享功能"

# 修复 Bug
git commit -m "fix: 修复笔记保存失败的问题"

# 代码优化
git commit -m "refine: 优化笔记列表渲染性能"

# 文档更新
git commit -m "doc: 更新架构文档"
```

### 禁止项

**不要出现以下内容**:
- ❌ `phase 1`, `phase 2`, `phase xxx`
- ❌ `适合 DAY1`, `适合第一天`
- ❌ 其他 AI 生成痕迹的表述

## 测试策略

### 后端测试

#### 单元测试

**目标**: 测试 Service 层业务逻辑

**策略**: Mock Repositories

```java
@ExtendWith(MockitoExtension.class)
class NoteServiceTest {
    
    @Mock
    private NoteRepository noteRepository;
    
    @InjectMocks
    private NoteServiceImpl noteService;
    
    @Test
    void shouldCreateNote() {
        // Given
        NoteCreateDTO dto = new NoteCreateDTO("标题", "内容");
        Note note = Note.builder()
            .id(1L)
            .title("标题")
            .content("内容")
            .build();
        
        when(noteRepository.save(any(Note.class))).thenReturn(note);
        
        // When
        NoteVO result = noteService.createNote(dto);
        
        // Then
        assertThat(result.getTitle()).isEqualTo("标题");
        verify(noteRepository).save(any(Note.class));
    }
}
```

#### 集成测试

**目标**: 测试完整的 API 流程

```java
@SpringBootTest
@AutoConfigureMockMvc
class NoteControllerIntegrationTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    void shouldCreateNoteViaAPI() throws Exception {
        String json = """
            {
                "title": "测试笔记",
                "content": "测试内容"
            }
            """;
        
        mockMvc.perform(post("/api/notes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.title").value("测试笔记"));
    }
}
```

### 移动端测试

#### 单元测试

**目标**: 测试业务逻辑、工具类

```dart
void main() {
  group('NoteService', () {
    late MockApiService mockApiService;
    late NoteService noteService;
    
    setUp(() {
      mockApiService = MockApiService();
      noteService = NoteService(mockApiService);
    });
    
    test('should fetch notes successfully', () async {
      // Given
      when(mockApiService.getNotes()).thenAnswer(
        (_) async => [Note(id: '1', title: '测试', content: '内容')]
      );
      
      // When
      final notes = await noteService.fetchNotes();
      
      // Then
      expect(notes.length, 1);
      expect(notes.first.title, '测试');
    });
  });
}
```

#### Widget 测试

**目标**: 测试 UI 组件

```dart
void main() {
  testWidgets('NoteCard should display title', (tester) async {
    // Given
    final note = Note(id: '1', title: '测试标题', content: '内容');
    
    // When
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(note: note),
        ),
      ),
    );
    
    // Then
    expect(find.text('测试标题'), findsOneWidget);
  });
}
```

#### 集成测试

**目标**: 测试完整的用户流程

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('should create and display note', (tester) async {
    await tester.pumpWidget(MyApp());
    
    // 点击创建按钮
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    
    // 输入标题和内容
    await tester.enterText(find.byType(AppTextField).first, '新笔记');
    await tester.enterText(find.byType(AppTextField).last, '笔记内容');
    
    // 保存
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    
    // 验证
    expect(find.text('新笔记'), findsOneWidget);
  });
}
```

## 持续集成 (CI)

### GitHub Actions 工作流

#### 后端 CI

```yaml
name: Backend CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '21'
      - name: Run tests
        run: |
          cd backend
          ./mvnw test
```

#### 移动端 CI

```yaml
name: Mobile CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - name: Run tests
        run: |
          cd mobile
          flutter pub get
          flutter test
```

## 相关文档

- [后端架构规范](../architecture/backend/layered-architecture.md)
- [移动端架构规范](../architecture/mobile/flutter-architecture.md)
- [编码规约](../conventions/coding-standards.md)
