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

  /// 单独生成会话标题。
  Future<ChatSessionModel> generateSessionTitle(
    String sessionUuid,
    String content,
  ) async {
    PMlog.d(_tag, '生成会话标题: sessionUuid=$sessionUuid');
    final data = await _http.post<Map<String, dynamic>>(
      ApiConstants.chatSessionTitle(sessionUuid),
      data: {'content': content},
    );
    return ChatSessionModel.fromJson(data);
  }

  /// 获取单个会话详情。
  Future<ChatSessionModel> getSession(String sessionUuid) async {
    PMlog.d(_tag, '拉取单会话: sessionUuid=$sessionUuid');
    final data = await _http.get<Map<String, dynamic>>(
      ApiConstants.chatSession(sessionUuid),
    );
    return ChatSessionModel.fromJson(data);
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
    String? requestId,
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
            if (requestId != null && requestId.isNotEmpty)
              'X-Request-Id': requestId,
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
    String? requestId,
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
            if (requestId != null && requestId.isNotEmpty)
              'X-Request-Id': requestId,
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

  /// 停止当前会话中指定 requestId 的流式回复。
  Future<void> stopStream(String sessionUuid, String requestId) async {
    PMlog.d(_tag, '停止流式回复: sessionUuid=$sessionUuid, requestId=$requestId');
    await _http.post<void>(
      ApiConstants.chatMessageStop(sessionUuid),
      data: {'requestId': requestId},
    );
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
    final lineBuffer = StringBuffer();
    String? currentEvent;
    final dataLines = <String>[];

    Stream<ChatStreamEvent> emitCurrentEvent() async* {
      final event = currentEvent;
      if (event == null || dataLines.isEmpty) {
        currentEvent = null;
        dataLines.clear();
        return;
      }

      final data = dataLines.join('\n');
      currentEvent = null;
      dataLines.clear();

      // 解析事件负载 JSON(所有细粒度事件的 data 都是一个扁平 JSON 对象)。
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        // 非 JSON 负载:仅个别事件容忍(见下),其余忽略。
      }

      // SSE event 帧名 = AG-UI 事件类型(大写下划线),对齐 `ag_ui ^0.3.0`。
      // 只映射块序列渲染真正需要的事件,其余生命周期事件(START/END/STEP)忽略——
      // 文本靠 CONTENT 累积,工具/卡片最终态靠流结束后 syncMessages 落库复现。
      switch (event) {
        case 'TEXT_MESSAGE_CONTENT':
          final delta = json?['delta'];
          if (delta is String) {
            yield ChatDeltaEvent(delta);
          }
        case 'TOOL_CALL_START':
          final toolCallId = json?['toolCallId'] as String?;
          final toolCallName = json?['toolCallName'] as String?;
          if (toolCallId != null) {
            yield ChatToolCallStartEvent(toolCallId, toolCallName ?? '工具');
          }
        case 'TOOL_CALL_END':
          final toolCallId = json?['toolCallId'] as String?;
          if (toolCallId != null) {
            yield ChatToolCallEndEvent(toolCallId);
          }
        case 'ACTIVITY_SNAPSHOT':
          // content 是一张卡片的完整 A2UI envelope(单条对象或多条数组)。
          // 内部 _LiveA2uiCardMessage 逐条消费,所以拆成逐条 chunk(每条重新
          // 序列化成字符串),流式态渲染逻辑无需改动。
          final content = json?['content'];
          final messages = content is List
              ? content
              : (content == null ? const [] : [content]);
          for (final message in messages) {
            yield ChatA2uiChunkEvent(jsonEncode(message));
          }
        case 'RUN_FINISHED':
          // result 带回这轮 assistant 消息 UUID(后端 handleDoneTerminal 放入),
          // requestId 用 runId。
          final messageUuid = json?['result'] as String?;
          if (messageUuid != null) {
            yield ChatDoneEvent(
              messageUuid,
              requestId: json?['runId'] as String?,
            );
          } else {
            PMlog.w(_tag, 'RUN_FINISHED 缺少 result(messageUuid): $data');
          }
        case 'RUN_ERROR':
          yield ChatErrorEvent(json?['message'] as String? ?? 'AI 服务异常');
        case 'CUSTOM':
          // 用户主动打断:AG-UI 词汇无对应事件,后端走 CUSTOM(name=chat.paused)。
          if (json?['name'] == 'chat.paused') {
            final value = json?['value'];
            if (value is Map<String, dynamic>) {
              yield ChatPausedEvent(
                requestId: value['requestId'] as String?,
                messageUuid: value['messageUuid'] as String?,
              );
            } else {
              yield const ChatPausedEvent();
            }
          }
        // TEXT_MESSAGE_START/END、RUN_STARTED、STEP_*、TOOL_CALL_RESULT 等
        // 事件对块序列渲染无用,静默忽略。
      }
    }

    Stream<ChatStreamEvent> parseLine(String line) async* {
      if (line.isEmpty) {
        yield* emitCurrentEvent();
        return;
      }

      if (line.startsWith(':')) {
        return;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        return;
      }

      if (line.startsWith('data:')) {
        final value = line.substring(5);
        dataLines.add(value);
      }
    }

    try {
      await for (final textChunk in utf8.decoder.bind(rawStream)) {
        if (cancelToken != null && cancelToken.isCancelled) break;

        lineBuffer.write(textChunk);
        final merged = lineBuffer.toString();
        final lines = merged.split(RegExp(r'\r?\n'));
        lineBuffer
          ..clear()
          ..write(lines.removeLast());

        for (final line in lines) {
          await for (final event in parseLine(line)) {
            yield event;
          }
        }
      }

      if (lineBuffer.isNotEmpty) {
        await for (final event in parseLine(lineBuffer.toString())) {
          yield event;
        }
      }

      await for (final event in emitCurrentEvent()) {
        yield event;
      }
    } catch (e) {
      if (cancelToken != null && cancelToken.isCancelled) {
        return;
      }
      PMlog.e(_tag, 'SSE 流读取异常: $e');
      yield ChatErrorEvent(e.toString());
    }
  }

  /// 仅供测试使用：直接解析原始 SSE 字节流。
  Stream<ChatStreamEvent> parseForTest(
    Stream<List<int>> rawStream,
    CancelToken? cancelToken,
  ) => _parseSseStream(rawStream, cancelToken);
}
