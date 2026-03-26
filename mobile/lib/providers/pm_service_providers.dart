import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/asset_api_service.dart';
import 'package:pocketmind/api/auth_pm_service.dart';
import 'package:pocketmind/api/post_detail_service.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/service/ai_polling_service.dart';

part 'pm_service_providers.g.dart';

@Riverpod(keepAlive: true)
AuthPmService authPmService(Ref ref) {
  final http = ref.watch(httpClientProvider);
  return AuthPmService(http);
}

@Riverpod(keepAlive: true)
AssetApiService assetApiService(Ref ref) {
  final http = ref.watch(httpClientProvider);
  return AssetApiService(http);
}

@Riverpod(keepAlive: true)
PostDetailService postDetailService(Ref ref) {
  final http = ref.watch(httpClientProvider);
  return PostDetailService(http);
}

@Riverpod(keepAlive: true)
AiPollingService aiPollingService(Ref ref) {
  return AiPollingService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(noteServiceProvider),
    ref.watch(postDetailServiceProvider),
  );
}
