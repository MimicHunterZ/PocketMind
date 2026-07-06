import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/demo/a2ui/chat_block_sequence_mock.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/providers/chat_providers.dart';
import 'package:pocketmind/service/chat_service.dart';

const String _previewSessionUuid = 'debug-block-sequence-preview';

/// 用固定 mock 消息(见 [buildChatBlockSequenceMockMessages])驱动真实
/// [ChatPage] 的调试预览页,供人工过一遍块序列(文本 + 工具卡片 + A2UI 卡片)
/// 的渲染效果。用局部 [ProviderScope] 覆盖数据层依赖,不接后端、不写入
/// 用户真实的本地聊天数据。
class ChatBlockSequencePreviewPage extends StatelessWidget {
  const ChatBlockSequencePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ChatSession()
      ..uuid = _previewSessionUuid
      ..title = '块序列 Mock 预览';

    return ProviderScope(
      overrides: [
        chatSessionRepositoryProvider.overrideWithValue(
          _PreviewSessionRepo(session),
        ),
        chatMessageRepositoryProvider.overrideWithValue(
          _PreviewMessageRepo(
            buildChatBlockSequenceMockMessages(_previewSessionUuid),
          ),
        ),
        chatServiceProvider.overrideWithValue(_PreviewChatService()),
        // 上面三个只覆盖了数据层。riverpod 的覆盖不会自动传导给"没有被覆盖
        // 但依赖了被覆盖 provider"的上层 provider——那些 provider 若本身不在
        // overrides 列表里,会在应用真正的根 ProviderScope 里被创建,其内部
        // ref 绑定的是根容器,读到的还是真实实现(表现为:界面读到空消息
        // 列表,同时后台仍发出真实网络请求)。所以 ChatPage 直接/间接读取的
        // 这几个 provider 也必须一起覆盖(用同一份实现重新登记,让它们在这个
        // 局部容器里创建,内部依赖才会解析到上面的假数据层)。
        chatSessionStreamProvider.overrideWith(chatSessionStream),
        chatMessagesProvider.overrideWith(chatMessages),
        chatSendProvider.overrideWith(ChatSend.new),
      ],
      child: const ChatPage(
        sessionUuid: _previewSessionUuid,
        canSend: false,
        sendGateHint: '本页仅预览固定 mock 消息的渲染效果,不支持发送新消息',
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

class _PreviewMessageRepo implements IsarChatMessageRepository {
  _PreviewMessageRepo(this._messages);

  final List<ChatMessage> _messages;

  @override
  Stream<List<ChatMessage>> watchBySessionUuid(String sessionUuid) async* {
    yield _messages;
  }

  @override
  Stream<List<ChatMessage>> watchByLeafUuid(
    String sessionUuid,
    String leafUuid,
  ) async* {
    yield _messages;
  }

  @override
  Future<List<ChatMessage>> findBySessionUuid(String sessionUuid) async =>
      _messages;

  @override
  Future<ChatMessage?> findByUuid(String uuid) async {
    for (final message in _messages) {
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
