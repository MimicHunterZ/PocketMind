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
}
