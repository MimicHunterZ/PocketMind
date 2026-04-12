import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/router/route_paths.dart';

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
            subtitle: '真实 A2UI SSE 流与 Surface 渲染联动',
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
    final theme = Theme.of(context);
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
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
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
