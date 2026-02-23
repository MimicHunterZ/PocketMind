import 'package:dio/dio.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 聊天业务层，编排 API 调用与本地 Isar 持久化。
///
/// 设计原则（持久化驱动展示）：
/// - UI 订阅 Isar 数据变化，而非直接消费 HTTP 响应。
/// - UI 绝不直接调用 [ChatApiService]，必须经由此 Service。
/// - 发送消息产生的流式事件由调用方（Notifier）处理展示；
///   流结束后调用 [syncMessages] 将最终消息落库，触发 UI 更新。
class ChatService {
  final IsarChatSessionRepository _sessionRepo;
  final IsarChatMessageRepository _messageRepo;
  final ChatApiService _apiService;

  static const String _tag = 'ChatService';

  const ChatService({
    required IsarChatSessionRepository sessionRepo,
    required IsarChatMessageRepository messageRepo,
    required ChatApiService apiService,
  }) : _sessionRepo = sessionRepo,
       _messageRepo = messageRepo,
       _apiService = apiService;

  
  // 会话管理
  

  /// 从服务端拉取会话列表并同步到本地 Isar。
  ///
  /// [noteUuid] 不为 null 时只拉取该笔记下的会话。
  Future<void> syncSessions({String? noteUuid}) async {
    try {
      final models = await _apiService.listSessions(noteUuid: noteUuid);
      await _sessionRepo.upsertFromModels(models);
      PMlog.d(_tag, '同步会话完成: count=${models.length}');
    } catch (e) {
      PMlog.w(_tag, '同步会话失败: $e');
      rethrow;
    }
  }

  /// 在服务端创建新会话，并将其写入本地 Isar，返回本地对象。
  Future<ChatSession> createSession({String? noteUuid, String? title}) async {
    final model = await _apiService.createSession(
      noteUuid: noteUuid,
      title: title,
    );
    await _sessionRepo.upsertFromModels([model]);
    final session = await _sessionRepo.findByUuid(model.uuid);
    return session!;
  }

  /// 重命名会话（更新服务端，再重新同步本地）。
  Future<void> renameSession(String uuid, String title) async {
    await _apiService.renameSession(uuid, title);
    // 重新拉取以保证本地数据与服务端一致
    await syncSessions();
  }

  /// 删除会话：服务端删除 + 本地软删除。
  Future<void> deleteSession(String uuid) async {
    await _apiService.deleteSession(uuid);
    await _sessionRepo.softDelete(uuid);
  }

  
  // 消息管理
  

  /// 从服务端拉取指定会话的全部历史消息并同步到本地 Isar。
  ///
  /// 通常在以下时机调用：
  /// 1. 进入聊天页面时（初始化加载）
  /// 2. 收到 [ChatDoneEvent] 后（将本轮对话落库）
  Future<void> syncMessages(String sessionUuid) async {
    try {
      final models = await _apiService.listMessages(sessionUuid);
      await _messageRepo.upsertFromModels(models);
      PMlog.d(_tag, '同步消息完成: sessionUuid=$sessionUuid, count=${models.length}');
    } catch (e) {
      PMlog.w(_tag, '同步消息失败: $e');
      rethrow;
    }
  }

  /// 向指定会话发送消息，返回服务端 SSE 事件流。
  ///
  /// 调用方（[ChatSend] Notifier）负责：
  /// - 监听 [ChatDeltaEvent] 更新流式预览文本；
  /// - 收到 [ChatDoneEvent] 后调用 [syncMessages] 将消息落库；
  /// - 捕获 [ChatErrorEvent] 更新错误状态。
  Stream<ChatStreamEvent> streamMessage(
    String sessionUuid,
    String content, {
    List<String> attachmentUuids = const [],
    CancelToken? cancelToken,
  }) {
    PMlog.d(_tag, '发送消息: sessionUuid=$sessionUuid');
    return _apiService.streamMessage(
      sessionUuid,
      content,
      attachmentUuids: attachmentUuids,
      cancelToken: cancelToken,
    );
  }
}
