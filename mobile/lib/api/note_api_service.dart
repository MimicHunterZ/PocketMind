import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';

import '../util/logger_service.dart';

part 'note_api_service.g.dart';

/// 笔记 AI 分析提交服务 Provider
@Riverpod(keepAlive: true)
NoteApiService noteApiService(Ref ref) {
  ref.watch(authControllerProvider);
  final httpClient = ref.watch(httpClientProvider);
  return NoteApiService(httpClient);
}

const String _tag = 'NoteApiService';

/// 笔记 AI 分析提交服务。
///
/// 调用 POST /api/ai/analyze 提交分析任务（202 Accepted 异步模式），
/// 结果通过 [PostDetailService.pollUntilComplete] 轮询获取。
class NoteApiService {
  final HttpClient _http;
  NoteApiService(this._http);

  /// 提交 AI 分析任务。
  ///
  /// - 客户端已抓取内容（小红书等）→ 传 [previewContent]，后端直接分析
  /// - 通用网址 → 仅传 [url]，后端自行抓取并分析
  Future<void> submitAnalysis({
    required String uuid,
    required String url,
    String? previewTitle,
    String? previewContent,
    String? userQuestion,
  }) async {
    final hasContent = previewContent != null && previewContent.isNotEmpty;
    PMlog.d(_tag, '提交 AI 分析: uuid=$uuid, hasContent=$hasContent');

    await _http.post<Map<String, dynamic>>(
      ApiConstants.aiAnalyze,
      data: {
        'uuid': uuid,
        'url': url,
        if (previewTitle != null) 'previewTitle': previewTitle,
        if (previewContent != null) 'previewContent': previewContent,
        if (userQuestion != null) 'userQuestion': userQuestion,
      },
    );

    PMlog.d(_tag, 'AI 分析已提交: uuid=$uuid');
  }
}
