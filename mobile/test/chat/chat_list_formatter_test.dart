import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_formatter.dart';
import 'package:pocketmind/page/chat/chat_list/chat_list_item.dart';
import 'package:pocketmind/providers/chat_providers.dart';

ChatMessage _msg(String uuid, String role, {String messageType = 'TEXT'}) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = 's-1'
    ..role = role
    ..messageType = messageType
    ..content = uuid;
}

const String _standardCatalogId =
    'https://a2ui.org/specification/v0_9/standard_catalog.json';

ChatMessage _cardMsg(String uuid, String surfaceId) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = 's-1'
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content = jsonEncode({
      'version': 'v0.9',
      'createSurface': {'surfaceId': surfaceId, 'catalogId': _standardCatalogId},
    });
}

ChatMessage _submissionMsg(
  String uuid,
  String surfaceId,
  Map<String, dynamic> dataModel,
) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = 's-1'
    ..role = 'USER'
    ..messageType = 'TEXT'
    ..content = jsonEncode({'surfaceId': surfaceId, 'dataModel': dataModel});
}

List<ChatListMessageItem> _messageItems(List<ChatMessage> messages) {
  return buildChatListItems(messages: messages, sendState: const ChatSendState.idle())
      .whereType<ChatListMessageItem>()
      .toList();
}

void main() {
  group('buildChatListItems isLastOfTurn', () {
    test('单轮纯文本对话:USER 不是 turn 结尾,ASSISTANT 回复是', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _msg('a1', 'ASSISTANT'),
      ]);
      expect(items.map((e) => e.message.uuid), ['u1', 'a1']);
      expect(items[0].isLastOfTurn, isFalse);
      expect(items[1].isLastOfTurn, isTrue);
    });

    test('一轮回复拆成文本+工具调用+文本+卡片:只有最后一块 isLastOfTurn=true', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _msg('a1', 'ASSISTANT'),
        _msg('call1', 'TOOL_CALL', messageType: 'TOOL_CALL'),
        _msg('result1', 'TOOL_RESULT', messageType: 'TOOL_RESULT'),
        _msg('a2', 'ASSISTANT'),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['u1']!.isLastOfTurn, isFalse);
      expect(byUuid['a1']!.isLastOfTurn, isFalse);
      expect(byUuid['call1']!.isLastOfTurn, isFalse);
      expect(byUuid['result1']!.isLastOfTurn, isFalse);
      expect(byUuid['a2']!.isLastOfTurn, isTrue);
    });

    test('两轮对话:每一轮各自的最后一块都是 isLastOfTurn=true', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _msg('a1', 'ASSISTANT'),
        _msg('u2', 'USER'),
        _msg('call2', 'TOOL_CALL', messageType: 'TOOL_CALL'),
        _msg('a2', 'ASSISTANT'),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['a1']!.isLastOfTurn, isTrue);
      expect(byUuid['call2']!.isLastOfTurn, isFalse);
      expect(byUuid['a2']!.isLastOfTurn, isTrue);
      expect(byUuid['u1']!.isLastOfTurn, isFalse);
      expect(byUuid['u2']!.isLastOfTurn, isFalse);
    });

    test('一轮以卡片(TOOL_RESULT)结束:卡片本身 isLastOfTurn=true', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _msg('a1', 'ASSISTANT'),
        _msg('card1', 'TOOL_RESULT', messageType: 'TOOL_RESULT'),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['a1']!.isLastOfTurn, isFalse);
      expect(byUuid['card1']!.isLastOfTurn, isTrue);
    });
  });

  group('buildChatListItems 卡片提交锁定(D15)', () {
    test('卡片后面有对应 surfaceId 的提交交互消息 → lockedDataModel 非空', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _cardMsg('card1', 'surface-a'),
        _submissionMsg('sub1', 'surface-a', {
          'choice': {'topic': 'B'},
        }),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['card1']!.lockedDataModel, {
        'choice': {'topic': 'B'},
      });
    });

    test('卡片没有对应的提交交互消息 → lockedDataModel 为 null', () {
      final items = _messageItems([
        _msg('u1', 'USER'),
        _cardMsg('card1', 'surface-a'),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['card1']!.lockedDataModel, isNull);
    });

    test('两张卡片各自 surfaceId 独立:只有匹配的那张锁定', () {
      final items = _messageItems([
        _cardMsg('card1', 'surface-a'),
        _cardMsg('card2', 'surface-b'),
        _submissionMsg('sub1', 'surface-a', {'x': 1}),
      ]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['card1']!.lockedDataModel, {'x': 1});
      expect(byUuid['card2']!.lockedDataModel, isNull);
    });

    test('普通文本消息不受影响,lockedDataModel 始终为 null', () {
      final items = _messageItems([_msg('u1', 'USER'), _msg('a1', 'ASSISTANT')]);
      final byUuid = {for (final item in items) item.message.uuid: item};
      expect(byUuid['u1']!.lockedDataModel, isNull);
      expect(byUuid['a1']!.lockedDataModel, isNull);
    });
  });
}
