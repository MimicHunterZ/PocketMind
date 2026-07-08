import 'dart:convert';

import 'package:genui/genui.dart';

/// 判别一条 `TOOL_RESULT` 消息的 [content] 是否是 A2UI 卡片,并解析出这张
/// 卡片的完整操作序列。
///
/// 一张卡片通常需要 `createSurface` + `updateComponents` + `updateDataModel`
/// 三条消息才能描述完整界面,因此 [content] 落库形状既支持单条 A2UI 消息
/// JSON,也支持这类消息组成的 JSON 数组,数组顺序即渲染顺序。
///
/// 后端落库的 `TOOL_RESULT` content 是一层工具结果包装
/// `{"toolCallId":...,"name":...,"result": "<A2UI envelope 的 JSON 字符串>"}`
/// (见 `PersistingToolCallAdvisor.toToolResultJson`)。而流式 `ACTIVITY_SNAPSHOT`
/// 送来的是裸 envelope。这里先剥掉这层包装(若存在),再判别,让 reload 复现
/// 的卡片和流式态走同一条判别路径——否则 reload 时卡片会因判别失败退化成
/// 普通工具卡。**注意不能改用 API 层 `toolData.result` 字段:后端对它做了
/// 500 字符截断,envelope 超长会拿到坏 JSON,必须用完整 content。**
///
/// 解析失败(非 JSON、或任意一条不满足 A2UI 消息结构)说明是普通工具结果,
/// 应渲染为 `ChatToolCallCard`。不依赖任何额外的类型标记字段。
List<A2uiMessage>? tryParseA2uiCard(String content) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    return null;
  }

  // 先剥工具结果包装:content 形如 {toolCallId,name,result} 且 result 是
  // 字符串时,真正的 envelope 藏在 result 里(再解析一层)。剥不出来就按原样
  // 判别(兼容裸 envelope)。
  decoded = _unwrapToolResult(decoded) ?? decoded;

  final List<Object?> rawMessages;
  if (decoded is Map<String, dynamic>) {
    rawMessages = [decoded];
  } else if (decoded is List<Object?>) {
    rawMessages = decoded;
  } else {
    return null;
  }
  if (rawMessages.isEmpty) return null;

  final messages = <A2uiMessage>[];
  for (final raw in rawMessages) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      messages.add(A2uiMessage.fromJson(raw));
    } on A2uiValidationException {
      return null;
    }
  }
  return messages;
}

/// 若 [decoded] 是后端的工具结果包装(带 `result` 字符串字段),把 `result`
/// 里嵌套的 JSON 再解析一层返回;否则返回 null(表示不是包装,按原样判别)。
Object? _unwrapToolResult(Object? decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  final result = decoded['result'];
  if (result is! String) return null;
  try {
    return jsonDecode(result);
  } on FormatException {
    return null;
  }
}

/// 取一组 A2UI 操作序列对应的 surfaceId(用于 [SurfaceController.contextFor])。
String a2uiSurfaceId(List<A2uiMessage> messages) {
  final first = messages.first;
  return switch (first) {
    CreateSurface m => m.surfaceId,
    UpdateComponents m => m.surfaceId,
    UpdateDataModel m => m.surfaceId,
    DeleteSurface m => m.surfaceId,
  };
}

/// 尝试把一条消息的 [content] 解析成"卡片提交交互"记录:
/// `{"surfaceId": "...", "dataModel": {...}}`。
///
/// 用户提交卡片交互(点击带 `event` 的按钮)后,以一条新 USER 消息落库,
/// content 是提交那一刻这张卡片完整的 dataModel。卡片是否已锁定,就看
/// 消息列表里有没有一条能解析成功、且 surfaceId 与该卡片匹配的这类消息。
/// 解析失败(非 JSON、形状不对)说明只是一条普通文本消息,返回 null。
({String surfaceId, Map<String, dynamic> dataModel})? tryParseA2uiSubmission(
  String content,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final surfaceId = decoded['surfaceId'];
  final dataModel = decoded['dataModel'];
  if (surfaceId is! String || dataModel is! Map<String, dynamic>) {
    return null;
  }
  return (surfaceId: surfaceId, dataModel: dataModel);
}
