import 'package:dio/dio.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/sync/model/sync_dto.dart';

/// 同步 HTTP 服务 —— 封装 Pull/Push 两个端点。
///
/// 职责：纯粹的网络层，不包含任何业务逻辑。
/// [PullCoordinator] 和 [PushCoordinator] 通过此类与后端通信。
class SyncApiService {
  final HttpClient _client;

  SyncApiService(this._client);

  /// 增量拉取（GET /api/sync/pull?sinceVersion={version}&pageSize={pageSize}）
  ///
  /// [sinceVersion] 为 0 时触发全量拉取（首次登录新设备）。
  /// 后端保证返回 serverVersion > sinceVersion 的所有变更，按 serverVersion 升序。
  Future<SyncPullResponse> pull({
    required int sinceVersion,
    int pageSize = 200,
  }) async {
    // _client.get<T>() 经拦截器解包后直接返回 ApiResponse.data 的值，
    // 即 {serverVersion, hasMore, changes}，而非 Dio Response 对象。
    final data = await _client.get<Map<String, dynamic>>(
      ApiConstants.syncPull,
      queryParameters: {'sinceVersion': sinceVersion, 'pageSize': pageSize},
    );
    return SyncPullResponse.fromJson(data);
  }

  /// 批量推送本地变更（POST /api/sync/push）
  ///
  /// 后端以 [SyncMutationDto.mutationId] 去重（幂等），
  /// 返回每条变更的接受/拒绝结果。
  Future<List<SyncPushResult>> push(SyncPushRequest request) async {
    // 拦截器解包后 response.data 即为 List，_client.post<T>() 直接返回该 List。
    final list = await _client.post<List<dynamic>>(
      ApiConstants.syncPush,
      data: request.toJson(),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return list
        .map((e) => SyncPushResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
