import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'streaming_markdown_catalog_item.dart';

/// PLAN Task 1.3a 的验证 spike:测试"流式中的临时 SurfaceController → 交接给
/// 持久化后的 SurfaceController"这个动作,交接瞬间会不会闪烁、旧 controller
/// 会不会正确释放。不接 mock 服务、不接真实发送流程,纯手写固定的 A2UI 消息
/// 序列,和真实聊天代码完全隔离。
///
/// 关键结论(做这个 spike 才发现的,写在这里避免以后重踩)：
/// 交接目标(持久化后的 controller)**不能**用 [A2uiTransportAdapter.addChunk]
/// 灌入最终 JSON——`addChunk` 走的是异步解析管线(内部靠 StreamController+
/// Transformer,消息要等一个 microtask 才真正送达 [SurfaceController]),如果
/// 灌完消息就立刻 setState 切换 widget,新 controller 在第一帧渲染时数据可能
/// 还没到,会有一瞬间的空白/重建。正确做法:用同步的
/// [A2uiMessage.fromJson] 把存储的最终 JSON 解析成消息对象,直接循环调用
/// [SurfaceController.handleMessage],在 setState 之前就让新 controller
/// 完全就位,再切换渲染——这样交接前后是同一帧内的状态,不会闪烁。
class SurfaceHandoffLifecycleDemoPage extends StatefulWidget {
  const SurfaceHandoffLifecycleDemoPage({super.key});

  @override
  State<SurfaceHandoffLifecycleDemoPage> createState() =>
      _SurfaceHandoffLifecycleDemoPageState();
}

const String _surfaceId = 'handoff-demo';

/// 固定的最终态消息序列。流式阶段逐条推送这些消息模拟流式生成;交接阶段把
/// 同一份序列同步喂给全新 controller,验证交接前后渲染内容完全一致。
List<String> fixedHandoffMessages() => [
  '{"version":"v0.9","createSurface":{"surfaceId":"$_surfaceId",'
      '"catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}}',
  '{"version":"v0.9","updateComponents":{"surfaceId":"$_surfaceId",'
      '"components":[{"id":"root","component":"Column","children":["title"]},'
      '{"id":"title","component":"Text","text":{"path":"/title"},"variant":"h2"}]}}',
  '{"version":"v0.9","updateDataModel":{"surfaceId":"$_surfaceId",'
      '"path":"/title","value":"生命周期交接测试"}}',
];

class _SurfaceHandoffLifecycleDemoPageState
    extends State<SurfaceHandoffLifecycleDemoPage> {
  SurfaceController? _liveController;
  A2uiTransportAdapter? _liveAdapter;
  SurfaceController? _finalController;

  bool _handedOff = false;
  bool _liveDisposed = false;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _startLiveStreaming();
  }

  void _startLiveStreaming() {
    final controller = SurfaceController(catalogs: [buildAppCatalog()]);
    final adapter = A2uiTransportAdapter();
    adapter.incomingMessages.listen(controller.handleMessage);
    _liveController = controller;
    _liveAdapter = adapter;

    final messages = fixedHandoffMessages();
    for (var i = 0; i < messages.length; i++) {
      Timer(Duration(milliseconds: 300 * (i + 1)), () {
        if (!mounted) return;
        adapter.addChunk(messages[i]);
        setState(() => _log.add('流式:第${i + 1}条消息已推送(经 addChunk 异步解析)'));
        if (i == messages.length - 1) {
          Timer(const Duration(milliseconds: 300), _handOff);
        }
      });
    }
  }

  /// 交接:new controller 用同步的 [A2uiMessage.fromJson] + [handleMessage]
  /// 直接灌入最终态,完全就位后才 setState 切换渲染——避免 [A2uiTransportAdapter]
  /// 异步解析管线造成的"切过去但数据还没到"的空白帧。
  void _handOff() {
    if (!mounted) return;

    final finalController = SurfaceController(catalogs: [buildAppCatalog()]);
    for (final raw in fixedHandoffMessages()) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      finalController.handleMessage(A2uiMessage.fromJson(json));
    }

    setState(() {
      _finalController = finalController;
      _handedOff = true;
      _log.add('交接:同步灌入完毕,切到持久化 controller');
    });

    // 等这一帧真正提交、旧的 Surface widget 已经卸载之后才 dispose 流式
    // controller——如果在 setState 的同一步就 dispose,旧 widget 此刻可能还
    // 挂着监听,会出问题。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _liveAdapter?.dispose();
      _liveController?.dispose();
      _liveAdapter = null;
      _liveController = null;
      if (!mounted) return;
      setState(() {
        _liveDisposed = true;
        _log.add('流式 controller 已 dispose(在新帧提交之后)');
      });
    });
  }

  @override
  void dispose() {
    _liveAdapter?.dispose();
    _liveController?.dispose();
    _finalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeController = _handedOff ? _finalController : _liveController;
    return Scaffold(
      appBar: AppBar(title: const Text('Surface 生命周期交接 spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _handedOff
                  ? '状态: 已交接,流式 controller 已释放: $_liveDisposed'
                  : '状态: 流式中',
              key: const Key('handoff-status'),
            ),
            const SizedBox(height: 12),
            if (activeController != null)
              Surface(surfaceContext: activeController.contextFor(_surfaceId)),
            const Divider(height: 24),
            Expanded(
              child: ListView(children: _log.map(Text.new).toList()),
            ),
          ],
        ),
      ),
    );
  }
}
