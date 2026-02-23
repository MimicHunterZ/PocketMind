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

  // Chat 会话 & 消息

  /// 会话列表 / 创建会话（GET / POST）
  static const String chatSessions = '/api/ai/sessions';

  /// 单个会话操作基础路径（拼接 /{uuid}）
  static String chatSession(String uuid) => '/api/ai/sessions/$uuid';

  /// 会话消息列表 / 发送消息（GET / POST）
  static String chatMessages(String sessionUuid) =>
      '/api/ai/sessions/$sessionUuid/messages';
}
