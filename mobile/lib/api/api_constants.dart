class ApiConstants {
  /// PocketMind 后端 API 路径
  ///
  /// 注意：baseUrl 由 [httpClientProvider] 统一注入到 Dio。
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';

  /// LinkPreview.net API 基础 URL
  static const String linkPreviewBaseUrl = 'https://api.linkpreview.net';

  /// AI 分析提交（POST，202 Accepted）
  static const String aiAnalyze = '/api/ai/analyze';

  /// 帖子详情轮询（GET /{uuid}）
  static const String postDetail = '/api/post';

  /// 图片资产（上传 POST，绑定 PATCH /{uuid}/bind）
  static const String assetsImages = '/api/assets/images';
}
