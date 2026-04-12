import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Markdown SSE Mock Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据源: $_mockFullAsset',
                  style: Theme.of(context).textTheme.bodySmall,
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: StreamingTextMarkdown.chatGPT(
                  text: _streamingText,
                  markdownEnabled: true,
                  animationsEnabled: false,
                  isLoading: _isStreaming,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
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

    _timer = Timer.periodic(const Duration(milliseconds: 14), (_) {
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
  }

  void _reset() {
    _timer?.cancel();
    _buffer.clear();
    _cursor = 0;
    setState(() {
      _streamingText = '';
      _isStreaming = false;
    });
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
