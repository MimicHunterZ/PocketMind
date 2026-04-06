import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/router/route_paths.dart';

/// 全局 AI 入口页：解析全局会话并重定向到聊天页
class GlobalAiEntryPage extends ConsumerStatefulWidget {
  const GlobalAiEntryPage({super.key});

  @override
  ConsumerState<GlobalAiEntryPage> createState() => _GlobalAiEntryPageState();
}

class _GlobalAiEntryPageState extends ConsumerState<GlobalAiEntryPage> {
  bool _navigated = false;
  bool _loading = true;
  bool _inFlight = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigated) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectToGlobalSession();
    });
  }

  Future<void> _redirectToGlobalSession() async {
    if (_inFlight) return;
    _inFlight = true;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(chatSessionRepositoryProvider);
      final service = ref.read(chatServiceProvider);
      final globalSessions = await repo.findGlobalSessions();
      final sessionUuid = globalSessions.isNotEmpty
          ? globalSessions.first.uuid
          : (await service.createSession(noteUuid: null)).uuid;

      if (!mounted) return;
      context.pushReplacement(RoutePaths.chatOf(sessionUuid));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '加载全局会话失败';
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage ?? '加载全局会话失败'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _inFlight ? null : _redirectToGlobalSession,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
