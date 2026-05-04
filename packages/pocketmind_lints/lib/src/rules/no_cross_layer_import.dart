import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止 UI 层（`lib/page/`）直接导入底层实现模块（`lib/api/`、`lib/data/`）。
///
/// UI 层必须通过 Riverpod Provider 或 Service 层访问数据，
/// 不得绕过分层架构直接依赖网络或持久化实现。
///
/// **触发场景**
///
/// 在 `lib/page/` 下的文件中出现：
/// ```dart
/// import 'package:pocketmind/api/...';   // ❌ UI 层直接导入网络请求层
/// import 'package:pocketmind/data/...';  // ❌ UI 层直接导入数据仓储层
/// ```
///
/// **正确做法**
/// ```dart
/// import 'package:pocketmind/providers/...';  // ✅ 通过 Provider 访问
/// import 'package:pocketmind/service/...';    // ✅ 通过 Service 访问（如必要）
/// ```
class NoCrossLayerImport extends DartLintRule {
  const NoCrossLayerImport() : super(code: _code);

  static const _code = LintCode(
    name: 'no_cross_layer_import',
    problemMessage: 'UI 层（page/）禁止直接导入 {0} 层，请通过 providers/ 或 service/ 访问。',
    correctionMessage:
        '将业务逻辑封装到 Riverpod Provider（lib/providers/）或 Service（lib/service/）中，'
        'UI 层只依赖 Provider 获取数据。',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// 哪些层的文件受到约束（不允许导入 _forbiddenLayers）
  static const _constrainedLayer = 'lib/page/';

  /// UI 层禁止直接导入的底层模块
  static const _forbiddenLayers = [
    'lib/api/',
    'lib/data/',
  ];

  /// 违规导入对应的友好名称（用于错误消息）
  static const _layerNames = {
    'lib/api/': 'api（网络请求）',
    'lib/data/': 'data（本地数据仓储）',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // 仅对 UI 层文件执行检查
    if (!filePath.contains(_constrainedLayer)) return;

    context.registry.addImportDirective((node) {
      final importUri = node.uri.stringValue;
      if (importUri == null) return;

      for (final forbidden in _forbiddenLayers) {
        // 检测 package: 形式，如 package:pocketmind/api/...
        // 或相对路径，如 ../../api/...（通过包含 /api/ 片段检测）
        if (_isForbiddenImport(importUri, forbidden)) {
          final layerName = _layerNames[forbidden] ?? forbidden;
          reporter.atNode(node, code, arguments: [layerName]);
          return; // 每个 import 只上报一次
        }
      }
    });
  }

  /// 判断 import URI 是否属于被禁止的层
  static bool _isForbiddenImport(String importUri, String forbiddenLayer) {
    // package: 形式：package:pocketmind/api/xxx.dart
    // 提取包名后的路径部分进行匹配
    if (importUri.startsWith('package:')) {
      final withoutScheme = importUri.substring('package:'.length);
      final slashIndex = withoutScheme.indexOf('/');
      if (slashIndex < 0) return false;
      final pathInPackage = withoutScheme.substring(slashIndex + 1);
      // forbiddenLayer 如 'lib/api/'，去掉 'lib/' 前缀得到 'api/'
      final layerDir = forbiddenLayer.startsWith('lib/')
          ? forbiddenLayer.substring('lib/'.length)
          : forbiddenLayer;
      return pathInPackage.startsWith(layerDir);
    }

    // 相对路径形式（较少见，但也涵盖）
    return importUri.contains('/${ forbiddenLayer.replaceAll('lib/', '')}') ||
        importUri.startsWith(forbiddenLayer.replaceAll('lib/', ''));
  }
}
