import 'package:flutter/material.dart';
import 'package:pocketmind/page/widget/desktop/desktop_sidebar.dart';
import 'package:pocketmind/util/responsive_breakpoints.dart';

/// 全局主布局组件
/// 负责根据平台实现响应式布局：
/// - 桌面端：固定侧边栏 + 动态内容区
/// - 移动端：全屏内容区
class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 根据可用宽度判断是否显示侧边栏，避免测试与小窗下强制桌面布局
    final width = MediaQuery.of(context).size.width;
    final bool isDesktopLayout =
        ResponsiveBreakpoints.shouldShowHomeSidebar(width);

    if (isDesktopLayout) {
      return Scaffold(
        body: Row(
          children: [
            // 桌面端侧边栏
            const DesktopSidebar(),

            // 分隔线
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),

            // 动态内容区域 (由路由驱动)
            Expanded(child: child),
          ],
        ),
      );
    }

    // 移动端布局：直接返回 child，由各页面自行管理 Scaffold
    return child;
  }
}
