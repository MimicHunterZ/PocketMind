import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// AI 消息 Markdown 渲染组件。
///
/// 支持两种渲染模式：
/// - [isStreaming] = false（默认）：完整渲染，启用文本选中。
/// - [isStreaming] = true：流式渲染，禁用选中以减少重绘开销；同时通过
///   [_sanitize] 补全未闭合的代码围栏，避免解析器把后续文本误判为代码块内容
///   堆叠在一起（这是业界主流做法，如 OpenAI ChatGPT Web、Claude Web 均
///   采用类似的 "close open fences" 策略）。
///
/// 两种状态对应的 Widget 使用不同 [ValueKey]，在流式结束后会触发一次
/// 完整重建，清除残余的 selection 层，解决 MarkdownBody 在高频更新时
/// 可能出现的布局残影问题。
///
/// 可在任意页面复用，只需提供 [data] 和可选的 [baseStyle]。
class MarkdownText extends StatelessWidget {
  /// Markdown 文本内容。
  final String data;

  /// 基础文字颜色 / 字号，未传时使用 [ColorScheme.onSurface] 和 15.sp。
  final TextStyle? baseStyle;

  /// 是否处于流式接收状态。
  final bool isStreaming;

  const MarkdownText({
    super.key,
    required this.data,
    this.baseStyle,
    this.isStreaming = false,
  });

  
  // 流式内容预处理（关闭未完成的 Markdown 语法块）
  

  /// 修复流式传输时不完整的 Markdown 语法。
  ///
  /// 当前处理规则：
  /// 1. 代码围栏（triple-backtick）奇数个时，追加关闭围栏，避免后续内容
  ///    被解析器当作代码块正文无换行地堆叠在一起。
  ///
  /// 可按需扩展更多规则（如行内代码、blockquote 等）。
  static String _sanitize(String content) {
    final fenceCount = '```'.allMatches(content).length;
    if (fenceCount.isOdd) {
      return '$content\n```';
    }
    return content;
  }

  
  // Build
  

  @override
  Widget build(BuildContext context) {
    final rendered = isStreaming ? _sanitize(data) : data;

    final base = baseStyle ?? const TextStyle();
    final c = base.color ?? Theme.of(context).colorScheme.onSurface;
    final fontSize = base.fontSize ?? 15.sp;

    return MarkdownBody(
      // streaming ↔ final 状态切换时强制重建 Widget 树，
      // 清除 flutter_markdown 内部残留的 SelectionOverlay，
      // 避免高频更新时出现文字"叠在一起"的布局残影。
      key: ValueKey(isStreaming),
      data: rendered,
      // 流式阶段关闭文本选中：SelectionArea 内的 hit-test
      // 会在高频重建时产生额外 repaint，关闭后渲染更流畅。
      selectable: !isStreaming,
      softLineBreak: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: fontSize, height: 1.6, color: c),
        h1: TextStyle(
          fontSize: fontSize * 1.33,
          fontWeight: FontWeight.bold,
          color: c,
        ),
        h2: TextStyle(
          fontSize: fontSize * 1.2,
          fontWeight: FontWeight.bold,
          color: c,
        ),
        h3: TextStyle(
          fontSize: fontSize * 1.07,
          fontWeight: FontWeight.bold,
          color: c,
        ),
        strong: TextStyle(fontWeight: FontWeight.bold, color: c),
        em: TextStyle(fontStyle: FontStyle.italic, color: c),
        del: TextStyle(
          decoration: TextDecoration.lineThrough,
          color: c.withValues(alpha: 0.7),
        ),
        code: TextStyle(
          fontSize: fontSize * 0.87,
          fontFamily: 'monospace',
          color: c,
          backgroundColor: Colors.black.withValues(alpha: 0.08),
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6.r),
        ),
        codeblockPadding: EdgeInsets.all(10.r),
        blockquote: TextStyle(
          fontSize: fontSize * 0.93,
          color: c.withValues(alpha: 0.75),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.withValues(alpha: 0.35), width: 3),
          ),
        ),
        blockquotePadding: EdgeInsets.only(left: 12.w),
        listBullet: TextStyle(fontSize: fontSize, color: c),
        tableBody: TextStyle(fontSize: fontSize * 0.93, color: c),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.withValues(alpha: 0.2), width: 1),
          ),
        ),
      ),
    );
  }
}
