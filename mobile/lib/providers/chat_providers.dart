import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/service/chat_service.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.freezed.dart';
part 'chat_providers.g.dart';


// 数据层 Providers


/// 聊天会话 Isar 仓库 Provider。
@Riverpod(keepAlive: true)
IsarChatSessionRepository chatSessionRepository(Ref ref) {
  return IsarChatSessionRepository(ref.watch(isarProvider));
}

/// 聊天消息 Isar 仓库 Provider。
@Riverpod(keepAlive: true)
IsarChatMessageRepository chatMessageRepository(Ref ref) {
  return IsarChatMessageRepository(ref.watch(isarProvider));
}


// 业务层 Provider


/// 聊天业务 Service Provider（全局单例）。
@Riverpod(keepAlive: true)
ChatService chatService(Ref ref) {
  return ChatService(
    sessionRepo: ref.watch(chatSessionRepositoryProvider),
    messageRepo: ref.watch(chatMessageRepositoryProvider),
    apiService: ref.watch(chatApiServiceProvider),
  );
}


// 流数据 Providers（UI 持久化驱动）


/// 聊天会话列表流。
///
/// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
/// 不为 null 时返回该笔记下的会话。
///
/// 用法示例：
/// ```dart
/// ref.watch(chatSessionsProvider(null))       // 全局会话列表
/// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
/// ```
@riverpod
Stream<List<ChatSession>> chatSessions(Ref ref, String? noteUuid) {
  return ref
      .watch(chatSessionRepositoryProvider)
      .watchSessions(noteUuid: noteUuid);
}

/// 指定会话的消息列表流（按时间轴升序）。
///
/// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
/// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String sessionUuid) {
  return ref
      .watch(chatMessageRepositoryProvider)
      .watchBySessionUuid(sessionUuid);
}

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。
@riverpod
Future<ChatSession?> chatSessionByUuid(Ref ref, String uuid) {
  return ref.watch(chatSessionRepositoryProvider).findByUuid(uuid);
}


// 发送状态


/// 消息发送状态，描述当前会话的 SSE 流状态。
@freezed
sealed class ChatSendState with _$ChatSendState {
  /// 空闲，无发送中的请求。
  const factory ChatSendState.idle() = ChatSendIdle;

  /// 流式接收中，[content] 为目前已累积的助手回复文本（用于实时预览）。
  /// [pendingUserMessage] 为用户发送的原始消息，用于乐观展示（落库前即刻显示）。
  const factory ChatSendState.streaming({
    required String content,
    required String pendingUserMessage,
  }) = ChatSendStreaming;

  /// 发生错误。
  const factory ChatSendState.error({required String message}) = ChatSendError;
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
///
/// 职责：
/// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
/// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
/// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
/// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
///
/// UI 显示逻辑：
/// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
/// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
/// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。
@riverpod
class ChatSend extends _$ChatSend {
  static const String _tag = 'ChatSend';

  /// 代码生成（@riverpod）中，family 参数通过 build() 传入。
  @override
  ChatSendState build(String sessionUuid) => const ChatSendState.idle();

  /// 进入聊天页面时调用，从服务端拉取历史消息同步到本地。
  Future<void> initSession() async {
    try {
      await ref.read(chatServiceProvider).syncMessages(sessionUuid);
    } catch (e) {
      PMlog.w(_tag, '初始化消息失败（已有本地缓存）: $e');
      // 同步失败不影响展示，本地缓存已足够显示历史记录
    }
  }

  /// 发送一条用户消息，驱动 SSE 流式回复。
  ///
  /// 防止在流式接收期间重复调用（忽略并发 send）。
  Future<void> send(
    String content, {
    List<String> attachmentUuids = const [],
  }) async {
    if (state is ChatSendStreaming) return;
    state = ChatSendState.streaming(content: '', pendingUserMessage: content);

    final service = ref.read(chatServiceProvider);
    final buffer = StringBuffer();

    try {
      await for (final event in service.streamMessage(
        sessionUuid,
        content,
        attachmentUuids: attachmentUuids,
      )) {
        switch (event) {
          case ChatDeltaEvent(:final delta):
            buffer.write(delta);
            state = ChatSendState.streaming(
              content: buffer.toString(),
              pendingUserMessage: content,
            );
          case ChatDoneEvent():
            // 流结束：将完整消息从服务端同步到本地 Isar，触发 chatMessages 流更新
            await service.syncMessages(sessionUuid);
            state = const ChatSendState.idle();
          case ChatErrorEvent(:final message):
            PMlog.w(_tag, 'AI 回复异常: $message');
            state = ChatSendState.error(message: message);
        }
      }
    } catch (e) {
      PMlog.e(_tag, '发送消息异常: $e');
      state = ChatSendState.error(message: e.toString());
    }
  }

  /// 清除错误状态，恢复 idle。
  void reset() => state = const ChatSendState.idle();
}
