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

  /// 同步单个会话。
  Future<void> syncSessionByUuid(String sessionUuid) async {
    try {
      final model = await _apiService.getSession(sessionUuid);
      await _sessionRepo.upsertFromModels([model]);
      PMlog.d(_tag, '同步单会话完成: sessionUuid=$sessionUuid');
    } catch (e) {
      PMlog.w(_tag, '同步单会话失败: sessionUuid=$sessionUuid, error=$e');
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
    await syncSessions();
  }

  /// 删除会话：服务端删除 + 本地软删除。
  Future<void> deleteSession(String uuid) async {
    await _apiService.deleteSession(uuid);
    await _sessionRepo.softDelete(uuid);
  }

  /// 本地更新会话激活的叶子节点（分支模式）。null = 回到主线。
  Future<void> updateActiveLeaf(String sessionUuid, String? leafUuid) async {
    await _sessionRepo.updateActiveLeaf(sessionUuid, leafUuid);
  }

  /// 本地更新会话标题（用于 SSE done 携带标题时即时刷新）。
  Future<void> updateSessionTitleLocal(String sessionUuid, String title) async {
    await _sessionRepo.updateTitle(sessionUuid, title);
  }

  // 消息管理

  /// 从服务端拉取指定会话的历史消息并同步到本地 Isar。
  ///
  /// [leafUuid] 不为 null 时，拉取该分支叶子节点所在的消息链；
  /// 默认（null）拉取主线最新消息。
  Future<void> syncMessages(String sessionUuid, {String? leafUuid}) async {
    try {
      final models = await _apiService.listMessages(
        sessionUuid,
        leafUuid: leafUuid,
      );
      await _messageRepo.upsertFromModels(models);
      PMlog.d(_tag, '同步消息完成: sessionUuid=$sessionUuid, count=${models.length}');
    } catch (e) {
      PMlog.w(_tag, '同步消息失败: $e');
      rethrow;
    }
  }

  /// 发送消息，返回 SSE 事件流。
  ///
  /// [parentUuid] 不为 null 时，从该节点分叉（创建新分支）。
  Stream<ChatStreamEvent> streamMessage(
    String sessionUuid,
    String content, {
    List<String> attachmentUuids = const [],
    String? parentUuid,
    String? requestId,
    CancelToken? cancelToken,
  }) {
    PMlog.d(_tag, '发送消息: sessionUuid=$sessionUuid');
    return _apiService.streamMessage(
      sessionUuid,
      content,
      attachmentUuids: attachmentUuids,
      parentUuid: parentUuid,
      requestId: requestId,
      cancelToken: cancelToken,
    );
  }

  /// 编辑 USER 消息内容（服务端覆盖原内容并删除 ASSISTANT 回复）。
  ///
  /// 本地同步：更新消息内容，并立即软删除紧随的 ASSISTANT 消息，使 UI 即时响应。
  /// 调用方应随后发起 [streamMessage] 以重新生成 AI 回复。
  Future<void> editMessage(
    String sessionUuid,
    String messageUuid,
    String newContent,
  ) async {
    await _apiService.editMessage(sessionUuid, messageUuid, newContent);
    // 本地同步：更新内容 + 立即软删除旧 AI 回复（避免旧回复在新流式响应期间继续显示）
    await _messageRepo.updateContent(messageUuid, newContent);
    await _messageRepo.softDeleteAssistantChildrenOf(messageUuid);
    PMlog.d(_tag, '已编辑消息 $messageUuid，并清理旧 AI 回复');
  }

  /// 重新生成或继续生成 ASSISTANT 回复，返回 SSE 事件流。
  ///
  /// [messageUuid] 可为 ASSISTANT UUID（重新生成）或 USER UUID（editAndResend 后继续生成）。
  Stream<ChatStreamEvent> streamRegenerate(
    String sessionUuid,
    String messageUuid, {
    String? requestId,
    CancelToken? cancelToken,
  }) {
    PMlog.d(_tag, '重新生成: sessionUuid=$sessionUuid, messageUuid=$messageUuid');
    return _apiService.streamRegenerate(
      sessionUuid,
      messageUuid,
      requestId: requestId,
      cancelToken: cancelToken,
    );
  }

  /// 停止当前 requestId 对应的流式回复。
  Future<void> stopStream(String sessionUuid, String requestId) {
    return _apiService.stopStream(sessionUuid, requestId);
  }

  /// 对消息评分（1=点赞, 0=取消, -1=点踩），同步到服务端并更新本地缓存。
  Future<void> rateMessage(
    String sessionUuid,
    String messageUuid,
    int rating,
  ) async {
    await _apiService.rateMessage(sessionUuid, messageUuid, rating);
    await _messageRepo.upsertRating(messageUuid, rating);
    PMlog.d(_tag, '评分 $messageUuid -> $rating');
  }

  /// 获取会话所有分支摘要。
  ///
  /// 优先请求服务端；网络异常或服务不可用时，自动降级到本地 Isar 推导。
  /// 对调用方无感知，始终返回同一模型结构。
  Future<List<ChatBranchSummaryModel>> fetchBranches(String sessionUuid) async {
    try {
      final remote = await _apiService.fetchBranches(sessionUuid);
      if (remote.isNotEmpty) {
        return remote;
      }
      final local = await _messageRepo.buildLocalBranchSummaries(sessionUuid);
      PMlog.d(
        _tag,
        '分支列表为空，返回本地推导结果: sessionUuid=$sessionUuid, count=${local.length}',
      );
      return local;
    } on DioException catch (e) {
      PMlog.w(_tag, '拉取分支失败，降级本地: sessionUuid=$sessionUuid, error=$e');
      return _messageRepo.buildLocalBranchSummaries(sessionUuid);
    } catch (e) {
      PMlog.w(_tag, '拉取分支异常，降级本地: sessionUuid=$sessionUuid, error=$e');
      return _messageRepo.buildLocalBranchSummaries(sessionUuid);
    }
  }

  /// 更新分支叶子节点的别名（同步服务端 + 本地缓存）。
  Future<void> updateBranchAlias(
    String sessionUuid,
    String messageUuid,
    String alias,
  ) async {
    await _apiService.updateBranchAlias(sessionUuid, messageUuid, alias);
    await _messageRepo.updateBranchAlias(messageUuid, alias);
    PMlog.d(_tag, '已更新分支别名: $messageUuid -> $alias');
  }
}
