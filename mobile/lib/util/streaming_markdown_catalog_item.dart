import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// 自定义 A2UI 组件:流式 Markdown 文本块。
///
/// 设计要点:
/// - `text` 字段支持 path 绑定(`{"path": "/xxx"}`)。后端通过 `updateDataModel`
///   不断把「累积到当前的全量文本」写入该 path,组件即随之重建并渲染当前全文。
/// - 流式观感来自「数据帧的到达节奏」(每帧累积全文),组件收到即渲染,不再叠加
///   组件内部的打字动画。这样「数据发完」与「画面渲染完」严格同步,避免后续组件
///   (如按钮)在文字尚未显示完时就出现。
/// - 与 A2UI 协议解耦:后端只需发 `{"component": "StreamingMarkdown", ...}`,
///   无需关心客户端用哪个 Markdown 渲染器。
///
/// 真后端对接契约:在自定义 catalog 的 `catalogId` 下注册同名组件即可,
/// 帧结构与基础 catalog 中的 `Text` 完全一致。

/// 组件名,后端 `updateComponents` 帧中的 `component` 字段需与此一致。
const String streamingMarkdownComponentName = 'StreamingMarkdown';

extension type _StreamingMarkdownData.fromMap(JsonMap _json) {
  Object get text => _json['text'] as Object;
}

final CatalogItem streamingMarkdown = CatalogItem(
  name: streamingMarkdownComponentName,
  dataSchema: S.object(
    description: '一个流式渲染的 Markdown 文本块。后端持续向其绑定的 path 写入累积全文即可实现流式输出。',
    properties: {
      'text': A2uiSchemas.stringReference(
        description: '要渲染的 Markdown 文本。支持 path 绑定以实现流式更新;每次更新应为前一次的前缀延长(累积全文)。',
      ),
    },
    required: ['text'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "StreamingMarkdown",
          "text": {"path": "/answer"}
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = _StreamingMarkdownData.fromMap(itemContext.data as JsonMap);

    return BoundString(
      dataContext: itemContext.dataContext,
      value: data.text,
      builder: (context, value) {
        // 关键:关闭组件内部的逐字打字动画。
        //
        // 流式观感由数据帧的到达节奏提供(后端/mock 每帧推送累积全文),组件
        // 收到即渲染。若再开启内部打字动画,会形成「数据时钟」与「动画时钟」
        // 两个独立计时器赛跑:动画落后于数据,导致后续组件(如按钮)在文字
        // 尚未显示完时就出现。关掉它,数据到达即渲染,二者严格同步。
        return StreamingTextMarkdown(
          text: value ?? '',
          markdownEnabled: true,
          animationsEnabled: false,
          padding: EdgeInsets.zero,
        );
      },
    );
  },
);

/// 把自定义组件并入基础 catalog。
///
/// 注意:A2UI 客户端按 `catalogId` 匹配 catalog,因此必须把自定义组件
/// 合并进与基础 catalog 相同的 `catalogId`,而不是新建一个并列 catalog。
Catalog buildAppCatalog() {
  return BasicCatalogItems.asCatalog().copyWith(
    newItems: [streamingMarkdown],
  );
}
