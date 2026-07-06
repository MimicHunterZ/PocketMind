import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/demo/a2ui/chat_streaming_mock.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';

const String _previewSessionUuid = 'debug-streaming-block-sequence-preview';

/// 用固定剧本(见 [buildChatStreamingMockEvents])驱动真实 [ChatPage] 的发送
/// 流程,验证直播态块序列渲染(文本/工具进度/A2UI 卡片依次出现)、流式结束后
/// 交接为持久化消息、全程都不崩溃。真的可以在这一页点击发送——发出的内容
/// 会被忽略,永远回放同一份剧本。用局部 [ProviderScope] 覆盖数据层依赖,
/// 不接后端、不写入用户真实的本地聊天数据。
class ChatStreamingMockPreviewPage extends StatelessWidget {
  const ChatStreamingMockPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ChatSession()
      ..uuid = _previewSessionUuid
      ..title = '直播态 Mock 预览';
    final messageRepo = _MutableStreamingMessageRepo();

    return ProviderScope(
      overrides: [
        chatSessionRepositoryProvider.overrideWithValue(
          _PreviewSessionRepo(session),
        ),
        chatMessageRepositoryProvider.overrideWithValue(messageRepo),
        chatServiceProvider.overrideWithValue(
          _MockStreamingChatService(messageRepo),
        ),
        // 同 chat_block_sequence_preview_page.dart 的教训:依赖链上层的
        // provider 也必须一起覆盖,否则会 escape 到应用真实的根 ProviderScope。
        chatSessionStreamProvider.overrideWith(chatSessionStream),
        chatMessagesProvider.overrideWith(chatMessages),
        chatSendProvider.overrideWith(ChatSend.new),
      ],
      child: const ChatPage(sessionUuid: _previewSessionUuid),
    );
  }
}

class _PreviewSessionRepo implements IsarChatSessionRepository {
  _PreviewSessionRepo(this.session);

  final ChatSession session;

  @override
  Future<ChatSession?> findByUuid(String uuid) async {
    return uuid == session.uuid ? session : null;
  }

  @override
  Stream<ChatSession?> watchByUuid(String uuid) async* {
    yield await findByUuid(uuid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 可变的消息仓库:初始为空,每轮直播结束后由 [_MockStreamingChatService]
/// 把这一轮的持久化消息追加进来,驱动 [chatMessagesProvider] 重新 emit。
class _MutableStreamingMessageRepo implements IsarChatMessageRepository {
  List<ChatMessage> _current = [];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  List<ChatMessage> get current => _current;

  void appendAndNotify(List<ChatMessage> newMessages) {
    _current = [..._current, ...newMessages];
    _controller.add(_current);
  }

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async =>
      _current;

  @override
  Future<ChatMessage?> findByUuid(String uuid) async {
    for (final message in _current) {
      if (message.uuid == uuid) return message;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 每次 [streamMessage] 调用都回放同一份固定剧本,忽略用户实际输入的内容
/// (只用它拼出这一轮的 USER 消息)。[syncMessages] 是真实发送流程里"流结束
/// 后落库"的钩子,这里落的是与剧本内容一致的持久化消息。
class _MockStreamingChatService implements ChatService {
  _MockStreamingChatService(this._messageRepo);

  final _MutableStreamingMessageRepo _messageRepo;
  int _turnCounter = 0;
  List<ChatMessage>? _pendingFinalMessages;

  @override
  Future<void> syncSessionByUuid(String sessionUuid) async {}

  @override
  Stream<ChatStreamEvent> streamMessage(
    String sessionUuid,
    String content, {
    List<String> attachmentUuids = const [],
    String? parentUuid,
    String? requestId,
    CancelToken? cancelToken,
  }) {
    _turnCounter++;
    final lastUuid = _messageRepo.current.isEmpty
        ? null
        : _messageRepo.current.last.uuid;
    _pendingFinalMessages = buildChatStreamingMockFinalMessages(
      sessionUuid: sessionUuid,
      turn: _turnCounter,
      userContent: content,
      parentUuid: lastUuid,
    );
    return buildChatStreamingMockEvents(requestId: requestId);
  }

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {
    final pending = _pendingFinalMessages;
    if (pending == null) return;
    _pendingFinalMessages = null;
    _messageRepo.appendAndNotify(pending);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
