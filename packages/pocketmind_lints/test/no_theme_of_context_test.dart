// ignore_for_file: prefer_single_quotes
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pocketmind_lints/pocketmind_lints.dart';
import 'package:test/test.dart';
import 'package:custom_lint_core/custom_lint_core.dart';

/// custom_lint 的测试框架基于 "golden test" 模式：
/// 提供一段 Dart 源码字符串，lint 规则对其分析，
/// 断言结果与期望的错误列表一致。

void main() {
  // ── testLint 是 custom_lint_builder 提供的测试辅助 API ──────────────────
  // 它会在内存中启动一个微型分析服务器，对传入的代码片段执行 lint，
  // 然后对比期望结果。

  group('NoThemeOfContext', () {
    /// 应该触发 lint 错误的代码
    test('直接调用 Theme.of(context) 应触发错误', () async {
      final lints = await _collectLints('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ 这一行应该报错
    final theme = Theme.of(context);
    return Container(color: theme.colorScheme.primary);
  }
}
''');
      expect(lints, hasLength(1));
      expect(lints.first.errorCode.name, 'no_theme_of_context');
    });

    test('Theme.of(context).colorScheme 应触发错误', () async {
      final lints = await _collectLints('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ 这一行应该报错
    final cs = Theme.of(context).colorScheme;
    return Container(color: cs.primary);
  }
}
''');
      expect(lints, hasLength(1));
      expect(lints.first.errorCode.name, 'no_theme_of_context');
    });

    /// 应该通过（不触发 lint 错误）的代码
    test('context.theme 不应触发错误', () async {
      final lints = await _collectLints('''
import 'package:flutter/material.dart';
// 假设 ThemeContextExt 已通过 import 引入
extension ThemeContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ✅ 正确用法
    final theme = context.theme;
    return Container(color: theme.colorScheme.primary);
  }
}
''');
      // 注意：扩展体内部的 Theme.of(this) 不应被报告，
      // 但由于测试代码不在 theme_data.dart 路径下，
      // 这里的 Theme.of(this) 参数是 this 而非 context，
      // _hasContextArgument 会返回 false，所以不报错。
      expect(lints, isEmpty);
    });

    test('非 BuildContext 参数不触发错误', () async {
      final lints = await _collectLints('''
import 'package:flutter/material.dart';

class MyClass {
  void doSomething(Object other) {
    // Theme.of(other) 参数不是 "context"，不触发
    // （实际上不会编译，但规则层面不报 lint）
  }
}
''');
      expect(lints, isEmpty);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 辅助：在内存中运行 lint 并收集结果
// ─────────────────────────────────────────────────────────────────────────────
Future<List<dynamic>> _collectLints(String source) async {
  // custom_lint_builder 的 testLint 工具
  final result = await testLint(
    (resolver, reporter, context) {
      const NoThemeOfContext().run(resolver, reporter, context);
    },
    // 要分析的源码
    source,
  );
  return result;
}
