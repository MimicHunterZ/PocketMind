import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';

import '../util/logger_service.dart';

part 'note_api_service.g.dart';

/// 笔记 API 服务 Provider - 全局单例
@Riverpod(keepAlive: true)
NoteApiService noteApiService(Ref ref) {
  // 确保 AuthController 已初始化（Token 已设置）
  ref.watch(authControllerProvider);
  // 从 ref 中获取统一的 httpClient
  final httpClient = ref.watch(httpClientProvider);
  return NoteApiService(httpClient);
}

final String tag = 'NoteApiService';

/// AI 分析响应 DTO
///
/// 两种模式的响应格式：
/// - SUMMARY 模式：aiResponse 为对象 `{ summary: String, tags: List }`
/// - QA 模式：aiResponse 为字符串（AI 回答内容）
class AiAnalyzeResponse {
  final String mode;
  final String? userQuestion;
  final dynamic aiResponse;

  AiAnalyzeResponse({
    required this.mode,
    this.userQuestion,
    required this.aiResponse,
  });

  factory AiAnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AiAnalyzeResponse(
      mode: json['mode'] as String,
      userQuestion: json['userQuestion'] as String?,
      aiResponse: json['aiResponse'],
    );
  }

  /// 是否为问答模式
  bool get isQaMode => mode == 'QA';

  /// 是否为总结模式
  bool get isSummaryMode => mode == 'SUMMARY';

  /// 获取总结内容（SUMMARY 模式）
  String? get summary {
    if (!isSummaryMode || aiResponse == null) return null;
    if (aiResponse is Map<String, dynamic>) {
      return aiResponse['summary'] as String?;
    }
    return null;
  }

  /// 获取标签列表（SUMMARY 和 QA 模式）
  List<String> get tags {
    if (aiResponse == null) return [];
    if (aiResponse is Map<String, dynamic>) {
      // 兼容 SUMMARY 和 QA 两种结构的 tags 字段
      final tagList = aiResponse['tags'];
      if (tagList is List) {
        return tagList.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  /// 获取问答回复（QA 模式）
  String? get qaAnswer {
    if (!isQaMode || aiResponse == null) return null;
    if (aiResponse is Map<String, dynamic>) {
       return aiResponse['answer'] as String?;
    }
    return null;
  }

  /// 获取用于存储的摘要字符串
  /// - SUMMARY 模式：返回 summary
  /// - QA 模式：返回格式化的问答内容
  String? get displayContent {
    if (isSummaryMode) {
      return summary;
    } else if (isQaMode) {
      return 'Q: ${userQuestion ?? ""} \n\nA: ${qaAnswer ?? ""}';
    }
    return null;
  }
}

class NoteApiService {
  final HttpClient _http;
  NoteApiService(this._http);

  /// AI 分析内容
  ///
  /// [uuid] 笔记的唯一标识
  /// [title] 笔记标题
  /// [content] 笔记内容（Markdown 格式）
  /// [userQuestion] 用户问题（可选，为空时执行内容总结，有值时执行问答模式）
  ///
  /// 返回 AI 分析结果
  Future<AiAnalyzeResponse> analyzeContent({
    required String uuid,
    String? title,
    required String content,
    String? userQuestion,
  }) async {
    final hasQuestion = userQuestion != null && userQuestion.isNotEmpty;
    PMlog.d(tag, '开始 AI 分析 - uuid: $uuid, hasQuestion: $hasQuestion');

    // 注意：_http.post 根据拦截器处理已解包返回 Result.data (即 Map<String, dynamic>)
    final data = await _http.post<Map<String, dynamic>>(
      ApiConstants.aiAnalyze,
      data: {
        'uuid': uuid,
        'title': title,
        'content': content,
        'userQuestion': userQuestion,
      },
    );

    PMlog.d(tag, 'AI 分析完成 - mode: ${data['mode']}');
    return AiAnalyzeResponse.fromJson(data);
  }
}
