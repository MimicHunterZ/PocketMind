// 插件入口 —— custom_lint_builder 要求此函数名必须是 createPlugin
// ignore_for_file: implementation_imports

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/no_cross_layer_import.dart';
import 'src/rules/no_hardcoded_colors.dart';
import 'src/rules/no_theme_of_context.dart';

/// custom_lint 插件入口，列出所有自定义规则
PluginBase createPlugin() => _PocketMindLintPlugin();

class _PocketMindLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        // 禁止直接调用 Theme.of(context)
        const NoThemeOfContext(),
        // 禁止硬编码颜色值
        const NoHardcodedColors(),
        // 禁止 UI 层跨层导入底层模块
        const NoCrossLayerImport(),
      ];
}

