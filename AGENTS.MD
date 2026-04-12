# PocketMind 开发知识图谱

## 项目概述

PocketMind 是一个"第二大脑"生态系统,包含 **Flutter 移动端** 和 **Spring Boot 后端**。

**本文档是知识图谱索引**,指向详细的技术文档。开发前请阅读相关规范。

---

## 📚 架构规范

### 后端架构

| 文档 | 说明 |
| :--- | :--- |
| [分层架构](docs/architecture/backend/layered-architecture.md) | Controller/Service/Repository/Mapper 职责划分 |
| [DDD 架构](docs/architecture/backend/ddd-architecture.md) | 领域驱动设计,聚合根/值对象/领域服务 |
| [AI 集成](docs/architecture/backend/ai-integration.md) | Prompt 工程/SSE 流式传输/故障转移 |

### 移动端架构

| 文档 | 说明 |
| :--- | :--- |
| [Flutter 架构](docs/architecture/mobile/flutter-architecture.md) | 主题系统/状态管理/网络层/本地存储 |

---

## 🛠️ 开发工作流

| 文档 | 说明 |
| :--- | :--- |
| [开发流程](docs/workflows/development-workflow.md) | 常用命令/测试策略/CI 配置 |

---

## 📝 编码规约

| 文档 | 说明 |
| :--- | :--- |
| [后端规约](docs/conventions/backend-coding-standards.md) | 命名规范/注释规范/代码风格 |
| [移动端规约](docs/conventions/mobile-coding-standards.md) | 命名规范/注释规范/Widget 构建 |

---

## 🔗 技术栈

### 后端
- Spring Boot 4.x + JDK 21
- MyBatis-Plus (文档: Context7 MCP)
- Spring AI

### 移动端
- Flutter 3.24+ / Dart 3.5+
- Riverpod 3.0 (文档: Context7 MCP)
- Isar

---

## 📖 其他资源

- [AI 相关文档](docs/ai/)
- [UI 设计文档](docs/a2ui/)

---

**注**: 详细规范请查阅对应的技术文档。
