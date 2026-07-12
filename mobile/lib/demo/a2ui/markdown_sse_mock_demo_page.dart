import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:genui/genui.dart';
import 'package:pocketmind/util/theme_data.dart';

const String _genuiSurfaceId = 'markdown-sse-mock-genui-text';

class MarkdownSseMockDemoPage extends StatefulWidget {
  const MarkdownSseMockDemoPage({super.key});

  @override
  State<MarkdownSseMockDemoPage> createState() =>
      _MarkdownSseMockDemoPageState();
}

class _MarkdownSseMockDemoPageState extends State<MarkdownSseMockDemoPage> {
  static const String _mockFullAsset = 'assets/mock/full.md';

  final StringBuffer _buffer = StringBuffer();
  Timer? _timer;

  String _fullText = '';
  String _streamingText = '';
  int _cursor = 0;
  bool _isStreaming = false;
  String? _error;

  /// 每个 tick 的间隔(毫秒),值越小输出越快
  double _intervalMs = 14;

  /// 右栏对比:同一份 [_streamingText] 同时喂给 genui 自带的 Text 组件,验证它
  /// 有没有跟 [StreamingTextMarkdown] 一样的"动画时钟 vs 数据时钟"错位问题。
  late final SurfaceController _genuiController;

  @override
  void initState() {
    super.initState();
    _genuiController = SurfaceController(
      catalogs: [BasicCatalogItems.asCatalog()],
    );
    _genuiController.handleMessage(
      const CreateSurface(
        surfaceId: _genuiSurfaceId,
        catalogId: basicCatalogId,
      ),
    );
    _genuiController.handleMessage(
      UpdateComponents(
        surfaceId: _genuiSurfaceId,
        components: [
          const Component(
            id: 'root',
            type: 'Text',
            properties: {
              'text': {'path': '/text'},
            },
          ),
        ],
      ),
    );
    _loadMock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _genuiController.dispose();
    super.dispose();
  }

  /// 把 [_streamingText] 同步写进 genui controller 的 dataModel,驱动右栏
  /// Text 组件跟左栏 [StreamingTextMarkdown] 收到完全相同的输入。
  void _pushGenuiText(String text) {
    _genuiController.handleMessage(
      UpdateDataModel(
        surfaceId: _genuiSurfaceId,
        path: DataPath('/text'),
        value: text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Markdown SSE Mock Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'StreamingTextMarkdown'),
              Tab(text: 'genui Text'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '数据源: $_mockFullAsset',
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: (!_isStreaming && _fullText.isNotEmpty)
                            ? _startStream
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始模拟流式'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isStreaming ? _stopStream : null,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('停止'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: !_isStreaming ? _reset : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重置'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: colorScheme.error)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('速度', style: context.textTheme.bodySmall),
                      Expanded(
                        // 滑块右移代表更快,因此用 (max - value) 映射到实际间隔
                        child: Slider(
                          min: 1,
                          max: 60,
                          value: 61 - _intervalMs,
                          label: '${_intervalMs.round()}ms/tick',
                          onChanged: (v) {
                            setState(() => _intervalMs = 61 - v);
                            // 流式进行中调速时立即应用新间隔
                            if (_isStreaming) {
                              _restartTimer();
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '${_intervalMs.round()}ms',
                          textAlign: TextAlign.end,
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _MarkdownPane(
                    colorScheme: colorScheme,
                    child: StreamingTextMarkdown.chatGPT(
                      text: _streamingText,
                      markdownEnabled: true,
                      animationsEnabled: false,
                      // isLoading 语义为「等待首个 token 时显示骨架屏」,
                      // 仅在尚未收到任何文本时为 true,否则会一直卡在加载骨架屏
                      isLoading: _isStreaming && _streamingText.isEmpty,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  _MarkdownPane(
                    colorScheme: colorScheme,
                    child: Surface(
                      surfaceContext: _genuiController.contextFor(
                        _genuiSurfaceId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMock() async {
    try {
      final text = await rootBundle.loadString(_mockFullAsset);
      if (!mounted) {
        return;
      }
      setState(() {
        _fullText = text;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '读取 mock 资源失败: $e';
      });
    }
  }

  void _startStream() {
    _timer?.cancel();
    _buffer.clear();
    _cursor = 0;
    setState(() {
      _streamingText = '';
      _isStreaming = true;
      _error = null;
    });
    _pushGenuiText('');
    _restartTimer();
  }

  /// 以当前 [_intervalMs] 重建定时器,支持流式过程中实时调速
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs.round()), (_) {
      if (_cursor >= _fullText.length) {
        _stopStream();
        return;
      }

      final step = _nextStep(_fullText, _cursor);
      final nextEnd = (_cursor + step).clamp(0, _fullText.length);
      _buffer.write(_fullText.substring(_cursor, nextEnd));
      _cursor = nextEnd;

      if (mounted) {
        setState(() {
          _streamingText = _buffer.toString();
        });
        _pushGenuiText(_streamingText);
      }
    });
  }

  void _stopStream() {
    _timer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isStreaming = false;
      if (_cursor >= _fullText.length) {
        _streamingText = _fullText;
      }
    });
    if (_cursor >= _fullText.length) {
      _pushGenuiText(_fullText);
    }
  }

  void _reset() {
    _timer?.cancel();
    _buffer.clear();
    _cursor = 0;
    setState(() {
      _streamingText = '';
      _isStreaming = false;
    });
    _pushGenuiText('');
  }

  int _nextStep(String text, int index) {
    final char = text[index];

    if (char == '\n') {
      return 1;
    }

    if (_looksLikeMarkdownMarker(text, index)) {
      return _consumeMarker(text, index);
    }

    return 1;
  }

  bool _looksLikeMarkdownMarker(String text, int index) {
    final c = text[index];
    return c == '#' ||
        c == '`' ||
        c == '*' ||
        c == '-' ||
        c == '>' ||
        c == '|' ||
        _isDigit(c);
  }

  int _consumeMarker(String text, int index) {
    int end = index;
    while (end < text.length) {
      final c = text[end];
      if (c == '\n') {
        break;
      }
      if (c == ' ') {
        end++;
        break;
      }
      if (_isMarkdownPunctuation(c) || _isDigit(c)) {
        end++;
        continue;
      }
      break;
    }

    if (end == index) {
      return 1;
    }
    return end - index;
  }

  bool _isMarkdownPunctuation(String c) {
    return c == '#' ||
        c == '`' ||
        c == '*' ||
        c == '-' ||
        c == '>' ||
        c == '|' ||
        c == '[' ||
        c == ']' ||
        c == '(' ||
        c == ')' ||
        c == '.';
  }

  bool _isDigit(String c) {
    if (c.isEmpty) {
      return false;
    }
    final code = c.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}

class _MarkdownPane extends StatelessWidget {
  const _MarkdownPane({required this.colorScheme, required this.child});

  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}
