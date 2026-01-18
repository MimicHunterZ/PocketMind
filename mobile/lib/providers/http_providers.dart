import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/providers/app_config_provider.dart';

part 'http_providers.g.dart';

/// HttpClient Provider
///
/// 提供全局单例的 HTTP 客户端，会根据环境配置自动设置 baseUrl
@Riverpod(keepAlive: true)
HttpClient httpClient(Ref ref) {
  final httpClient = HttpClient();
  // 从 AppConfig 获取当前环境的 baseUrl
  final config = ref.watch(appConfigProvider);
  httpClient.dio.options.baseUrl = config.baseUrl;
  return httpClient;
}
