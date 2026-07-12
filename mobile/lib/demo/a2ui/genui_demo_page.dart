import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart'
    show ActivitySnapshotEvent, BaseEvent, RunErrorEvent, RunFinishedEvent;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';
import 'package:pocketmind/demo/a2ui/a2ui_stream_api_service.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:uuid/uuid.dart';

class GenUiDemoPage extends ConsumerStatefulWidget {
  const GenUiDemoPage({super.key});

  @override
  ConsumerState<GenUiDemoPage> createState() => _GenUiDemoPageState();
}

class _GenUiDemoPageState extends ConsumerState<GenUiDemoPage> {
  final Uuid _uuid = const Uuid();

  late final SurfaceController _surfaceController;
  late final A2uiTransportAdapter _transportAdapter;

  final List<String> _surfaceIds = [];
  final List<String> _logs = [];

  CancelToken? _cancelToken;
  StreamSubscription<BaseEvent>? _streamSubscription;
  StreamSubscription<ChatMessage>? _onSubmitSubscription;

  String _requestId = '';
  bool _isStreaming = false;
  double _frameDelayMs = 320;
  String? _error;

  @override
  void initState() {
    super.initState();
    _surfaceController = SurfaceController(
      catalogs: [BasicCatalogItems.asCatalog()],
    );
    _transportAdapter = A2uiTransportAdapter();

    _transportAdapter.incomingMessages.listen(_surfaceController.handleMessage);

    _surfaceController.surfaceUpdates.listen((update) {
      if (!mounted) {
        return;
      }
      setState(() {
        switch (update) {
          case SurfaceAdded(:final surfaceId):
            if (!_surfaceIds.contains(surfaceId)) {
              _surfaceIds.add(surfaceId);
            }
          case SurfaceRemoved(:final surfaceId):
            _surfaceIds.remove(surfaceId);
          case ComponentsUpdated():
            break;
        }
      });
    });

    _onSubmitSubscription = _surfaceController.onSubmit.listen((message) {
      for (final part in message.parts) {
        final interaction = part.asUiInteractionPart;
        if (interaction != null) {
          _handleInteraction(interaction.interaction);
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _streamSubscription?.cancel();
    _onSubmitSubscription?.cancel();
    _surfaceController.dispose();
    _transportAdapter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GenUI Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'UI 展示'),
              Tab(text: '日志'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildUiTab(context), _buildLogTab(context)],
        ),
      ),
    );
  }

  Widget _buildUiTab(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _isStreaming ? _stopStream : _startStream,
                icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                label: Text(_isStreaming ? '停止流式' : '开始流式'),
              ),
              const SizedBox(width: 12),
              Text('${_frameDelayMs.round()}ms'),
              SizedBox(
                width: 160,
                child: Slider(
                  min: 80,
                  max: 1000,
                  divisions: 23,
                  value: _frameDelayMs,
                  label: '${_frameDelayMs.round()}ms',
                  onChanged: _isStreaming
                      ? null
                      : (value) => setState(() => _frameDelayMs = value),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_surfaceIds.isEmpty)
                Text(
                  '点击开始流式，查看 AI 如何流式讲解 Java 类加载机制，并通过选择卡片引导深入。',
                  style: context.textTheme.bodyMedium,
                ),
              for (final surfaceId in _surfaceIds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    surfaceContext: _surfaceController.contextFor(surfaceId),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogTab(BuildContext context) {
    if (_logs.isEmpty) {
      return Center(child: Text('暂无日志', style: context.textTheme.bodyMedium));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        return SelectableText(_logs[index]);
      },
    );
  }

  Future<void> _startStream() async {
    _cancelToken?.cancel();
    await _streamSubscription?.cancel();

    _cancelToken = CancelToken();
    _requestId = _uuid.v4();

    setState(() {
      _isStreaming = true;
      _error = null;
      _surfaceIds.clear();
      _logs.clear();
    });

    _log('stream start requestId=$_requestId');

    final api = ref.read(a2uiStreamApiServiceProvider);
    _consume(
      api.mockStream(
        requestId: _requestId,
        cancelToken: _cancelToken,
        delay: Duration(milliseconds: _frameDelayMs.round()),
      ),
    );
  }

  /// 消费一条 AG-UI 事件流(首轮或交互后的续推共用)。
  void _consume(Stream<BaseEvent> stream) {
    _streamSubscription = stream.listen((event) {
      if (!mounted) {
        return;
      }
      switch (event) {
        case ActivitySnapshotEvent(:final content):
          final data = jsonEncode(content);
          _transportAdapter.addChunk(data);
          _log(_describeFrame(data));
        case RunFinishedEvent():
          setState(() => _isStreaming = false);
          _log('stream done requestId=$_requestId');
        case RunErrorEvent(:final message):
          setState(() {
            _isStreaming = false;
            _error = message;
          });
          _log('stream error $message');
        case _:
          break;
      }
    });
  }

  void _stopStream() {
    _cancelToken?.cancel();
    setState(() => _isStreaming = false);
    _log('stream stopped requestId=$_requestId');
  }

  void _handleInteraction(String rawInteraction) {
    try {
      final decoded = jsonDecode(rawInteraction) as Map<String, dynamic>;
      final action = decoded['action'] as Map<String, dynamic>;
      final name = action['name'] as String? ?? 'unknown_action';
      final context = action['context'] as Map<String, dynamic>? ?? {};
      _log('action $name context=${jsonEncode(context)}');
      _respondToAction(name, context);
    } catch (e) {
      _log('action parse failed $e');
    }
  }

  Future<void> _respondToAction(
    String actionName,
    Map<String, dynamic> context,
  ) async {
    final surfaceId = _surfaceIds.isEmpty ? null : _surfaceIds.last;
    if (surfaceId == null) {
      return;
    }

    final api = ref.read(a2uiStreamApiServiceProvider);

    switch (actionName) {
      case 'deep_dive':
        // 用户选择深入方向 → 后端据选择续推第二段流式讲解。
        // mutuallyExclusive 的 ChoicePicker 把选中值写成数组(如 ["热修复原理"]),
        // 因此 topic 可能是 List 或 String,这里统一取首个非空值。
        final topic = _firstNonEmpty(context['topic']);
        if (topic == null) {
          _emitDataModel(surfaceId, '/status', '请先选择一个方向');
          return;
        }
        await _streamSubscription?.cancel();
        _cancelToken = CancelToken();
        setState(() => _isStreaming = true);
        _log('agent continue topic=$topic');
        _consume(
          api.continueWithTopic(
            surfaceId: surfaceId,
            topic: topic,
            cancelToken: _cancelToken,
            delay: Duration(milliseconds: _frameDelayMs.round()),
          ),
        );
      case 'mark_done':
        _emitDataModel(surfaceId, '/status', '✅ 已完成讲解');
        _log('marked done');
      default:
        _log('unhandled action $actionName');
    }
  }

  /// 从 event context 的值中取出首个非空字符串。
  ///
  /// 兼容两种形态:标量字符串,或 mutuallyExclusive ChoicePicker 写入的单元素数组。
  String? _firstNonEmpty(Object? raw) {
    if (raw is String) {
      final v = raw.trim();
      return v.isEmpty ? null : v;
    }
    if (raw is List) {
      for (final e in raw) {
        if (e is String && e.trim().isNotEmpty) {
          return e.trim();
        }
      }
    }
    return null;
  }

  /// 直接向数据模型写一帧(用于本地即时反馈,如状态文字)。
  void _emitDataModel(String surfaceId, String path, Object? value) {
    final data = jsonEncode({
      'version': 'v0.9',
      'updateDataModel': {'surfaceId': surfaceId, 'path': path, 'value': value},
    });
    _transportAdapter.addChunk(data);
    _log(_describeFrame(data));
  }

  String _describeFrame(String data) {
    try {
      final payload = jsonDecode(data) as Map<String, dynamic>;
      if (payload.containsKey('createSurface')) {
        final create = payload['createSurface'] as Map<String, dynamic>;
        return 'a2ui createSurface ${create['surfaceId']}';
      }
      if (payload.containsKey('updateComponents')) {
        final update = payload['updateComponents'] as Map<String, dynamic>;
        final components = update['components'] as List<dynamic>;
        return 'a2ui updateComponents count=${components.length}';
      }
      if (payload.containsKey('updateDataModel')) {
        final update = payload['updateDataModel'] as Map<String, dynamic>;
        return 'a2ui updateDataModel path=${update['path']}';
      }
    } catch (_) {
      return 'a2ui invalid frame';
    }
    return 'a2ui frame';
  }

  void _log(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _logs.insert(0, message));
  }
}
