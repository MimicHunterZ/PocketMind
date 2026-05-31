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

  /// 单条 note 抓取最多尝试次数（达到后置 FAILED 终态）
  static const int maxScrapeAttempts = 3;

  /// ScrapeAttempt running 状态的 lease 时长（超过则视为悬挂可被复活）
  static const Duration scrapeLease = Duration(minutes: 5);

  /// 软失败重入队的退避时长，按 attemptNumber 索引（attemptNumber 1 → 1min,
  /// attemptNumber 2 → 5min；attemptNumber 3 已是终态不再退避）。
  ///
  /// 用法：重入队的新 attempt 的 enqueuedAt = now + scrapeBackoffSchedule[N-1]，
  /// claimNext 的 filter 排除 enqueuedAt 在未来的行；这样同一轮 runNow 不会
  /// 立刻把刚失败的作业捡回来重跑，避免后端短暂不可用引起 3 连发失败通知。
  static const List<Duration> scrapeBackoffSchedule = [
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  // ==================== 资源抓取状态常量 ====================

  /// 抓取待处理（已入队或正在 ScrapeAttempt 中执行）
  static const String resourceStatusPending = 'PENDING';

  /// 抓取成功（正文可用）
  static const String resourceStatusCrawled = 'CRAWLED';

  /// 抓取失败（终态，不再重试）
  static const String resourceStatusFailed = 'FAILED';

  // ==================== ScrapeAttempt 状态常量 ====================

  /// 排队中
  static const String scrapeAttemptStateQueued = 'queued';

  /// 已被某 worker 领走，正在执行
  static const String scrapeAttemptStateRunning = 'running';

  /// 已成功结束
  static const String scrapeAttemptStateSucceeded = 'succeeded';

  /// 已失败结束（具体原因看 errorCode）
  static const String scrapeAttemptStateFailed = 'failed';

  /// 已取消（note 被删 / 用户强制完成等）
  static const String scrapeAttemptStateCancelled = 'cancelled';

  // ==================== ScrapeAttempt 错误码 ====================

  static const String scrapeErrorNetwork = 'network';
  static const String scrapeErrorCookieExpired = 'cookie_expired';
  static const String scrapeErrorParse = 'parse';
  static const String scrapeErrorQuota = 'quota';
  static const String scrapeErrorCancelled = 'cancelled';
  static const String scrapeErrorCrashed = 'crashed';
  static const String scrapeErrorUnknown = 'unknown';

  // ==================== 后台任务常量 ====================

  /// Workmanager: 拉一次 ResourceFetchScheduler
  static const String taskScrapeAndSave = 'scrapeAndSave';

  /// Workmanager: 用户从通知"重试"按钮触发的复活 + 抓取
  static const String taskRetryUrlsWithPolicy = 'retryUrlsWithPolicy';

  /// Workmanager: 用户从通知"忽略"按钮触发的强制 FAILED
  static const String taskMarkDismissedUrlsFailed = 'markDismissedUrlsFailed';

  /// Workmanager input key: noteUuid 列表（重试 / 忽略 用）
  static const String taskInputNoteUuids = 'noteUuids';

  /// Workmanager input key: 用户问题（分享 → 抓取 用）
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

  /// 存储待前台轮询 AI 分析结果的 noteUuid 列表。
  static const String keyPendingAiAnalysis = 'pending_ai_analysis';

  /// 存储 submitAnalysis 失败、待下次 runNow 重试提交的 noteUuid 列表。
  ///
  /// 当 ResourceFetchScheduler 的 Phase 2 在尝试把笔记交给后端做 AI 分析时
  /// 发生网络/服务端故障，会把 noteUuid 写入此列表（不影响 Phase 1 的本地
  /// 爬取成功语义）。下次 runNow 入口会先 best-effort drain 该列表。
  static const String keyPendingAiSubmission = 'pending_ai_submission';

  // ==================== 默认值 ====================

  /// 默认元数据缓存时间（天）
  static const int defaultMetaCacheTimeDays = 10;

  /// 最大提醒快捷方式数量
  static const int maxReminderShortcuts = 5;
}
