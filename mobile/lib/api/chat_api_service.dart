import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_api_service.g.dart';

/// ChatApiService Provider
@Riverpod(keepAlive: true)
ChatApiService chatApiService(Ref ref) {
  ref.watch(authControllerProvider);
  final httpClient = ref.watch(httpClientProvider);
  return ChatApiService(httpClient);
}

const String _tag = 'ChatApiService';

/// 聊天会话 & 消息 API 客户端。
///
/// 对应后端 [ChatController] 提供的 6 个端点：
/// - [createSession]  POST   /api/ai/sessions
/// - [listSessions]   GET    /api/ai/sessions
/// - [renameSession]  PATCH  /api/ai/sessions/{uuid}
/// - [deleteSession]  DELETE /api/ai/sessions/{uuid}
/// - [listMessages]   GET    /api/ai/sessions/{uuid}/messages
/// - [streamMessage]  POST   /api/ai/sessions/{uuid}/messages  (SSE)
class ChatApiService {
  final HttpClient _http;

  ChatApiService(this._http);

  // -------------------------------------------------------------------------
  // 会话管理
  // -------------------------------------------------------------------------

  /// 创建新会话。
  ///
  /// [noteUuid] 关联笔记（null 表示全局对话）
  /// [title]    会话标题（可选，AI 会在首条消息后自动设置）
  Future<ChatSessionModel> createSession({
    String? noteUuid,
    String? title,
  }) async {
    PMlog.d(_tag, '创建会话: noteUuid=$noteUuid');
    final data = await _http.post<Map<String, dynamic>>(
      ApiConstants.chatSessions,
      data: {
        if (noteUuid != null) 'noteUuid': noteUuid,
        if (title != null) 'title': title,
      },
    );
    return ChatSessionModel.fromJson(data);
  }

  /// 列出当前用户的所有会话。
  ///
  /// [noteUuid] 过滤关联特定笔记的会话（可选）
  /// [page]     页码（从 0 开始）
  /// [size]     每页条数（默认 50）
  Future<List<ChatSessionModel>> listSessions({
    String? noteUuid,
    int page = 0,
    int size = 50,
  }) async {
    PMlog.d(_tag, '拉取会话列表: noteUuid=$noteUuid');
    final raw = await _http.get<List<dynamic>>(
      ApiConstants.chatSessions,
      queryParameters: {
        if (noteUuid != null) 'noteUuid': noteUuid,
        'page': page,
        'size': size,
      },
    );
    return raw
        .map((e) => ChatSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 重命名会话标题。
  Future<void> renameSession(String sessionUuid, String title) async {
    PMlog.d(_tag, '重命名会话: sessionUuid=$sessionUuid, title=$title');
    await _http.patch<void>(
      ApiConstants.chatSession(sessionUuid),
      data: {'title': title},
    );
  }

  /// 软删除会话。
  Future<void> deleteSession(String sessionUuid) async {
    PMlog.d(_tag, '删除会话: sessionUuid=$sessionUuid');
    await _http.delete<void>(ApiConstants.chatSession(sessionUuid));
  }

  // -------------------------------------------------------------------------
  // 消息管理
  // -------------------------------------------------------------------------

  /// 获取会话下的消息列表（按时间正序）。
  ///
  /// [leafUuid] 指定分支叶子节点时，仅返回该分支的消息链；
  /// 为 null 时返回最新主线消息。
  Future<List<ChatMessageModel>> listMessages(
    String sessionUuid, {
    String? leafUuid,
  }) async {
    PMlog.d(_tag, '拉取消息列表: sessionUuid=$sessionUuid, leaf=$leafUuid');
    final raw = await _http.get<List<dynamic>>(
      ApiConstants.chatMessages(sessionUuid),
      queryParameters: {if (leafUuid != null) 'leafUuid': leafUuid},
    );
    return raw
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 发送用户消息并流式接收 AI 回复。
  ///
  /// [parentUuid] 不为 null 时，从该历史节点分叉创建新分支。
  Stream<ChatStreamEvent> streamMessage(
    String sessionUuid,
    String content, {
    List<String> attachmentUuids = const [],
    String? parentUuid,
    CancelToken? cancelToken,
  }) async* {
    PMlog.d(
      _tag,
      '发送消息(SSE): sessionUuid=$sessionUuid, len=${content.length}, parent=$parentUuid',
    );

    late final Response<ResponseBody> response;
    try {
      response = await _http.dio.post<ResponseBody>(
        ApiConstants.chatMessages(sessionUuid),
        data: jsonEncode({
          'content': content,
          'attachmentUuids': attachmentUuids,
          if (parentUuid != null) 'parentUuid': parentUuid,
        }),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );
    } on DioException catch (e) {
      PMlog.e(_tag, 'SSE 请求失败: $e');
      yield ChatErrorEvent(e.message ?? '网络请求失败');
      return;
    }

    yield* _parseSseStream(response.data!.stream, cancelToken);
  }

  /// 编辑 USER 消息内容（覆盖原内容，后端同时删除紧随的 ASSISTANT 消息）。
  Future<void> editMessage(
    String sessionUuid,
    String messageUuid,
    String content,
  ) async {
    PMlog.d(_tag, '编辑消息: $messageUuid');
    await _http.patch<void>(
      ApiConstants.chatMessage(sessionUuid, messageUuid),
      data: {'content': content},
    );
  }

  /// 重新生成或继续生成指定消息，流式返回新回复。
  ///
  /// [messageUuid] 可为 ASSISTANT UUID（重新生成）或 USER UUID（editAndResend 后继续生成）。
  Stream<ChatStreamEvent> streamRegenerate(
    String sessionUuid,
    String messageUuid, {
    CancelToken? cancelToken,
  }) async* {
    PMlog.d(_tag, '重新生成(SSE): $messageUuid');

    late final Response<ResponseBody> response;
    try {
      response = await _http.dio.post<ResponseBody>(
        ApiConstants.chatMessageRegenerate(sessionUuid, messageUuid),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );
    } on DioException catch (e) {
      PMlog.e(_tag, '重新生成 SSE 请求失败: $e');
      yield ChatErrorEvent(e.message ?? '网络请求失败');
      return;
    }

    yield* _parseSseStream(response.data!.stream, cancelToken);
  }

  /// 对消息评分（1=点赞, 0=取消, -1=点踩）。
  Future<void> rateMessage(
    String sessionUuid,
    String messageUuid,
    int rating,
  ) async {
    PMlog.d(_tag, '评分消息: $messageUuid -> $rating');
    await _http.post<void>(
      ApiConstants.chatMessageRating(sessionUuid, messageUuid),
      data: {'rating': rating},
    );
  }

  /// 获取会话的所有分支摘要列表。
  Future<List<ChatBranchSummaryModel>> fetchBranches(String sessionUuid) async {
    PMlog.d(_tag, '拉取分支列表: $sessionUuid');
    final raw = await _http.get<List<dynamic>>(
      ApiConstants.chatBranches(sessionUuid),
    );
    return raw
        .map((e) => ChatBranchSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 更新分支叶子节点的别名（最多 10 个字符）。
  Future<void> updateBranchAlias(
    String sessionUuid,
    String messageUuid,
    String alias,
  ) async {
    PMlog.d(_tag, '更新分支别名: $messageUuid -> $alias');
    await _http.patch<void>(
      ApiConstants.chatMessageAlias(sessionUuid, messageUuid),
      data: {'alias': alias},
    );
  }

  // -------------------------------------------------------------------------
  // 私有工具
  // -------------------------------------------------------------------------

  /// 解析 SSE 响应流，将 raw bytes 转为 [ChatStreamEvent]。
  Stream<ChatStreamEvent> _parseSseStream(
    Stream<List<int>> rawStream,
    CancelToken? cancelToken,
  ) async* {
    // SSE 行缓冲区（用于处理跨 chunk 的不完整行）
    final buffer = StringBuffer();
    String? currentEvent;

    try {
      await for (final chunk in rawStream) {
        if (cancelToken != null && cancelToken.isCancelled) break;

        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final raw = buffer.toString();

        // 找到所有完整行（以 \n 结尾）
        final newlineIdx = raw.lastIndexOf('\n');
        if (newlineIdx == -1) continue; // 尚无完整行

        final completeLines = raw.substring(0, newlineIdx + 1);
        buffer.clear();
        buffer.write(raw.substring(newlineIdx + 1)); // 剩余不完整内容

        for (final rawLine in completeLines.split('\n')) {
          final line = rawLine.trimRight(); // 去掉 \r

          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            final event = currentEvent;
            currentEvent = null;

            switch (event) {
              case 'delta':
                yield ChatDeltaEvent(data);
              case 'done':
                try {
                  final json = jsonDecode(data) as Map<String, dynamic>;
                  yield ChatDoneEvent(json['messageUuid'] as String);
                } catch (_) {
                  PMlog.w(_tag, 'done 事件解析失败: $data');
                }
              case 'error':
                try {
                  final json = jsonDecode(data) as Map<String, dynamic>;
                  yield ChatErrorEvent(json['message'] as String? ?? 'AI 服务异常');
                } catch (_) {
                  yield ChatErrorEvent(data);
                }
            }
          }
          // 空行（SSE 事件分隔符）直接跳过
        }
      }
    } catch (e) {
      PMlog.e(_tag, 'SSE 流读取异常: $e');
      yield ChatErrorEvent(e.toString());
    }
  }
}
