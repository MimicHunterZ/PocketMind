import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show A2uiMessage, basicCatalogId;
import 'package:pocketmind/page/chat/widgets/chat_message_widgets.dart';
import 'package:pocketmind/util/a2ui_card_util.dart';

const String _surfaceId = 'open-note-function-demo';

/// 验证 `OpenNoteFunction`(本地 `functionCall`,注册进
/// `pocketMindA2uiCatalog`)真的生效:点击列表项应该本地跳转到笔记详情页,
/// 不发任何网络请求、不触发 `onSubmitted`。
class OpenNoteFunctionDemoPage extends StatelessWidget {
  const OpenNoteFunctionDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('openNote 本地函数验证')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: A2uiCardMessage(operations: _operations()),
      ),
    );
  }

  List<A2uiMessage> _operations() {
    final raw = [
      {
        'version': 'v0.9',
        'createSurface': {'surfaceId': _surfaceId, 'catalogId': basicCatalogId},
      },
      {
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': _surfaceId,
          'components': [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['title', 'note1Button', 'note2Button'],
              'align': 'stretch',
            },
            {
              'id': 'title',
              'component': 'Text',
              'text': '点击笔记跳转详情页(本地 functionCall,不联网)',
              'variant': 'h4',
            },
            {
              'id': 'note1Button',
              'component': 'Button',
              'variant': 'primary',
              'child': 'note1Label',
              'action': {
                'functionCall': {
                  'call': 'openNote',
                  'args': {
                    'noteUuid': 'demo-note-1',
                    'title': '示例笔记 A',
                    'content': '这是 openNote 本地函数验证用的示例内容 A。',
                  },
                },
              },
            },
            {'id': 'note1Label', 'component': 'Text', 'text': '打开《示例笔记 A》'},
            {
              'id': 'note2Button',
              'component': 'Button',
              'child': 'note2Label',
              'action': {
                'functionCall': {
                  'call': 'openNote',
                  'args': {
                    'noteUuid': 'demo-note-2',
                    'title': '示例笔记 B',
                    'content': '这是 openNote 本地函数验证用的示例内容 B。',
                  },
                },
              },
            },
            {'id': 'note2Label', 'component': 'Text', 'text': '打开《示例笔记 B》'},
          ],
        },
      },
    ];
    return tryParseA2uiCard(jsonEncode(raw))!;
  }
}
