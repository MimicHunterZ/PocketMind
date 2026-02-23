import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/models/post_detail_response.dart';
import 'package:pocketmind/util/logger_service.dart';

const String _tag = 'PostDetailService';

/// 帖子详情查询与 AI 分析结果轮询服务。
///
/// 通过 GET /api/post/{uuid} 获取笔记状态，
/// [pollUntilComplete] 持续轮询直到 aiStatus 达到终态。
class PostDetailService {
  final HttpClient _http;

  PostDetailService(this._http);

  /// 单次获取帖子详情。
  Future<PostDetailResponse> fetchPost(String uuid) async {
    final data = await _http.get<Map<String, dynamic>>(
      '${ApiConstants.postDetail}/$uuid',
    );
    return PostDetailResponse.fromJson(data);
  }

  /// 轮询直到 AI 分析完成（COMPLETED 或 FAILED）或超时。
  ///
  /// [timeout] 最长等待时间，默认 3 分钟
  /// [interval] 轮询间隔，默认 3 秒
  /// 返回最终的 [PostDetailResponse]（无论成功或失败）。
  Future<PostDetailResponse> pollUntilComplete(
    String uuid, {
    Duration timeout = const Duration(minutes: 3),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);

    PMlog.d(_tag, '开始轮询 AI 分析结果: uuid=$uuid');

    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await fetchPost(uuid);

        PMlog.d(_tag, '轮询中: uuid=$uuid, aiStatus=${result.aiStatus}');

        if (!result.isProcessing) {
          PMlog.d(_tag, '轮询结束: uuid=$uuid, aiStatus=${result.aiStatus}');
          return result;
        }

        await Future.delayed(interval);
      } catch (e) {
        // 单次请求失败时记录日志，继续轮询
        PMlog.e(_tag, '轮询请求失败: uuid=$uuid, e=$e');
        await Future.delayed(interval);
      }
    }

    // 超时：返回最后一次成功的结果（如有），否则抛出
    PMlog.w(_tag, '轮询超时: uuid=$uuid');
    return await fetchPost(uuid);
  }
}
