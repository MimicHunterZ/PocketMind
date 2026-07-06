import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'package:pocketmind/util/theme_data.dart';

class GenUiDemoHubPage extends StatelessWidget {
  const GenUiDemoHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A2UI / Markdown Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoEntryCard(
            title: 'A2UI Stream Demo',
            subtitle: 'AG-UI 事件流(mock)驱动 A2UI Surface 渲染',
            icon: Icons.auto_awesome,
            onTap: () => context.push(RoutePaths.genuiDemoA2ui),
          ),
          const SizedBox(height: 12),
          _DemoEntryCard(
            title: 'Markdown SSE Mock Demo',
            subtitle: '读取 mock/full.md 模拟 AI 流式回复',
            icon: Icons.article_outlined,
            onTap: () => context.push(RoutePaths.genuiDemoMarkdownSse),
          ),
          const SizedBox(height: 12),
          _DemoEntryCard(
            title: 'Surface 生命周期交接 spike',
            subtitle: '验证直播 controller 交接给持久化 controller 会不会闪烁/漏释放',
            icon: Icons.swap_horiz,
            onTap: () => context.push(RoutePaths.genuiDemoSurfaceHandoff),
          ),
          const SizedBox(height: 12),
          _DemoEntryCard(
            title: '聊天块序列 Mock 预览',
            subtitle: '真实 ChatPage + 文本/工具卡片/A2UI 卡片混排的固定 mock 数据',
            icon: Icons.view_agenda_outlined,
            onTap: () => context.push(RoutePaths.genuiDemoChatBlockSequence),
          ),
        ],
      ),
    );
  }
}

class _DemoEntryCard extends StatelessWidget {
  const _DemoEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
