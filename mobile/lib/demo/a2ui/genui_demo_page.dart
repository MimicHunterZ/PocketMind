import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pocketmind/demo/a2ui/a2ui_stream_api_service.dart';
import 'package:uuid/uuid.dart';

class GenUiDemoPage extends ConsumerStatefulWidget {
  const GenUiDemoPage({super.key});

  @override
  ConsumerState<GenUiDemoPage> createState() => _GenUiDemoPageState();
}

class _GenUiDemoPageState extends ConsumerState<GenUiDemoPage> {
  final TextEditingController _queryController = TextEditingController(
    text: '今天天气是晴天，有什么计划可以做？',
  );
  final Uuid _uuid = const Uuid();

  late final SurfaceController _surfaceController;
  late final A2uiTransportAdapter _transportAdapter;

  final List<String> _surfaceIds = [];
  final List<_ActionLog> _actionLogs = [];

  CancelToken? _cancelToken;
  StreamSubscription<A2uiSseEvent>? _streamSubscription;
  StreamSubscription<ChatMessage>? _onSubmitSubscription;

  String _sessionUuid = const Uuid().v4();
  String _requestId = '';
  bool _isStreaming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _surfaceController = SurfaceController(catalogs: [_buildCatalog()]);
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
      if (!mounted) {
        return;
      }
      for (final part in message.parts) {
        final interaction = part.asUiInteractionPart;
        if (interaction != null) {
          setState(() {
            _actionLogs.add(
              _ActionLog(name: 'ui_action', context: interaction.interaction),
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _streamSubscription?.cancel();
    _onSubmitSubscription?.cancel();
    _queryController.dispose();
    _surfaceController.dispose();
    _transportAdapter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('GenUI Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'session: $_sessionUuid',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _queryController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '问题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isStreaming ? null : _startStream,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始流式'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isStreaming ? _stopStream : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isStreaming ? null : _newSession,
                      icon: const Icon(Icons.refresh),
                      label: const Text('新会话'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: colorScheme.error)),
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
                    '点击“开始流式”后，真实 A2UI 事件会驱动同一 surface 内的文本与组件交错更新。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                for (final surfaceId in _surfaceIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Surface(
                          surfaceContext: _surfaceController.contextFor(
                            surfaceId,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_actionLogs.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '交互事件日志',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final log in _actionLogs.reversed.take(8))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• ${log.name}  ${log.context}'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Catalog _buildCatalog() {
    final streamMarkdownMessage = CatalogItem(
      name: 'StreamingMarkdownMessage',
      dataSchema: S.object(
        properties: {
          'path': S.string(description: 'Markdown 数据模型路径'),
          'isLoading': S.boolean(description: '是否加载中'),
        },
        required: ['path'],
      ),
      widgetBuilder: (itemContext) {
        final data = itemContext.data as Map<String, Object?>;
        final path = data['path'] as String;
        final isLoading = (data['isLoading'] as bool?) ?? false;
        return BoundString(
          dataContext: itemContext.dataContext,
          value: {'path': path},
          builder: (context, value) {
            return StreamingTextMarkdown.chatGPT(
              text: value ?? '',
              markdownEnabled: true,
              animationsEnabled: false,
              isLoading: isLoading,
              padding: EdgeInsets.zero,
            );
          },
        );
      },
    );

    final sourceReferenceCard = CatalogItem(
      name: 'SourceReferenceCard',
      dataSchema: S.object(
        properties: {
          'title': S.string(),
          'author': S.string(),
          'timestamp': S.string(),
          'url': S.string(),
        },
        required: ['title'],
      ),
      widgetBuilder: (itemContext) {
        final data = itemContext.data as Map<String, Object?>;
        final title = (data['title'] as String?) ?? '来源';
        final author = (data['author'] as String?) ?? '';
        final timestamp = (data['timestamp'] as String?) ?? '';
        final url = (data['url'] as String?) ?? '';
        return ListTile(
          leading: const Icon(Icons.link_outlined),
          title: Text(title),
          subtitle: Text('$author  $timestamp\n$url'),
          isThreeLine: true,
        );
      },
    );

    final taskChecklist = CatalogItem(
      name: 'TaskChecklist',
      dataSchema: S.object(
        properties: {
          'title': S.string(),
          'items': S.list(
            items: S.object(
              properties: {
                'taskId': S.string(),
                'description': S.string(),
                'priority': S.string(),
                'status': S.string(),
              },
              required: ['taskId', 'description'],
            ),
          ),
        },
      ),
      widgetBuilder: (itemContext) {
        final data = itemContext.data as Map<String, Object?>;
        final title = (data['title'] as String?) ?? '任务清单';
        final items = (data['items'] as List?) ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final raw in items)
              if (raw is Map)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        '${raw['status']}' == 'DONE'
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '[${raw['taskId']}] ${raw['description']} (${raw['priority']})',
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );

    final actionButtonGroup = CatalogItem(
      name: 'ActionButtonGroup',
      dataSchema: S.object(
        properties: {
          'title': S.string(),
          'actions': S.list(
            items: S.object(
              properties: {
                'id': S.string(),
                'label': S.string(),
                'payload': S.string(),
              },
              required: ['id', 'label'],
            ),
          ),
        },
      ),
      widgetBuilder: (itemContext) {
        final data = itemContext.data as Map<String, Object?>;
        final title = (data['title'] as String?) ?? '操作';
        final actions = (data['actions'] as List?) ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final raw in actions)
                  if (raw is Map)
                    FilledButton(
                      onPressed: () {
                        final actionId = '${raw['id'] ?? ''}';
                        final payload = '${raw['payload'] ?? ''}';
                        if (mounted) {
                          setState(() {
                            _actionLogs.add(
                              _ActionLog(
                                name: actionId.isEmpty ? 'action' : actionId,
                                context: payload,
                              ),
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已触发操作: ${raw['label'] ?? actionId}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                        itemContext.dispatchEvent(
                          UserActionEvent(
                            name: actionId,
                            sourceComponentId: itemContext.id,
                            context: {'payload': payload},
                          ),
                        );
                      },
                      child: Text('${raw['label'] ?? 'Action'}'),
                    ),
              ],
            ),
          ],
        );
      },
    );

    return BasicCatalogItems.asCatalog().copyWith(
      newItems: [
        streamMarkdownMessage,
        sourceReferenceCard,
        taskChecklist,
        actionButtonGroup,
      ],
    );
  }

  Future<void> _startStream() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = '请输入问题');
      return;
    }

    _cancelToken?.cancel();
    await _streamSubscription?.cancel();

    _cancelToken = CancelToken();
    _requestId = _uuid.v4();

    setState(() {
      _isStreaming = true;
      _error = null;
      _surfaceIds.clear();
      _actionLogs.clear();
    });

    final api = ref.read(a2uiStreamApiServiceProvider);
    _streamSubscription = api
        .stream(query: query, requestId: _requestId, cancelToken: _cancelToken)
        .listen((event) {
          if (!mounted) {
            return;
          }
          switch (event) {
            case A2uiDeltaEvent(:final data):
              _transportAdapter.addChunk(data);
            case A2uiDoneEvent():
              setState(() => _isStreaming = false);
            case A2uiErrorEvent(:final message):
              setState(() {
                _isStreaming = false;
                _error = message;
              });
          }
        });
  }

  void _stopStream() {
    _cancelToken?.cancel();
    setState(() => _isStreaming = false);
  }

  void _newSession() {
    setState(() {
      _sessionUuid = _uuid.v4();
      _error = null;
      _surfaceIds.clear();
      _actionLogs.clear();
    });
  }
}

class _ActionLog {
  const _ActionLog({required this.name, required this.context});

  final String name;
  final String context;
}
