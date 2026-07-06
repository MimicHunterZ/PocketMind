import 'dart:convert';

import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/model/chat_message.dart';

/// 直播态调试预览用的固定剧本：文本 → 工具调用 → 文本 → A2UI 卡片。
///
/// [buildChatStreamingMockEvents] 逐块吐出 SSE 事件模拟直播过程；
/// [buildChatStreamingMockFinalMessages] 吐出与剧本内容一致的持久化消息，
/// 流结束后落库，验证"直播最终态"和"历史里的最终态"一致。

const String _text1 = '好的，我先搜一下相关记忆。';
const String _text2 = '找到了，给你一张卡片。';
const String _toolCallId = 'mock-call-1';
const String _toolName = 'searchMemory';
const String _toolArguments = '{"query":"上次讨论的方案"}';
const String _toolResult = '命中 3 条相关记忆';
const String _surfaceId = 'streaming-mock-card';
const String _standardCatalogId =
    'https://a2ui.org/specification/v0_9/standard_catalog.json';

List<String> _chatStreamingMockA2uiChunks() => [
  jsonEncode({
    'version': 'v0.9',
    'createSurface': {'surfaceId': _surfaceId, 'catalogId': _standardCatalogId},
  }),
  jsonEncode({
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': _surfaceId,
      'components': [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['streamCard'],
        },
        {'id': 'streamCard', 'component': 'Card', 'child': 'streamColumn'},
        {
          'id': 'streamColumn',
          'component': 'Column',
          'children': ['streamTitle', 'streamBody'],
          'align': 'stretch',
        },
        {
          'id': 'streamTitle',
          'component': 'Text',
          'text': '直播搭建的卡片',
          'variant': 'h4',
        },
        {'id': 'streamBody', 'component': 'Text', 'text': {'path': '/body'}},
      ],
    },
  }),
  jsonEncode({
    'version': 'v0.9',
    'updateDataModel': {
      'surfaceId': _surfaceId,
      'path': '/body',
      'value': '这条卡片是随 A2UI 分片逐步到达搭建起来的，不是一次性出现的。',
    },
  }),
];

/// 逐块吐出这一轮直播的 SSE 事件：先一段文本，再一次工具调用，再一段文本，
/// 最后一张分片到达的 A2UI 卡片，用固定小延时模拟真实网络的逐步到达。
Stream<ChatStreamEvent> buildChatStreamingMockEvents({
  String? requestId,
  Duration tick = const Duration(milliseconds: 90),
}) async* {
  Future<void> wait() => Future<void>.delayed(tick);

  for (final delta in _chunkText(_text1)) {
    yield ChatDeltaEvent(delta);
    await wait();
  }

  yield const ChatToolCallStartEvent(_toolCallId, _toolName);
  await wait();
  yield const ChatToolCallEndEvent(_toolCallId);
  await wait();

  for (final delta in _chunkText(_text2)) {
    yield ChatDeltaEvent(delta);
    await wait();
  }

  for (final chunk in _chatStreamingMockA2uiChunks()) {
    yield ChatA2uiChunkEvent(chunk);
    await wait();
  }

  yield ChatDoneEvent('mock-assistant-turn', requestId: requestId);
}

List<String> _chunkText(String text, {int chunkSize = 3}) {
  final chunks = <String>[];
  for (var i = 0; i < text.length; i += chunkSize) {
    chunks.add(text.substring(i, (i + chunkSize).clamp(0, text.length)));
  }
  return chunks;
}

/// 与 [buildChatStreamingMockEvents] 剧本一致的持久化消息，流结束后落库。
/// [turn] 用于生成跨多轮发送互不冲突的 uuid；[parentUuid] 是这一轮第一条
/// 消息要接上的、当前会话已有的最后一条消息 uuid（null = 会话还没有消息）。
List<ChatMessage> buildChatStreamingMockFinalMessages({
  required String sessionUuid,
  required int turn,
  required String userContent,
  String? parentUuid,
}) {
  String uuidOf(String suffix) => 'mock-turn-$turn-$suffix';

  final messages = [
    _textMessage(sessionUuid, uuidOf('user'), 'USER', userContent),
    _textMessage(sessionUuid, uuidOf('text1'), 'ASSISTANT', _text1),
    _toolCallMessage(sessionUuid, uuidOf('call')),
    _toolResultMessage(sessionUuid, uuidOf('result')),
    _textMessage(sessionUuid, uuidOf('text2'), 'ASSISTANT', _text2),
    _a2uiCardMessage(sessionUuid, uuidOf('card')),
  ];

  var previousUuid = parentUuid;
  for (final message in messages) {
    message.parentUuid = previousUuid;
    previousUuid = message.uuid;
  }
  return messages;
}

ChatMessage _textMessage(
  String sessionUuid,
  String uuid,
  String role,
  String content,
) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = role
    ..messageType = 'TEXT'
    ..content = content;
}

ChatMessage _toolCallMessage(String sessionUuid, String uuid) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_CALL'
    ..messageType = 'TOOL_CALL'
    ..content = jsonEncode({
      'toolCallId': _toolCallId,
      'name': _toolName,
      'arguments': _toolArguments,
    });
}

ChatMessage _toolResultMessage(String sessionUuid, String uuid) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content = jsonEncode({
      'toolCallId': _toolCallId,
      'name': _toolName,
      'result': _toolResult,
    });
}

ChatMessage _a2uiCardMessage(String sessionUuid, String uuid) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content = jsonEncode(
      _chatStreamingMockA2uiChunks().map(jsonDecode).toList(),
    );
}
