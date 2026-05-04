import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止在业务代码中硬编码颜色值。
///
/// 所有颜色必须从主题系统获取（`context.colorScheme`、`context.appColors` 等），
/// 定义于 `lib/util/theme_data.dart` 的 `ThemeContextExt` 扩展。
///
/// **触发场景**
///
/// 1. 直接构造颜色值：
/// ```dart
/// Color(0xFF3A3A35)          // ❌
/// Color.fromARGB(255, 58, 58, 53)  // ❌
/// Color.fromRGBO(58, 58, 53, 1.0)  // ❌
/// ```
///
/// 2. 使用 Material 色板（有语义的颜色请用主题，无语义的透明/纯黑白见下方例外）：
/// ```dart
/// Colors.red                 // ❌
/// Colors.blue.shade700       // ❌
/// Colors.green.shade100      // ❌
/// ```
///
/// **允许的例外**（不触发规则）
/// - `Colors.transparent` — 透明无语义颜色
/// - 主题定义文件 `lib/util/theme_data.dart` 内部
///
/// **正确做法**
/// ```dart
/// context.colorScheme.primary        // ✅
/// context.colorScheme.error          // ✅  替代 Colors.red
/// context.appColors.accentColor      // ✅
/// context.categoryHomeColors.xxx     // ✅
/// ```
class NoHardcodedColors extends DartLintRule {
  const NoHardcodedColors() : super(code: _code);

  static const _code = LintCode(
    name: 'no_hardcoded_colors',
    problemMessage: '禁止硬编码颜色值，请从主题获取（context.colorScheme、context.appColors 等）。',
    correctionMessage:
        '使用 ThemeContextExt 提供的属性：context.colorScheme.primary、'
        'context.appColors.accentColor、context.colorScheme.error 等。'
        '详见 lib/util/theme_data.dart。',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// 排除的文件路径片段：这些文件内部允许直接操作颜色值
  static const _allowedPathFragments = [
    'lib/util/theme_data.dart', // ThemeContextExt 和主题色定义本身
  ];

  /// 允许使用的 Colors 成员（语义明确且无对应主题色的情况）
  static const _allowedColorsMembers = {
    'transparent', // 透明
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;
    if (_allowedPathFragments.any((p) => filePath.endsWith(p))) return;

    context.registry.addInstanceCreationExpression((node) {
      if (_isHardcodedColorConstructor(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addPrefixedIdentifier((node) {
      // 仅在父节点不是 PropertyAccess 时上报，避免 Colors.red.shade100 重复上报：
      // - Colors.red 作为 PropertyAccess 的 target 时，由 addPropertyAccess 处理
      // - Colors.red 单独使用时，由此处处理
      if (node.parent is PropertyAccess) return;
      if (_isForbiddenColorsMember(node)) {
        reporter.atNode(node, code);
      }
    });

    // 检测 Colors.red.shade700 这类属性链（PropertyAccess），上报整个链
    context.registry.addPropertyAccess((node) {
      if (_isForbiddenColorsPropertyAccess(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 检测：Color(0xFF...) / Color.fromARGB(...) / Color.fromRGBO(...)
  // ---------------------------------------------------------------------------

  static bool _isHardcodedColorConstructor(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    if (typeName != 'Color') return false;

    // Color(0xFF...) — 默认构造
    final constructorName = node.constructorName.name?.name;
    if (constructorName == null) return true; // Color(value) 形式

    // Color.fromARGB / Color.fromRGBO
    return constructorName == 'fromARGB' || constructorName == 'fromRGBO';
  }

  // ---------------------------------------------------------------------------
  // 检测：Colors.red、Colors.blue 等（PrefixedIdentifier）
  //   PrefixedIdentifier = "Colors" + "." + "red"
  //   这种形式是直接使用，如 color: Colors.green
  // ---------------------------------------------------------------------------

  static bool _isForbiddenColorsMember(PrefixedIdentifier node) {
    if (node.prefix.name != 'Colors') return false;
    final member = node.identifier.name;
    return !_allowedColorsMembers.contains(member);
  }

  // ---------------------------------------------------------------------------
  // 检测：Colors.red.shade700 等链式访问（PropertyAccess）
  //   PropertyAccess target = Colors.red（PrefixedIdentifier）
  //                property = shade700
  // ---------------------------------------------------------------------------

  static bool _isForbiddenColorsPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is! PrefixedIdentifier) return false;
    if (target.prefix.name != 'Colors') return false;
    final member = target.identifier.name;
    // 如果根节点已经被 _isForbiddenColorsMember 处理，这里只处理 .shadeXXX 链
    // 但为了避免重复上报，只在 target 本身是不允许的成员时上报整个链
    return !_allowedColorsMembers.contains(member);
  }
}
