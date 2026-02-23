import 'package:json_annotation/json_annotation.dart';

part 'chat_models.g.dart';

// ============================================================
// 聊天会话
// ============================================================

/// 聊天会话响应体（对应后端 ChatSessionResponse）
@JsonSerializable()
class ChatSessionModel {
  final String uuid;
  final String? scopeNoteUuid;
  final String? title;

  /// 最后更新时间（毫秒时间戳）
  final int updatedAt;

  const ChatSessionModel({
    required this.uuid,
    this.scopeNoteUuid,
    this.title,
    required this.updatedAt,
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatSessionModelToJson(this);
}

// ============================================================
// 聊天消息
// ============================================================

/// 工具调用元数据（仅 TOOL_CALL / TOOL_RESULT 消息时非 null）
@JsonSerializable()
class ToolCallData {
  /// 工具调用唯一 ID（关联 TOOL_CALL 和 TOOL_RESULT）
  final String? toolCallId;

  /// 工具名称（供 UI 显示）
  final String? toolName;

  /// 参数 JSON 字符串（仅 TOOL_CALL 时有值）
  final String? arguments;

  /// 执行结果（仅 TOOL_RESULT 时有值）
  final String? result;

  const ToolCallData({
    this.toolCallId,
    this.toolName,
    this.arguments,
    this.result,
  });

  factory ToolCallData.fromJson(Map<String, dynamic> json) =>
      _$ToolCallDataFromJson(json);

  Map<String, dynamic> toJson() => _$ToolCallDataToJson(this);
}

/// 聊天消息响应体（对应后端 ChatMessageResponse）
///
/// [messageType] 决定如何渲染：
/// - `TEXT`        普通文本，读 [content]
/// - `TOOL_CALL`   AI 工具调用，读 [toolData]（toolName / arguments）
/// - `TOOL_RESULT` 工具结果，   读 [toolData]（toolName / result）
@JsonSerializable()
class ChatMessageModel {
  final String uuid;
  final String sessionUuid;
  final String? parentUuid;

  /// 角色：USER / ASSISTANT / TOOL_CALL / TOOL_RESULT
  final String role;

  /// 渲染类型：TEXT / TOOL_CALL / TOOL_RESULT
  final String messageType;

  /// 消息内容（TEXT 时为纯文本；工具消息时为原始 JSON）
  final String content;
  final List<String> attachmentUuids;

  /// 创建时间（毫秒时间戳）
  final int createdAt;

  /// 工具调用元数据（仅工具类消息时非 null）
  final ToolCallData? toolData;

  const ChatMessageModel({
    required this.uuid,
    required this.sessionUuid,
    this.parentUuid,
    required this.role,
    required this.messageType,
    required this.content,
    required this.attachmentUuids,
    required this.createdAt,
    this.toolData,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageModelToJson(this);

  bool get isUserMessage => role == 'USER';
  bool get isAssistantMessage => role == 'ASSISTANT';
  bool get isToolCallMessage => messageType == 'TOOL_CALL';
  bool get isToolResultMessage => messageType == 'TOOL_RESULT';
  bool get isTextMessage => messageType == 'TEXT';
}

// ============================================================
// SSE 流式事件（sealed class，Dart 3.x）
// ============================================================

/// AI 流式回复 SSE 事件基类
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// 增量文本片段（event: delta）
final class ChatDeltaEvent extends ChatStreamEvent {
  final String delta;
  const ChatDeltaEvent(this.delta);
}

/// 回复完成（event: done），携带已落库的 ASSISTANT 消息 UUID
final class ChatDoneEvent extends ChatStreamEvent {
  final String messageUuid;
  const ChatDoneEvent(this.messageUuid);
}

/// 错误事件（event: error）
final class ChatErrorEvent extends ChatStreamEvent {
  final String message;
  const ChatErrorEvent(this.message);
}
