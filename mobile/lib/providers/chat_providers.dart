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
@riverpod
Stream<List<ChatSession>> chatSessions(Ref ref, String? noteUuid) {
  return ref
      .watch(chatSessionRepositoryProvider)
      .watchSessions(noteUuid: noteUuid);
}

/// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。
@riverpod
Stream<ChatSession?> chatSessionStream(Ref ref, String sessionUuid) {
  return ref.watch(chatSessionRepositoryProvider).watchByUuid(sessionUuid);
}

/// 指定会话的消息列表流（按时间轴升序）。
///
/// 自动感知会话的 [ChatSession.activeLeafUuid]：
/// - null → 主线（watchBySessionUuid）
/// - 非 null → 分支链路（watchByLeafUuid）
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String sessionUuid) {
  final sessionAsync = ref.watch(chatSessionStreamProvider(sessionUuid));
  final leafUuid = sessionAsync.asData?.value?.activeLeafUuid;
  final messageRepo = ref.watch(chatMessageRepositoryProvider);

  if (leafUuid != null) {
    return messageRepo.watchByLeafUuid(sessionUuid, leafUuid);
  }
  return messageRepo.watchBySessionUuid(sessionUuid);
}

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。
@riverpod
Future<ChatSession?> chatSessionByUuid(Ref ref, String uuid) {
  return ref.watch(chatSessionRepositoryProvider).findByUuid(uuid);
}

/// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。
@riverpod
Future<List<ChatBranchSummaryModel>> chatBranches(Ref ref, String sessionUuid) {
  return ref.watch(chatServiceProvider).fetchBranches(sessionUuid);
}

/// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。
@riverpod
Stream<ChatMessage?> chatMessageByUuid(Ref ref, String uuid) {
  return ref.watch(chatMessageRepositoryProvider).watchByUuid(uuid);
}

// 发送状态

/// 消息发送状态，描述当前会话的 SSE 流状态。
@freezed
sealed class ChatSendState with _$ChatSendState {
  /// 空闲，无发送中的请求。
  const factory ChatSendState.idle() = ChatSendIdle;

  /// 流式接收中，[content] 为目前已累积的助手回复文本（用于实时预览）。
  const factory ChatSendState.streaming({
    required String content,
    required String pendingUserMessage,
  }) = ChatSendStreaming;

  /// 发生错误。
  const factory ChatSendState.error({required String message}) = ChatSendError;
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
@riverpod
class ChatSend extends _$ChatSend {
  static const String _tag = 'ChatSend';

  @override
  ChatSendState build(String sessionUuid) => const ChatSendState.idle();

  /// 进入聊天页面时调用，从服务端拉取历史消息同步到本地。
  Future<void> initSession() async {
    try {
      final session = await ref
          .read(chatSessionRepositoryProvider)
          .findByUuid(sessionUuid);
      await ref
          .read(chatServiceProvider)
          .syncMessages(sessionUuid, leafUuid: session?.activeLeafUuid);
    } catch (e) {
      PMlog.w(_tag, '初始化消息失败（已有本地缓存）: $e');
    }
  }

  /// 发送一条用户消息，驱动 SSE 流式回复。
  ///
  /// [parentUuid] 不为 null 时，从该节点分叉创建新分支。
  /// [showPendingBubble] false 时不显示待发用户气泡（编辑重发时避免重复）。
  Future<void> send(
    String content, {
    List<String> attachmentUuids = const [],
    String? parentUuid,
    bool showPendingBubble = true,
  }) async {
    if (state is ChatSendStreaming) return;
    state = ChatSendState.streaming(
      content: '',
      pendingUserMessage: showPendingBubble ? content : '',
    );

    final service = ref.read(chatServiceProvider);
    final buffer = StringBuffer();

    // 分支模式：发送前切换视图到分岔点，避免流式期间展示全量消息
    if (parentUuid != null) {
      await service.updateActiveLeaf(sessionUuid, parentUuid);
    }

    try {
      await for (final event in service.streamMessage(
        sessionUuid,
        content,
        attachmentUuids: attachmentUuids,
        parentUuid: parentUuid,
      )) {
        switch (event) {
          case ChatDeltaEvent(:final delta):
            buffer.write(delta);
            state = ChatSendState.streaming(
              content: buffer.toString(),
              pendingUserMessage: showPendingBubble ? content : '',
            );
          case ChatDoneEvent(:final messageUuid):
            if (parentUuid != null) {
              // 分支创建完成：同步新叶子链路，切换视图到新 ASSISTANT 消息
              await service.syncMessages(sessionUuid, leafUuid: messageUuid);
              await service.updateActiveLeaf(sessionUuid, messageUuid);
            } else {
              await service.syncMessages(sessionUuid);
            }
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

  /// 编辑 USER 消息内容，并对同一 USER 消息重新触发 AI 回复（不创建新 USER 消息）。
  ///
  /// 服务端编辑消息内容并删除旧 ASSISTANT 回复，再对原 userUuid 重新生成，避免重复对话条目。
  Future<void> editAndResend(String messageUuid, String newContent) async {
    if (state is ChatSendStreaming) return;
    final service = ref.read(chatServiceProvider);

    // 编辑前检查分支模式状态，避免编辑和删除 ASSISTANT 后 UI 空预
    final currentSession = await ref
        .read(chatSessionRepositoryProvider)
        .findByUuid(sessionUuid);
    final wasInBranch = currentSession?.activeLeafUuid != null;

    try {
      await service.editMessage(sessionUuid, messageUuid, newContent);
    } catch (e) {
      PMlog.e(_tag, '编辑消息失败: $e');
      state = ChatSendState.error(message: '编辑失败: $e');
      return;
    }

    // 分支模式下，ASSISTANT 已被 editMessage 删除，activeLeafUuid 仍指向旧删除节点
    // 立即切换到 USER 消息节点，避免 watchByLeafUuid 返回空链
    if (wasInBranch) {
      await service.updateActiveLeaf(sessionUuid, messageUuid);
    }

    // 对原 USER 消息直接调用重新生成（后端识别 USER UUID，不再创建新资源）
    state = const ChatSendState.streaming(content: '', pendingUserMessage: '');
    final buffer = StringBuffer();
    try {
      await for (final event in service.streamRegenerate(
        sessionUuid,
        messageUuid,
      )) {
        switch (event) {
          case ChatDeltaEvent(:final delta):
            buffer.write(delta);
            state = ChatSendState.streaming(
              content: buffer.toString(),
              pendingUserMessage: '',
            );
          case ChatDoneEvent(:final messageUuid):
            if (wasInBranch) {
              await service.syncMessages(sessionUuid, leafUuid: messageUuid);
              await service.updateActiveLeaf(sessionUuid, messageUuid);
            } else {
              await service.syncMessages(sessionUuid);
            }
            state = const ChatSendState.idle();
          case ChatErrorEvent(:final message):
            PMlog.w(_tag, '编辑重发异常: $message');
            state = ChatSendState.error(message: message);
        }
      }
    } catch (e) {
      PMlog.e(_tag, '编辑重发异常: $e');
      state = ChatSendState.error(message: e.toString());
    }
  }

  /// 重新生成指定 ASSISTANT 消息，替换为新的 SSE 流式回复。
  Future<void> regenerate(String assistantMessageUuid) async {
    if (state is ChatSendStreaming) return;

    final messageRepo = ref.read(chatMessageRepositoryProvider);
    // 提前获取父节点 UUID 和当前分支状态，避免删除后无法查询
    final assistantMsg = await messageRepo.findByUuid(assistantMessageUuid);
    final currentSession = await ref
        .read(chatSessionRepositoryProvider)
        .findByUuid(sessionUuid);
    final wasInBranch = currentSession?.activeLeafUuid != null;

    // 若当前处于分支模式，先将视图切换到 USER 父节点，
    // 避免软删除后 watchByLeafUuid 指向已删除的 ASSISTANT 消息导致 UI 空链
    if (wasInBranch && assistantMsg?.parentUuid != null) {
      await ref
          .read(chatServiceProvider)
          .updateActiveLeaf(sessionUuid, assistantMsg!.parentUuid!);
    }

    // 本地立即删除旧 AI 消息，使气泡即刻从 UI 消失
    await messageRepo.softDeleteByUuids([assistantMessageUuid]);

    state = const ChatSendState.streaming(content: '', pendingUserMessage: '');
    final service = ref.read(chatServiceProvider);
    final buffer = StringBuffer();

    try {
      await for (final event in service.streamRegenerate(
        sessionUuid,
        assistantMessageUuid,
      )) {
        switch (event) {
          case ChatDeltaEvent(:final delta):
            buffer.write(delta);
            state = ChatSendState.streaming(
              content: buffer.toString(),
              pendingUserMessage: '',
            );
          case ChatDoneEvent(:final messageUuid):
            if (wasInBranch) {
              // 分支模式：同步新叶子链路，再切换激活节点
              await service.syncMessages(sessionUuid, leafUuid: messageUuid);
              await service.updateActiveLeaf(sessionUuid, messageUuid);
            } else {
              await service.syncMessages(sessionUuid);
            }
            state = const ChatSendState.idle();
          case ChatErrorEvent(:final message):
            PMlog.w(_tag, '重新生成异常: $message');
            state = ChatSendState.error(message: message);
        }
      }
    } catch (e) {
      PMlog.e(_tag, '重新生成异常: $e');
      state = ChatSendState.error(message: e.toString());
    }
  }

  /// 对消息评分。[rating] = 1/0/-1，与当前值相同时切换为 0（取消）。
  Future<void> rateMessage(String messageUuid, int rating) async {
    try {
      await ref
          .read(chatServiceProvider)
          .rateMessage(sessionUuid, messageUuid, rating);
    } catch (e) {
      PMlog.e(_tag, '评分失败: $e');
    }
  }

  /// 清除错误状态，恢复 idle。
  void reset() => state = const ChatSendState.idle();
}
