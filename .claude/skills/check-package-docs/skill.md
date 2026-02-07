---
name: check-package-docs
description: 查询第三方 Dart/Flutter 包的最新文档和 API 使用方法
version: 1.0.0
---
# 查询第三方包文档

当遇到第三方 Dart/Flutter 包的使用问题时，请按以下步骤操作：

## 步骤

1. **识别问题包和版本**
   - 从错误信息中识别出问题包的名称
   - 检查 `pubspec.yaml` 中该包的版本号
   - 注意是否使用了预发布版本（如 `^3.0.0-0.0.dev`）

2. **使用 context7 MCP 查询文档**
   - 查询格式：`[包名] [版本号] [关键词]`
   - 关键词示例：
     - `migration guide` - 查询迁移指南
     - `breaking changes` - 查询破坏性变更
     - `api reference` - 查询 API 参考
     - `example` - 查询示例代码

3. **重点关注的文档内容**
   - **Breaking Changes**: 版本间的不兼容变更
   - **Migration Guide**: 官方迁移指南
   - **API Changes**: 新增、废弃或修改的 API
   - **Example Code**: 官方示例代码

4. **应用文档中的解决方案**
   - 根据文档更新代码
   - 运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成代码
   - 运行 `flutter analyze` 验证修复

## 常见场景

### Freezed 3.0 迁移
```
问题：编译错误 "Missing concrete implementations"
查询：freezed 3.0 migration guide
解决：添加 abstract 或 sealed 关键字到类定义
```

### Riverpod 版本升级
```
问题：Provider 代码生成失败
查询：riverpod_annotation breaking changes
解决：更新注解用法和 Provider 定义
```

### Isar 版本兼容
```
问题：Schema 生成失败
查询：isar_community migration
解决：更新 @collection 注解和字段定义
```

## 重要原则

1. **永远不要依赖过时的记忆** - 包的 API 在新版本中可能完全改变
2. **优先查询官方文档** - 使用 context7 MCP 获取最新信息
3. **验证版本一致性** - 确保文档版本与 pubspec.yaml 一致
4. **参考官方示例** - 官方示例代码是最佳实践

## 输出格式

完成查询后，请提供：
1. 问题的根本原因
2. 官方文档中的解决方案
3. 需要修改的具体代码
4. 验证步骤
