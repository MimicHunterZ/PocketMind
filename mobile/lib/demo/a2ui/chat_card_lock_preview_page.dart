import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/demo/a2ui/chat_card_lock_mock.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';

const String _previewSessionUuid = 'debug-card-lock-preview';

/// 用 [buildChatCardLockMockMessages] 驱动真实 [ChatPage],验证卡片提交锁定
/// (D15)的完整闭环:已经带"提交交互"消息的卡片一开始就应该锁定、定格显示;
/// 没有的卡片二在这里真的点一下"提交选择",应该立刻锁定、跟卡片一的样式
/// 一致。不接后端、不接真实发送,提交交互通过 [a2uiCardSubmitHandlerProvider]
/// 这个挂点直接写回本地假仓库。
class ChatCardLockPreviewPage extends StatelessWidget {
  const ChatCardLockPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ChatSession()
      ..uuid = _previewSessionUuid
      ..title = '卡片锁定 Mock 预览';
    final messageRepo = _MutableCardLockMessageRepo(
      buildChatCardLockMockMessages(_previewSessionUuid),
    );

    return ProviderScope(
      overrides: [
        chatSessionRepositoryProvider.overrideWithValue(
          _PreviewSessionRepo(session),
        ),
        chatMessageRepositoryProvider.overrideWithValue(messageRepo),
        chatServiceProvider.overrideWithValue(_PreviewChatService()),
        // 同其余预览页的教训:依赖链上层的 provider 也必须一起覆盖,否则会
        // escape 到应用真实的根 ProviderScope。
        chatSessionStreamProvider.overrideWith(chatSessionStream),
        chatMessagesProvider.overrideWith(chatMessages),
        chatSendProvider.overrideWith(ChatSend.new),
        a2uiCardSubmitHandlerProvider.overrideWith(
          (ref) => (surfaceId, dataModel) {
            messageRepo.appendSubmission(surfaceId, dataModel);
          },
        ),
      ],
      child: const ChatPage(
        sessionUuid: _previewSessionUuid,
        canSend: false,
        sendGateHint: '本页仅预览卡片交互与锁定效果,不支持发送新消息',
      ),
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

/// 可变消息仓库:提交交互后,把一条新的"提交交互"消息追加进去并通知订阅者,
/// 驱动卡片重新渲染成锁定态。
class _MutableCardLockMessageRepo implements IsarChatMessageRepository {
  _MutableCardLockMessageRepo(this._current);

  List<ChatMessage> _current;
  final _controller = StreamController<List<ChatMessage>>.broadcast();
  int _submissionCounter = 0;

  void appendSubmission(String surfaceId, Map<String, dynamic> dataModel) {
    _submissionCounter++;
    final submission = ChatMessage()
      ..uuid = 'lock-live-sub-$_submissionCounter'
      ..sessionUuid = _previewSessionUuid
      ..parentUuid = _current.isEmpty ? null : _current.last.uuid
      ..role = 'USER'
      ..messageType = 'TEXT'
      ..content = jsonEncode({'surfaceId': surfaceId, 'dataModel': dataModel});
    _current = [..._current, submission];
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

class _PreviewChatService implements ChatService {
  @override
  Future<void> syncSessionByUuid(String sessionUuid) async {}

  @override
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
