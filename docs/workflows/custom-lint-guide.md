# 自定义 Lint 规则指南

## 概述

PocketMind 使用 `custom_lint` 将编码规范自动化为 lint 错误，让 IDE、`dart analyze` 和 CI 均能强制执行，无需依赖人工代码审查。

规则定义在独立包 `packages/pocketmind_lints/` 中。

---

## 当前规则

| 规则名 | 级别 | 说明 |
| :--- | :--- | :--- |
| `no_theme_of_context` | ERROR | 禁止直接调用 `Theme.of(context)`，必须使用 `ThemeContextExt` 扩展 |
| `no_hardcoded_colors` | ERROR | 禁止硬编码颜色值（`Color(0x...)`、`Colors.red` 等），必须从主题获取 |
| `no_cross_layer_import` | ERROR | 禁止 UI 层（`lib/page/`）直接导入 `lib/api/` 或 `lib/data/`，必须通过 `providers/` 或 `service/` 访问 |

---

## 使用方式

### 检查违规

```bash
cd mobile
dart run custom_lint
```

### 自动修复

```bash
dart run custom_lint --fix
```

### 查看所有分析错误（CI 使用）

```bash
flutter analyze
```

---

## 首次配置常见问题

### analyzer 版本冲突

**现象**：`flutter pub get` 报依赖解析失败：

```
Because no versions of isar_community_generator match >3.3.2 <4.0.0
and isar_community_generator 3.3.2 depends on analyzer >=8.0.0 <11.0.0,
...is incompatible with pocketmind_lints from path.
```

**原因**：`pocketmind_lints/pubspec.yaml` 中 `analyzer` 版本范围与主项目其他依赖（如 `isar_community_generator`）要求的版本不兼容。

**解决方法**：在 `packages/pocketmind_lints/pubspec.yaml` 中将 `analyzer` 约束放宽以覆盖主项目所需的最低版本：

```yaml
dependencies:
  custom_lint_builder: ^0.8.0
  analyzer: ">=8.0.0 <12.0.0"   # 需覆盖 isar_community_generator 所需的 >=8.0.0
```

同时确保 `mobile/pubspec.yaml` 中的 `custom_lint` 版本与 `custom_lint_builder` 大版本一致：

```yaml
dev_dependencies:
  custom_lint: ^0.8.0   # 与 pocketmind_lints 中的 custom_lint_builder 主版本一致
```

**规律**：每当 `pocketmind_lints` 中的 `custom_lint_builder` 大版本升级时，`mobile` 中的 `custom_lint` 也需同步更新。

---

### IDE 未显示错误

`flutter pub get` 后需要重启 Dart 分析服务器才能生效：

- **VS Code**：`Cmd+Shift+P` → `Dart: Restart Analysis Server`
- **Android Studio**：`File` → `Invalidate Caches / Restart`

---

## 扩展：新增 lint 规则

1. 在 `packages/pocketmind_lints/lib/src/rules/` 下新建规则文件
2. 在 `packages/pocketmind_lints/lib/pocketmind_lints.dart` 的 `getLintRules` 中追加
3. 在 `mobile/analysis_options.yaml` 的 `custom_lint.rules` 中启用

```dart
// pocketmind_lints.dart
@override
List<LintRule> getLintRules(CustomLintConfigs configs) => [
  const NoThemeOfContext(),
  const NoHardcodedColors(),
  const NoCrossLayerImport(),  // 追加新规则
];
```

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - no_theme_of_context
    - no_hardcoded_colors       # 启用新规则
```

---

## 临时豁免

极少数场景需要绕过规则时：

```dart
// 单行豁免
Theme.of(context); // ignore: no_theme_of_context

// 整个文件豁免（不推荐）
// ignore_for_file: no_theme_of_context
```

---

## 相关文档

- [移动端编码规约](../conventions/mobile-coding-standards.md)
- [规则源码](../../packages/pocketmind_lints/lib/src/rules/)
