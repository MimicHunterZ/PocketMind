import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止在 Widget 中直接调用 `Theme.of(context)`。
///
/// 必须通过 `ThemeContextExt` 扩展方法访问主题：
///   - `context.theme`         — 完整 ThemeData
///   - `context.colorScheme`   — Material 3 颜色方案
///   - `context.textTheme`     — 文字样式集
///   - `context.isDark`        — 是否暗色模式
///   - `context.appColors`     — 全局扩展颜色
///
/// **错误示例**
/// ```dart
/// final theme = Theme.of(context);           // ❌
/// final cs = Theme.of(context).colorScheme;  // ❌
/// ```
///
/// **正确示例**
/// ```dart
/// final theme = context.theme;               // ✅
/// final cs = context.colorScheme;            // ✅
/// ```
class NoThemeOfContext extends DartLintRule {
  const NoThemeOfContext() : super(code: _code);

  // ---------------------------------------------------------------------------
  // LintCode 定义
  // DiagnosticSeverity.ERROR  → 在 IDE 和 dart analyze 中显示为错误（红色）
  // ---------------------------------------------------------------------------
  static const _code = LintCode(
    name: 'no_theme_of_context',
    problemMessage:
        '禁止直接调用 Theme.of(context)，请使用 context.theme（来自 ThemeContextExt）。',
    correctionMessage:
        '将 Theme.of(context) 替换为对应的扩展属性，例如 context.theme、'
        'context.colorScheme、context.textTheme、context.isDark、context.appColors 等。',
    // ERROR 级别：dart analyze 退出码非零，CI 可感知
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // ---------------------------------------------------------------------------
  // 需要排除的文件路径（定义 ThemeContextExt 的源文件本身）
  // 匹配规则：只要路径包含此子串就跳过
  // ---------------------------------------------------------------------------
  static const _allowedPaths = [
    'lib/util/theme_data.dart',
  ];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // ------------------------------------------------------------------
    // 快速路径：如果当前文件是 theme_data.dart 本身，跳过检测。
    // ThemeContextExt 的实现体内当然需要调用 Theme.of(this)。
    // ------------------------------------------------------------------
    final filePath = resolver.path;
    if (_allowedPaths.any((p) => filePath.endsWith(p))) return;

    // ------------------------------------------------------------------
    // 注册 AST 访问者：每次遇到方法调用节点时触发
    // ------------------------------------------------------------------
    context.registry.addMethodInvocation((node) {
      // 仅关注 Theme.of(...) 调用
      if (!_isThemeOf(node)) return;

      // 检查参数是否是 BuildContext（即 context 变量）
      // 注：此处做名称检查即可；精确类型检查见下方注释
      if (!_hasContextArgument(node)) return;

      // 上报错误，定位到整个方法调用节点
      reporter.atNode(node, code);
    });
  }

  // ---------------------------------------------------------------------------
  // 提供 IDE 快速修复（Quick Fix）
  // ---------------------------------------------------------------------------
  @override
  List<Fix> getFixes() => [_ReplaceWithContextThemeFix()];

  // ---------------------------------------------------------------------------
  // 内部工具方法
  // ---------------------------------------------------------------------------

  /// 判断是否是 `Theme.of(...)` 调用。
  ///
  /// AST 结构：
  ///   MethodInvocation
  ///     target: SimpleIdentifier  ("Theme")  或 PrefixedIdentifier
  ///     methodName: SimpleIdentifier ("of")
  static bool _isThemeOf(MethodInvocation node) {
    if (node.methodName.name != 'of') return false;

    final target = node.target;
    if (target == null) return false;

    // 直接写 Theme.of() → target 是 SimpleIdentifier
    if (target is SimpleIdentifier && target.name == 'Theme') return true;

    // 有时候带前缀 material.Theme.of() → target 是 PrefixedIdentifier
    if (target is PrefixedIdentifier && target.identifier.name == 'Theme') {
      return true;
    }

    return false;
  }

  /// 判断 `Theme.of(...)` 的第一个参数名称是否为 `context`。
  ///
  /// 只匹配变量名为 `context` 的情况（Flutter 中的惯例命名）。
  /// 如果项目中有人把 BuildContext 参数命名为其他名字（如 `ctx`），
  /// 此规则不会误报，可根据需要放宽匹配。
  static bool _hasContextArgument(MethodInvocation node) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    // 最常见的情况：直接传 context
    if (firstArg is SimpleIdentifier && firstArg.name == 'context') {
      return true;
    }
    // 偶尔会写 Theme.of(this)（在 BuildContext 扩展内），
    // 这种情况已被 _allowedPaths 过滤，此处不需要处理
    return false;
  }
}

// =============================================================================
// Quick Fix：将 Theme.of(context) 替换为 context.theme
// =============================================================================

class _ReplaceWithContextThemeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((node) {
      // 只修复与本次错误位置重叠的节点
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // ------------------------------------------------------------------
      // 智能替换策略：
      //   Theme.of(context)             → context.theme
      //   Theme.of(context).colorScheme → context.colorScheme
      //   Theme.of(context).textTheme   → context.textTheme
      //   Theme.of(context).brightness  → context.theme.brightness（通用回退）
      // ------------------------------------------------------------------
      final parent = node.parent;

      // 情况 A：Theme.of(context).someProperty（属性访问）
      if (parent is PropertyAccess) {
        final propertyName = parent.propertyName.name;
        final replacement = _resolveExtensionProperty(propertyName);

        final changeBuilder = reporter.createChangeBuilder(
          message: '替换为 $replacement',
          priority: 90,
        );

        changeBuilder.addDartFileEdit((builder) {
          // 替换整个 "Theme.of(context).xxx" 表达式
          builder.addSimpleReplacement(
            SourceRange(parent.offset, parent.length),
            replacement,
          );
        });

        // 同时提供"修复文件内所有此类问题"
        _addFixAll(reporter, context, others);
        return;
      }

      // 情况 A2：Theme.of(context).someProperty 可能解析为 MethodInvocation 的 target
      // 时 parent 是 PrefixedIdentifier 或 MethodInvocation —— 统一回退到 context.theme
      // 情况 B：单独使用 Theme.of(context)（赋值、传参等）
      final changeBuilder = reporter.createChangeBuilder(
        message: '替换为 context.theme',
        priority: 90,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          'context.theme',
        );
      });

      _addFixAll(reporter, context, others);
    });
  }

  /// 根据属性名决定使用哪个 ThemeContextExt 扩展属性
  static String _resolveExtensionProperty(String propertyName) {
    return switch (propertyName) {
      'colorScheme' => 'context.colorScheme',
      'textTheme' => 'context.textTheme',
      'brightness' => 'context.theme.brightness',
      'extension' => 'context.theme.extension', // 仍用 context.theme 访问
      _ => 'context.theme.$propertyName', // 通用回退：context.theme.xxx
    };
  }

  /// 批量修复：修复文件内所有相同错误
  void _addFixAll(
    ChangeReporter reporter,
    CustomLintContext context,
    List<AnalysisError> others,
  ) {
    if (others.isEmpty) return;

    context.registry.addMethodInvocation((otherNode) {
      for (final otherError in others) {
        if (!otherError.sourceRange.intersects(otherNode.sourceRange)) continue;

        final changeBuilder = reporter.createChangeBuilder(
          message: '修复此文件中所有 Theme.of(context) 调用',
          priority: 80,
        );

        changeBuilder.addDartFileEdit((builder) {
          final otherParent = otherNode.parent;
          if (otherParent is PropertyAccess) {
            builder.addSimpleReplacement(
              SourceRange(otherParent.offset, otherParent.length),
              _resolveExtensionProperty(otherParent.propertyName.name),
            );
          } else {
            builder.addSimpleReplacement(
              SourceRange(otherNode.offset, otherNode.length),
              'context.theme',
            );
          }
        });
      }
    });
  }
}
