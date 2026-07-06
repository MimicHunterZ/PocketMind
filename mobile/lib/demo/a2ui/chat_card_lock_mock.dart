import 'dart:convert';

import 'package:pocketmind/model/chat_message.dart';

/// 卡片交互 + 提交锁定的固定 mock 场景,供 debug 预览页验证:
/// - 卡片一已经有对应的"提交交互"消息,reload 后应该锁定、定格显示。
/// - 卡片二没有,reload 后应该仍可交互。
/// 两张卡片都带三种交互(选方向写本地 dataModel、"查看文档"走本地
/// functionCall、"提交选择"走 event 往返),用来验证这三种交互方式都不
/// 出问题——只有 event 往返才会经 [ChatSendState] 之外的挂点触发提交。

const String _standardCatalogId =
    'https://a2ui.org/specification/v0_9/standard_catalog.json';

List<ChatMessage> buildChatCardLockMockMessages(String sessionUuid) {
  final messages = <ChatMessage>[
    _textMessage(sessionUuid, 'lock-u1', 'USER', '有什么方向可以深入讲讲?'),
    _textMessage(sessionUuid, 'lock-a1', 'ASSISTANT', '给你一张卡片,选一个方向。'),
    _interactiveCardMessage(sessionUuid, 'lock-card-locked', 'lock-demo-locked'),
    _submissionMessage(
      sessionUuid,
      'lock-sub-1',
      surfaceId: 'lock-demo-locked',
      dataModel: {
        'choice': {'topic': '热修复原理'},
      },
    ),
    _textMessage(sessionUuid, 'lock-a2', 'ASSISTANT', '收到,已经记下你的选择。再给你一张新的。'),
    _interactiveCardMessage(sessionUuid, 'lock-card-open', 'lock-demo-open'),
  ];

  String? previousUuid;
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

/// 一张可交互卡片:`topicPicker`(ChoicePicker,本地写 dataModel)、
/// `openDocButton`(functionCall,本地打开,不往返)、`submitButton`
/// (event,触发一次提交往返)。
ChatMessage _interactiveCardMessage(
  String sessionUuid,
  String uuid,
  String surfaceId,
) {
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
            'children': ['lockCard'],
          },
          {'id': 'lockCard', 'component': 'Card', 'child': 'lockColumn'},
          {
            'id': 'lockColumn',
            'component': 'Column',
            'children': [
              'lockTitle',
              'topicPicker',
              'openDocButton',
              'submitButton',
            ],
            'align': 'stretch',
          },
          {
            'id': 'lockTitle',
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
            'id': 'openDocButton',
            'component': 'Button',
            'variant': 'secondary',
            'child': 'openDocLabel',
            'action': {
              'functionCall': {
                'call': 'openUrl',
                'args': {'url': 'https://a2ui.org'},
              },
            },
          },
          {
            'id': 'openDocLabel',
            'component': 'Text',
            'text': '查看相关文档(本地打开,不提交)',
          },
          {
            'id': 'submitButton',
            'component': 'Button',
            'variant': 'primary',
            'child': 'submitLabel',
            'action': {
              'event': {
                'name': 'submit_choice',
                'context': {
                  'topic': {'path': '/choice/topic'},
                },
              },
            },
          },
          {'id': 'submitLabel', 'component': 'Text', 'text': '提交选择'},
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

/// "提交交互"消息(D15):一条 USER 侧 TEXT 消息,content 存
/// `{"surfaceId": ..., "dataModel": ...}`,是卡片锁定与否的唯一判据。
ChatMessage _submissionMessage(
  String sessionUuid,
  String uuid, {
  required String surfaceId,
  required Map<String, dynamic> dataModel,
}) {
  return ChatMessage()
    ..uuid = uuid
    ..sessionUuid = sessionUuid
    ..role = 'USER'
    ..messageType = 'TEXT'
    ..content = jsonEncode({'surfaceId': surfaceId, 'dataModel': dataModel});
}
