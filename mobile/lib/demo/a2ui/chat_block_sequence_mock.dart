import 'dart:convert';

import 'package:pocketmind/model/chat_message.dart';

/// 块序列渲染(文本 + 工具卡片 + A2UI 卡片混排)的固定 mock 消息集,供
/// widget 测试和 debug 预览页共用同一份数据,保证"测试验证过的东西"和
/// "人工看到的效果"是同一份东西。
///
/// 消息顺序即时间轴顺序(升序):前面是纯文本填充的历史消息,最后 8 条是
/// 一轮完整对话——文本、工具调用/结果、两张独立 A2UI 卡片。
List<ChatMessage> buildChatBlockSequenceMockMessages(String sessionUuid) {
  final messages = <ChatMessage>[];
  for (var i = 0; i < 30; i++) {
    messages.add(
      _textMessage(
        sessionUuid,
        'filler-${i.toString().padLeft(2, '0')}',
        i.isEven ? 'USER' : 'ASSISTANT',
        '这是第 $i 条历史消息,用来把列表撑高触发虚拟化。',
      ),
    );
  }
  messages.addAll([
    _textMessage(sessionUuid, 'm-01', 'USER', '帮我查一下上次讨论的方案,再展开讲讲'),
    _textMessage(sessionUuid, 'm-02', 'ASSISTANT', '好的,我先搜一下相关记忆。'),
    _toolCallMessage(sessionUuid, 'm-03'),
    _toolResultMessage(sessionUuid, 'm-04'),
    _textMessage(sessionUuid, 'm-05', 'ASSISTANT', '找到了,给你一张选择卡片。'),
    _choiceCardMessage(sessionUuid, 'm-06'),
    _textMessage(sessionUuid, 'm-07', 'ASSISTANT', '再补充第二张卡片作为对照。'),
    _infoCardMessage(sessionUuid, 'm-08'),
  ]);
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
    ..content =
        '{"toolCallId":"call_1","name":"searchMemory","arguments":"{\\"query\\":\\"上次讨论的方案\\"}"}';
}

ChatMessage _toolResultMessage(String sessionUuid, String uuid) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content =
        '{"toolCallId":"call_1","name":"searchMemory","result":"命中 3 条相关记忆"}';
}

const String _standardCatalogId =
    'https://a2ui.org/specification/v0_9/standard_catalog.json';

/// A2UI 卡片一:带 [ChoicePicker] + [Button] 的可交互选择卡片,套在
/// [Card] 组件里(不是裸 Text),这样在消息列表里能一眼看出"这是一张卡片"
/// 而不是普通文字。
ChatMessage _choiceCardMessage(String sessionUuid, String uuid) {
  const surfaceId = 'choice-card';
  final operations = [
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': surfaceId, 'catalogId': _standardCatalogId},
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['choiceCard'],
          },
          {'id': 'choiceCard', 'component': 'Card', 'child': 'choiceColumn'},
          {
            'id': 'choiceColumn',
            'component': 'Column',
            'children': ['choiceTitle', 'topicPicker', 'deepButton'],
            'align': 'stretch',
          },
          {
            'id': 'choiceTitle',
            'component': 'Text',
            'text': '想深入哪个方向?',
            'variant': 'h4',
          },
          {
            'id': 'topicPicker',
            'component': 'ChoicePicker',
            'label': '深入方向',
            'variant': 'mutuallyExclusive',
            'value': {'path': '/choice/topic'},
            'options': [
              {'label': '热修复原理', 'value': '热修复原理'},
              {'label': '自定义 ClassLoader', 'value': '自定义 ClassLoader'},
            ],
          },
          {
            'id': 'deepButton',
            'component': 'Button',
            'variant': 'primary',
            'child': 'deepButtonLabel',
            'action': {
              'event': {
                'name': 'deep_dive',
                'context': {
                  'topic': {'path': '/choice/topic'},
                },
              },
            },
          },
          {'id': 'deepButtonLabel', 'component': 'Text', 'text': '展开讲解'},
        ],
      },
    },
  ];
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content = jsonEncode(operations);
}

/// A2UI 卡片二:另一个独立 surfaceId 的静态信息卡片(同样套 [Card] 组件),
/// 用来验证同屏多条 Surface 不互相干扰。
ChatMessage _infoCardMessage(String sessionUuid, String uuid) {
  const surfaceId = 'info-card';
  final operations = [
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': surfaceId, 'catalogId': _standardCatalogId},
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['infoCard'],
          },
          {'id': 'infoCard', 'component': 'Card', 'child': 'infoColumn'},
          {
            'id': 'infoColumn',
            'component': 'Column',
            'children': ['infoTitle', 'infoBody'],
            'align': 'stretch',
          },
          {
            'id': 'infoTitle',
            'component': 'Text',
            'text': '第二张卡片',
            'variant': 'h4',
          },
          {
            'id': 'infoBody',
            'component': 'Text',
            'text': {'path': '/body'},
          },
        ],
      },
    },
    {
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': surfaceId,
        'path': '/body',
        'value': '用来验证同屏多条 Surface 互不干扰,这张不带交互组件。',
      },
    },
  ];
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'TOOL_RESULT'
    ..messageType = 'TOOL_RESULT'
    ..content = jsonEncode(operations);
}
