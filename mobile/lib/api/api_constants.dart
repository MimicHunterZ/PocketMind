class ApiConstants {
  /// PocketMind 后端 API 路径
  ///
  /// 注意：baseUrl 由 [httpClientProvider] 统一注入到 Dio。
  static const String resourceSubmit = '/api/resource/submit';
  static const String resourceStatus = '/api/resource/status';

  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';

  /// LinkPreview.net API 基础 URL
  static const String linkPreviewBaseUrl = 'https://api.linkpreview.net';

  /// AI 分析服务
  static const String aiAnalyze = '/api/ai/analyze';
}
