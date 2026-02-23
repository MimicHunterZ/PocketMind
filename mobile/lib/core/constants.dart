/// 应用程序常量定义
///
/// 集中管理所有魔法数字和字符串常量，避免硬编码
class AppConstants {
  // 私有构造函数，防止实例化
  AppConstants._();

  // ==================== 分类相关常量 ====================

  /// 默认分类（Home）的 ID
  static const int homeCategoryId = 1;

  /// 默认分类（Home）的名称
  static const String homeCategoryName = 'home';

  /// 默认分类（Home）的描述
  static const String homeCategoryDescription = '首页';

  // ==================== 笔记相关常量 ====================

  /// 默认笔记标题
  static const String defaultNoteTitle = '默认标题';

  /// 默认笔记内容
  static const String defaultNoteContent = '默认内容';

  // ==================== 图片存储相关常量 ====================

  /// 本地图片存储路径前缀
  static const String localImagePathPrefix = 'pocket_images/';

  // ==================== 同步相关常量 ====================

  /// WebSocket 默认端口
  static const int defaultWebSocketPort = 8080;

  /// UDP 广播端口
  static const int defaultUdpBroadcastPort = 8888;

  /// 设备发现超时时间（秒）
  static const int deviceDiscoveryTimeoutSeconds = 30;

  /// 同步重试次数
  static const int syncRetryCount = 3;

  /// 分享 URL 抓取最大重试次数
  static const int maxShareUrlRetryCount = 3;

  // ==================== 资源抓取状态常量 ====================

  /// 链接资源抓取中
  static const String resourceStatusScraping = 'SCRAPING';

  /// 抓取待重试/待回调
  static const String resourceStatusPending = 'PENDING';

  /// 抓取成功（正文可用）
  static const String resourceStatusCrawled = 'CRAWLED';

  /// 向量化/Embedding 完成
  static const String resourceStatusEmbedded = 'EMBEDDED';

  /// 抓取失败（终态，不再重试）
  static const String resourceStatusFailed = 'FAILED';

  // ==================== 后台任务常量 ====================

  /// Workmanager: 执行抓取并保存
  static const String taskScrapeAndSave = 'scrapeAndSave';

  /// Workmanager: 按策略重试 URL
  static const String taskRetryUrlsWithPolicy = 'retryUrlsWithPolicy';

  /// Workmanager: 通知重试次数耗尽
  static const String taskNotifyRetryExhausted = 'notifyRetryExhausted';

  /// Workmanager: 将忽略 URL 标记失败
  static const String taskMarkDismissedUrlsFailed = 'markDismissedUrlsFailed';

  /// Workmanager input key: URL 列表
  static const String taskInputUrls = 'urls';

  /// Workmanager input key: 用户问题
  static const String taskInputUserQuestion = 'uq';

  // ==================== UI 相关常量 ====================

  /// 桌面端断点宽度（像素）
  static const double desktopBreakpoint = 600.0;

  /// 桌面端设计尺寸
  static const double desktopDesignWidth = 1280.0;
  static const double desktopDesignHeight = 720.0;

  /// 移动端设计尺寸
  static const double mobileDesignWidth = 400.0;
  static const double mobileDesignHeight = 869.0;

  // ==================== 代理相关常量 ====================

  /// 默认代理主机
  static const String defaultProxyHost = '127.0.0.1';

  /// 默认代理端口
  static const int defaultProxyPort = 7890;

  // ==================== SharedPreferences 键名 ====================

  /// 代理启用状态键
  static const String keyProxyEnabled = 'proxy_enabled';

  /// 代理主机键
  static const String keyProxyHost = 'proxy_host';

  /// 代理端口键
  static const String keyProxyPort = 'proxy_port';

  /// 链接预览 API 密钥
  static const String keyLinkPreviewApiKey = 'linkpreview_api_key';

  /// 元数据缓存时间键
  static const String keyMetaCacheTime = 'meta_cache_time';

  /// 标题启用状态键
  static const String keyTitleEnabled = 'title_enabled';

  /// 应用环境键
  static const String keyEnvironment = 'app_environment';

  /// 瀑布流布局启用状态键
  static const String keyWaterfallLayout = 'waterfall_layout';

  /// 同步自动启动键
  static const String keySyncAutoStart = 'sync_auto_start';

  /// 提醒快捷方式键
  static const String keyReminderShortcuts = 'reminder_shortcuts';

  /// 高精度通知键
  static const String keyHighPrecisionNotification =
      'high_precision_notification';

  /// 通知强度键
  static const String keyNotificationIntensity = 'notification_intensity';

  /// 局域网同步设备 ID 键
  static const String keyLanSyncDeviceId = 'lan_sync_device_id';

  /// 局域网同步设备名称键
  static const String keyLanSyncDeviceName = 'lan_sync_device_name';

  /// 分享待处理 URL 列表键
  static const String keyNeedCallbackUrl = 'needCallBackUrl';

  /// 存储待前台轮询 AI 分析结果的 noteUuid 列表。
  static const String keyPendingAiAnalysis = 'pending_ai_analysis';

  /// 分享 URL 重试计数字典键（JSON Map<String,int>）
  static const String keyShareUrlRetryCountMap = 'share_url_retry_count_map';

  // ==================== 默认值 ====================

  /// 默认元数据缓存时间（天）
  static const int defaultMetaCacheTimeDays = 10;

  /// 最大提醒快捷方式数量
  static const int maxReminderShortcuts = 5;
}
