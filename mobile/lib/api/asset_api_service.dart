import 'dart:io';
import 'package:dio/dio.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/api/models/asset_models.dart';
import 'package:pocketmind/util/logger_service.dart';

const String _tag = 'AssetApiService';

/// 图片资产上传及提取结果查询服务。
class AssetApiService {
  final HttpClient _http;

  AssetApiService(this._http);

  /// 上传本地图片到后端。
  Future<UploadResultModel> uploadImage(
    File file, {
    String? noteUuid,
    int sortOrder = 0,
  }) async {
    PMlog.d(
      _tag,
      '开始上传图片: ${file.path}, noteUuid=$noteUuid, sortOrder=$sortOrder',
    );
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final queryParams = <String, dynamic>{};
    if (noteUuid != null) queryParams['noteUuid'] = noteUuid;
    queryParams['sortOrder'] = sortOrder.toString();
    final data = await _http.post<Map<String, dynamic>>(
      ApiConstants.assetsImages,
      data: formData,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final result = UploadResultModel.fromJson(data);
    PMlog.d(
      _tag,
      '图片上传成功: uuid=${result.uuid}, ${result.width}x${result.height}',
    );
    return result;
  }
}
