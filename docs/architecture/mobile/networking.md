# Flutter 网络层设计

## 概述

PocketMind 移动端网络层基于 **Dio** 构建,本文档定义网络请求的架构设计和最佳实践。

## 架构分层

```
┌─────────────────────┐
│   UI Layer          │  Widget, Page
├─────────────────────┤
│   Service Layer     │  NoteService, AuthService
├─────────────────────┤
│   API Layer         │  ApiClient, Interceptors
├─────────────────────┤
│   Network Layer     │  Dio
└─────────────────────┘
```

## Dio 配置

### 基础配置

```dart
import 'package:dio/dio.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.pocketmind.app',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
  
  // 添加拦截器
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LoggingInterceptor());
  dio.interceptors.add(ErrorInterceptor());
  
  return dio;
});
```

## 拦截器设计

### AuthInterceptor - 认证拦截器

```dart
class AuthInterceptor extends Interceptor {
  final Ref ref;
  
  AuthInterceptor(this.ref);
  
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. 读取 Token
    final authState = ref.read(authStateProvider);
    if (authState.token != null) {
      options.headers['Authorization'] = 'Bearer ${authState.token}';
    }
    
    // 2. 添加语言 Header
    final locale = ref.read(localeProvider);
    options.headers['Accept-Language'] = locale.languageCode;
    
    // 3. 添加设备信息
    options.headers['X-Device-ID'] = await _getDeviceId();
    
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token 过期,尝试刷新
    if (err.response?.statusCode == 401) {
      try {
        // 刷新 Token
        final newToken = await _refreshToken();
        
        // 重试请求
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newToken';
        
        final response = await Dio().fetch(options);
        handler.resolve(response);
        return;
      } catch (e) {
        // 刷新失败,跳转登录页
        ref.read(authStateProvider.notifier).logout();
      }
    }
    
    handler.next(err);
  }
  
  Future<String> _refreshToken() async {
    final authState = ref.read(authStateProvider);
    final refreshToken = authState.refreshToken;
    
    final response = await Dio().post(
      'https://api.pocketmind.app/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    
    final newToken = response.data['accessToken'];
    final newRefreshToken = response.data['refreshToken'];
    
    // 更新本地 Token
    ref.read(authStateProvider.notifier).updateTokens(
      accessToken: newToken,
      refreshToken: newRefreshToken,
    );
    
    return newToken;
  }
  
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? '';
    }
    return '';
  }
}
```

### LoggingInterceptor - 日志拦截器

```dart
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('→ ${options.method} ${options.uri}');
      print('  Headers: ${options.headers}');
      if (options.data != null) {
        print('  Body: ${options.data}');
      }
    }
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('← ${response.statusCode} ${response.requestOptions.uri}');
      print('  Data: ${response.data}');
    }
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('✗ ${err.requestOptions.uri}');
      print('  Error: ${err.message}');
      if (err.response != null) {
        print('  Status: ${err.response?.statusCode}');
        print('  Data: ${err.response?.data}');
      }
    }
    handler.next(err);
  }
}
```

### ErrorInterceptor - 错误处理拦截器

```dart
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 转换为友好的错误消息
    final friendlyError = _handleError(err);
    
    // 显示错误提示 (通过全局 Provider)
    // ref.read(toastProvider.notifier).showError(friendlyError.message);
    
    handler.next(friendlyError);
  }
  
  DioException _handleError(DioException err) {
    String message;
    
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '网络连接超时,请检查网络设置';
        break;
        
      case DioExceptionType.badResponse:
        message = _parseServerError(err.response);
        break;
        
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
        
      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          message = '无法连接到服务器,请检查网络';
        } else {
          message = '网络错误: ${err.message}';
        }
        break;
        
      default:
        message = '未知错误: ${err.message}';
    }
    
    return DioException(
      requestOptions: err.requestOptions,
      error: message,
      type: err.type,
      response: err.response,
    );
  }
  
  String _parseServerError(Response? response) {
    if (response == null) return '服务器错误';
    
    final statusCode = response.statusCode;
    final data = response.data;
    
    // 解析服务器返回的错误消息
    if (data is Map<String, dynamic> && data.containsKey('message')) {
      return data['message'];
    }
    
    // 根据状态码返回默认消息
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权,请登录';
      case 403:
        return '无权访问此资源';
      case 404:
        return '请求的资源不存在';
      case 500:
        return '服务器内部错误';
      default:
        return '服务器错误 ($statusCode)';
    }
  }
}
```

## API Client 设计

### 通用 API Client

```dart
class ApiClient {
  final Dio _dio;
  
  ApiClient(this._dio);
  
  /// GET 请求
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      
      return parser != null ? parser(response.data) : response.data;
    } on DioException {
      rethrow;
    }
  }
  
  /// POST 请求
  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return parser != null ? parser(response.data) : response.data;
    } on DioException {
      rethrow;
    }
  }
  
  /// PUT 请求
  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return parser != null ? parser(response.data) : response.data;
    } on DioException {
      rethrow;
    }
  }
  
  /// DELETE 请求
  Future<T> delete<T>(
    String path, {
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.delete(path);
      return parser != null ? parser(response.data) : response.data;
    } on DioException {
      rethrow;
    }
  }
  
  /// 上传文件
  Future<T> upload<T>(
    String path,
    File file, {
    String fileKey = 'file',
    Map<String, dynamic>? data,
    T Function(dynamic)? parser,
    ProgressCallback? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(file.path),
        ...?data,
      });
      
      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      
      return parser != null ? parser(response.data) : response.data;
    } on DioException {
      rethrow;
    }
  }
  
  /// 下载文件
  Future<void> download(
    String url,
    String savePath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }
}
```

### Provider 注入

```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
```

## Service 层设计

### NoteService 示例

```dart
class NoteService {
  final ApiClient _apiClient;
  
  NoteService(this._apiClient);
  
  /// 获取笔记列表
  Future<List<Note>> fetchNotes({int page = 1, int pageSize = 20}) async {
    return _apiClient.get(
      '/api/notes',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
      parser: (data) {
        final List<dynamic> items = data['items'];
        return items.map((json) => Note.fromJson(json)).toList();
      },
    );
  }
  
  /// 获取单个笔记
  Future<Note> fetchNote(String id) async {
    return _apiClient.get(
      '/api/notes/$id',
      parser: (data) => Note.fromJson(data),
    );
  }
  
  /// 创建笔记
  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    return _apiClient.post(
      '/api/notes',
      data: {
        'title': title,
        'content': content,
      },
      parser: (data) => Note.fromJson(data),
    );
  }
  
  /// 更新笔记
  Future<Note> updateNote(
    String id, {
    String? title,
    String? content,
  }) async {
    return _apiClient.put(
      '/api/notes/$id',
      data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
      },
      parser: (data) => Note.fromJson(data),
    );
  }
  
  /// 删除笔记
  Future<void> deleteNote(String id) async {
    await _apiClient.delete('/api/notes/$id');
  }
  
  /// 搜索笔记
  Future<List<Note>> searchNotes(String query) async {
    return _apiClient.get(
      '/api/notes/search',
      queryParameters: {'q': query},
      parser: (data) {
        final List<dynamic> items = data['items'];
        return items.map((json) => Note.fromJson(json)).toList();
      },
    );
  }
}

// Provider 注入
final noteServiceProvider = Provider<NoteService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NoteService(apiClient);
});
```

## 请求取消

### 使用 CancelToken

```dart
class NoteService {
  CancelToken? _searchCancelToken;
  
  Future<List<Note>> searchNotes(String query) async {
    // 取消上一个搜索请求
    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();
    
    try {
      final response = await _dio.get(
        '/api/notes/search',
        queryParameters: {'q': query},
        cancelToken: _searchCancelToken,
      );
      
      return (response.data['items'] as List)
          .map((json) => Note.fromJson(json))
          .toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        print('请求已取消');
        return [];
      }
      rethrow;
    }
  }
}
```

## 缓存策略

### 内存缓存

```dart
class CachedNoteService implements NoteService {
  final NoteService _noteService;
  final _cache = <String, Note>{};
  
  @override
  Future<Note> fetchNote(String id) async {
    // 检查缓存
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }
    
    // 缓存未命中,请求网络
    final note = await _noteService.fetchNote(id);
    _cache[id] = note;
    
    return note;
  }
  
  void invalidateCache(String id) {
    _cache.remove(id);
  }
  
  void clearCache() {
    _cache.clear();
  }
}
```

### HTTP 缓存 (Dio Cache Interceptor)

```dart
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

final dio = Dio()
  ..interceptors.add(
    DioCacheInterceptor(
      options: CacheOptions(
        store: MemCacheStore(),
        maxStale: const Duration(days: 7),
        policy: CachePolicy.request,
      ),
    ),
  );
```

## 错误处理模式

### 统一错误处理

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  
  ApiException(this.message, [this.statusCode]);
  
  @override
  String toString() => message;
}

Future<T> handleApiCall<T>(Future<T> Function() apiCall) async {
  try {
    return await apiCall();
  } on DioException catch (e) {
    throw ApiException(
      e.error?.toString() ?? '网络错误',
      e.response?.statusCode,
    );
  } catch (e) {
    throw ApiException('未知错误: $e');
  }
}

// 使用
Future<Note> fetchNote(String id) async {
  return handleApiCall(() => _apiClient.get('/api/notes/$id'));
}
```

## 最佳实践

### 1. 禁止 UI 层直接调用 Dio

```dart
// ❌ 错误 - UI 层直接调用
class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/api/notes');  // 禁止!
  }
}

// ✅ 正确 - 通过 Service 层
class NotePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteService = ref.watch(noteServiceProvider);
    final notes = await noteService.fetchNotes();
  }
}
```

### 2. 统一响应格式

```dart
// 服务器响应格式
{
  "code": 200,
  "message": "success",
  "data": { ... }
}

// 解析辅助方法
T parseResponse<T>(
  Response response,
  T Function(dynamic) parser,
) {
  final data = response.data;
  
  if (data['code'] != 200) {
    throw ApiException(data['message']);
  }
  
  return parser(data['data']);
}
```

### 3. 环境配置

```dart
abstract class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.pocketmind.app',
  );
  
  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: kDebugMode,
  );
}

// 使用
final dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
```

## 相关文档

- [Flutter 架构规范](./flutter-architecture.md)
- [状态管理最佳实践](./state-management-patterns.md)
- [移动端编码规约](../../conventions/mobile-coding-standards.md)
