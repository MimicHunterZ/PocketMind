# PocketMind Copilot Instructions

你是 PocketMind 项目的专家级 AI 架构师。PocketMind 是一个"第二大脑"生态系统,包含 Flutter 移动端 和 Spring Boot 后端。

## 📚 文档体系

**本项目采用分层文档结构,详细规范已迁移到 `docs/` 目录**。

### 入口文档
- **[AGENTS.md](AGENTS.md)** - 知识图谱索引

### 详细文档
请根据具体任务查阅:
- 后端架构: [docs/architecture/backend/](docs/architecture/backend/)
- 移动端架构: [docs/architecture/mobile/](docs/architecture/mobile/)
- 开发工作流: [docs/workflows/](docs/workflows/)
- 编码规约: [docs/conventions/](docs/conventions/)

---

## 🚀 快速决策

### 后端开发

**需要访问数据库?**
- ✅ 注入 Repository (不是 Mapper)

**需要开启事务?**
- ✅ 多表操作 → `@Transactional`
- ❌ AI 调用/文件上传 → 禁止在事务内

**需要调用 AI?**
- ✅ 使用 `AIFailoverRouter`
- ✅ Prompt 外部化 (`prompts/{domain}/{scene}.st`)
- ✅ 使用 `PromptBuilder` 构建

**查询数据库?**
- ❌ 禁止 `SELECT *`
- ✅ 明确指定字段

### 移动端开发

**需要定义数据模型?**
- ✅ 状态/领域模型 → `@freezed`
- ❌ 禁止手动编写 `fromJson`/`toJson`
- ✅ 修改后执行: `flutter pub run build_runner watch --delete-conflicting-outputs`

**需要网络请求?**
- ✅ 通过 Riverpod Provider 注入 Service
- ❌ 禁止 UI 层直接调用 Dio

**需要本地存储?**
- ✅ 使用 Isar
- ✅ 写操作封装在 `writeTxn`
- ✅ UI 订阅 `watch()` 流

**需要 UI 组件?**
- ✅ 查看 `lib/page/widget/` 是否已有封装
- ✅ 从 `theme_data.dart` 获取设计元素
- ❌ 禁止硬编码颜色/字体

---

## 📝 通用规约

### 注释
- ✅ 必须使用中文
- ❌ 禁止 `phase xxx`、`适合 DAY1` 等 AI 生成痕迹

### Git 提交
```bash
feat: 新增xxx       # 新功能
fix: 修复xxx        # Bug 修复
refine: 优化xxx     # 代码优化/重构
doc: 更新xxx        # 文档更新
```

---

## 🛠️ 常用命令

### 移动端
```bash
# 运行
cd mobile && flutter run

# 代码生成
flutter pub run build_runner watch --delete-conflicting-outputs

# 测试
flutter test
```

### 后端
```bash
# 运行
cd backend && ./mvnw spring-boot:run

# 测试
./mvnw test
```

---

**重要**: 本文档仅为快速参考,详细规范请查阅 `docs/` 目录。
