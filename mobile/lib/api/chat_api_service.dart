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

  /// 获取会话下的所有消息（按时间正序）。
  Future<List<ChatMessageModel>> listMessages(String sessionUuid) async {
    PMlog.d(_tag, '拉取消息列表: sessionUuid=$sessionUuid');
    final raw = await _http.get<List<dynamic>>(
      ApiConstants.chatMessages(sessionUuid),
    );
    return raw
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 发送用户消息并流式接收 AI 回复。
  ///
  /// 返回 [Stream<ChatStreamEvent>]，包含三种事件：
  /// - [ChatDeltaEvent]  ：AI 回复的增量文本片段
  /// - [ChatDoneEvent]   ：回复完成，携带 ASSISTANT 消息 UUID
  /// - [ChatErrorEvent]  ：AI 服务异常
  ///
  /// 注意：SSE 请求直接使用 Dio 原始实例，绕过 _ApiTransformInterceptor
  /// 的 JSON 解包逻辑（SSE 响应体为 ResponseBody 流，不是 {code,message,data} 格式）。
  Stream<ChatStreamEvent> streamMessage(
    String sessionUuid,
    String content, {
    List<String> attachmentUuids = const [],
    CancelToken? cancelToken,
  }) async* {
    PMlog.d(_tag, '发送消息(SSE): sessionUuid=$sessionUuid, len=${content.length}');

    late final Response<ResponseBody> response;
    try {
      response = await _http.dio.post<ResponseBody>(
        ApiConstants.chatMessages(sessionUuid),
        data: jsonEncode({
          'content': content,
          'attachmentUuids': attachmentUuids,
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

    final rawStream = response.data!.stream;

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
