/// 统一导出所有 Providers
///
/// 使用方式：
/// ```dart
/// import 'package:pocketmind/providers/providers.dart';
/// ```
///
/// 这样可以一次性导入所有常用的 providers
library;

// Infrastructure Providers
export 'infrastructure_providers.dart';

// HTTP Providers
export 'http_providers.dart';

// Category Providers
export 'category_providers.dart';

// Note Providers
export 'note_providers.dart';

// Navigation Providers
export 'nav_providers.dart';

// UI Providers
export 'ui_providers.dart';

// Chat Providers
export 'chat_providers.dart';

// 注意：sync_service 和 API service providers 通常在各自的模块中使用
// 如需使用，请单独导入：
// import 'package:pocketmind/sync/sync_service.dart';
// import 'package:pocketmind/api/note_api_service.dart';
