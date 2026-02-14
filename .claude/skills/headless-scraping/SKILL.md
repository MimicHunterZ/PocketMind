---
name: "headless-scraping"
description: "PocketMind 本地无头浏览器爬取架构，适用于小红书/知乎抓取、后台爬虫服务、MethodChannel、Cookie 管理与 MetadataManager 协作场景。"
metadata:
  version: "2.1.1"
  updated: "2026-02-14"
  tags: ['scraper','爬虫','xhs','小红书','zhihu','知乎','抓取','Cookie','WebView','stealth','前台服务']
---

# 无头浏览器内容爬取架构

PocketMind 使用 HeadlessInAppWebView 实现无头浏览器爬取，用于从小红书等需要登录的平台提取内容。

## 架构概览（当前实现）

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           URL 生产入口（双来源）                           │
│                                                                          │
│  A. 其他 App 分享 URL                                                     │
│     ShareActivity -> main_share.dart -> enqueuePendingUrlIfAbsent()      │
│                                                                          │
│  B. 主 App 启动/回前台                                                     │
│     main.dart(init/resume) -> NoteService.processPendingUrls()           │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        统一调度入口（唯一）                                │
│                                                                          │
│  NoteService.processPendingUrls()                                         │
│    ├─ 读取 needCallBackUrl                                                 │
│    ├─ evaluateRetryEligibility()（队列存在 + 最大重试次数）                │
│    ├─ 达上限：markUrlsAsFailedAndStopRetry() + notifyRetryExhausted      │
│    └─ 可重试：注册 Workmanager 任务 scrapeAndSave                          │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         后台执行与结果处理                                 │
│                                                                          │
│  callbackDispatcher -> scrapeAndSave()                                    │
│    ├─ MetadataManager 多策略抓取（平台爬虫/后端/API/本地）                │
│    ├─ 成功 URL 清理 pending + 清理重试计数                                 │
│    ├─ 失败 URL 增加重试计数，达到 3 次转终态 FAILED                        │
│    └─ NotificationService 发送成功/失败/三次失败通知                       │
└──────────────────────────────────────────────────────────────────────────┘
```

### 核心设计原则

1. **单入口调度**：分享触发与回前台触发都必须走 `NoteService.processPendingUrls()`
2. **队列幂等**：URL 进入 `needCallBackUrl` 前先去重，防止重复分享造成并发抓取
3. **重试上限一致性**：手动重试与自动重试共用同一计数（默认上限 3 次）
4. **终态可观测**：达到上限后标记 `FAILED`，并发送“已尝试3次抓取均失败”通知
5. **失败静默落库**：失败不写占位内容，仅更新状态，便于后续重试/排障

## 核心文件清单

修改以下任一文件时，**必须同步更新此 SKILL.md**：

### Flutter 端

| 文件 | 职责 |
|------|------|
| `mobile/lib/service/note_service.dart` | **核心调度**：pending 队列管理、重试资格判定、重试计数、终态失败落库 |
| `mobile/lib/service/call_back_dispatcher.dart` | **后台执行入口**：Workmanager 任务分发、抓取结果处理、重试策略落地 |
| `mobile/lib/service/notification_service.dart` | **通知交互层**：重试/忽略按钮回调、三次失败通知 |
| `mobile/lib/service/scraper/platform_scraper_service.dart` | 爬虫服务：Cookie 管理、图片下载、批量爬取 |
| `mobile/lib/service/scraper/xhs_scraper.dart` | 小红书爬虫：HeadlessInAppWebView + stealth.js |
| `mobile/lib/service/scraper/zhihu_scraper.dart` | 知乎爬虫：支持回答/文章/视频，从 js-initialData 提取 |
| `mobile/lib/service/scraper/platform_scraper_interface.dart` | 接口定义：IPlatformScraper + ScrapedMetadata + CookieExpiredException |
| `mobile/lib/service/scraper/stealth_js_loader.dart` | stealth.js 单例加载器 |
| `mobile/lib/service/scraper/scraper_task.dart` | 任务模型：@JsonSerializable（TaskStatus 枚举 + 重试机制） |
| `mobile/lib/service/scraper/scraper.dart` | 模块统一导出文件 |
| `mobile/lib/util/platform_detector.dart` | 平台检测 + 爬虫工厂：URL → PlatformType + getScraper() |
| `mobile/lib/main_share.dart` | 分享入口：写入 pending 队列并调用 `processPendingUrls()` |
| `mobile/lib/main.dart` | 主应用入口：启动与 resumed 时统一调用 `processPendingUrls()` |
| `mobile/lib/service/metadata_manager.dart` | 元数据管理：多策略获取（爬虫 → 后端API → LinkPreview → 本地解析） |

### Android 原生端

| 文件 | 职责 |
|------|------|
| `mobile/android/.../service/ScraperForegroundService.kt` | 前台服务：通知栏进度、保活进程、静态方法（start/stop/updateProgress） |
| `mobile/android/.../MainActivity.kt` | 主应用 MethodChannel 注册 |
| `mobile/android/.../ShareActivity.kt` | 分享入口：FlutterEngine 缓存 + MethodChannel 注册 + 剪贴板读取 |

**重要**：`MainActivity` 和 `ShareActivity` 都需要注册 `scraper` Channel，因为它们运行在不同的 FlutterEngine 实例中。

## MethodChannel 协议

**Channel**: `com.doublez.pocketmind/scraper`

### Flutter → Android

```kotlin
// 启动前台服务
"startForegroundService" { taskCount: Int }

// 停止前台服务
"stopForegroundService" {}

// 更新通知进度
"updateProgress" { currentUrl: String, pendingCount: Int }
```

### Android → Flutter

```dart
// 触发队列处理
"processQueue" {}

// 取消任务
"cancelTask" { noteId: Int }

// 查询状态
"getQueueStatus" → { queueLength, currentUrl, isProcessing }
```

## 处理策略枚举

```dart
/// 平台类型枚举
enum PlatformType {
  /// 小红书
  xhs('小红书', 'xhs'),

  /// 知乎
  zhihu('知乎', 'zhihu'),

  /// 通用平台（使用默认策略）
  generic('通用', 'generic');

  final String displayName;
  final String identifier;

  const PlatformType(this.displayName, this.identifier);
}
```

**支持的知乎 URL 格式**：
- 回答: `https://www.zhihu.com/question/123456/answer/789012`
- 文章: `https://zhuanlan.zhihu.com/p/123456789`
- 视频: `https://www.zhihu.com/zvideo/123456789`

**MetadataManager 策略优先级**：
0. 平台专用爬虫（小红书、知乎等需要登录的平台）
1. 后端 API（支持正文提取）
2. LinkPreview API（公共服务）
3. 本地解析（AnyLinkPreview）

## 关键实现细节

### 1. 入队与消费（核心流程，当前）

```dart
// main_share.dart - 分享时仅负责入队（幂等）
await noteService.enqueuePendingUrlIfAbsent(url);

// 分享完成后与主应用回前台，都走统一入口
await noteService.processPendingUrls(userQuestion: userQuestion);

// note_service.dart - 统一调度
Future<void> processPendingUrls({String? userQuestion}) async {
  final urls = loadPendingUrls();
  final eligibility = await evaluateRetryEligibility(urls);

  if (eligibility.reachedMaxRetryUrls.isNotEmpty) {
    await markUrlsAsFailedAndStopRetry(eligibility.reachedMaxRetryUrls);
    enqueueTask('notifyRetryExhausted', eligibility.reachedMaxRetryUrls);
  }

  if (eligibility.retryableUrls.isNotEmpty) {
    enqueueTask('scrapeAndSave', eligibility.retryableUrls, uq: userQuestion);
  }
}

// call_back_dispatcher.dart - 后台执行
// scrapeAndSave() 负责调用 MetadataManager、落库、更新重试计数；
// 失败达到 3 次后调用 notifyRetryExhausted() 给用户发终态通知。
```

### 2. 平台检测与爬虫工厂（整合在 platform_detector.dart）

```dart
// PlatformDetector.detectPlatform()
static PlatformType detectPlatform(String url) {
  if (url.isEmpty) return PlatformType.generic;
  
  // 小红书检测（含短链）
  if (_xhsPattern.hasMatch(url)) {  // (xhslink|xiaohongshu)\.com
    return PlatformType.xhs;
  }
  
  // 知乎检测
  if (_zhihuPattern.hasMatch(url)) {  // (zhihu|zhuanlan\.zhihu)\.com
    return PlatformType.zhihu;
  }
  
  return PlatformType.generic;
}

// PlatformDetector.getScraper() - 工厂方法
static IPlatformScraper? getScraper(String url) {
  final platform = detectPlatform(url);
  switch (platform) {
    case PlatformType.xhs:
      return XhsScraper();
    case PlatformType.zhihu:
      return ZhihuScraper();
    case PlatformType.generic:
      return null;  // 通用平台走 MetadataManager
  }
}
```

### 3. 知乎数据提取（参考 MediaCrawler zhihu/help.py）

```dart
// zhihu_scraper.dart - 从 js-initialData 提取
// 知乎页面包含 <script id="js-initialData"> 标签，内含 JSON 数据
Future<ScrapedMetadata?> _extractFromInitialData(controller, contentType) async {
  // 1. 获取 js-initialData 脚本内容
  var scriptEl = document.getElementById('js-initialData');
  var data = JSON.parse(scriptEl.textContent);
  
  // 2. 根据内容类型提取
  var entities = data.initialState.entities;
  
  if (contentType == 'answer') {
    // 从 entities.answers 提取
    var answer = entities.answers[Object.keys(entities.answers)[0]];
    return { title: answer.question.title, content: answer.content, ... };
  } else if (contentType == 'article') {
    // 从 entities.articles 提取
    var article = entities.articles[Object.keys(entities.articles)[0]];
    return { title: article.title, content: article.content, ... };
  } else if (contentType == 'zvideo') {
    // 从 entities.zvideos 提取
    var video = entities.zvideos[Object.keys(entities.zvideos)[0]];
    return { title: video.title, desc: video.description, ... };
  }
}

// 知乎必需 Cookie: d_c0, z_c0
```

### 4. Stealth 模式注入

```dart
// xhs_scraper.dart - 在 WebView 创建时注入 stealth.js
onWebViewCreated: (ctrl) {
  controller = ctrl;
  
  // 注入 stealth.js（在 document 开始时）
  if (stealthJs.isNotEmpty) {
    ctrl.addUserScript(
      userScript: UserScript(
        source: stealthJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    );
  }
},
```

**stealth.js 作用**：
- 覆盖 `navigator.webdriver` 检测
- 伪装 Chrome 运行时
- 隐藏自动化特征
- 资源路径：`assets/js/stealth.min.js`

### 5. Cookie 管理

```dart
// IPlatformScraper 接口定义
abstract class IPlatformScraper {
  Future<ScrapedMetadata?> scrape(String url, Map<String, String> cookieDict);
  List<String> getRequiredCookieNames();
  bool validateCookies(Map<String, String> cookieDict);
}

// XhsScraper 实现
@override
List<String> getRequiredCookieNames() => ['a1', 'webId'];

// ZhihuScraper 实现
@override
List<String> getRequiredCookieNames() => ['d_c0', 'z_c0'];

@override
bool validateCookies(Map<String, String> cookieDict) {
  final required = getRequiredCookieNames();
  for (var name in required) {
    if (!cookieDict.containsKey(name) || cookieDict[name]!.isEmpty) {
      return false;
    }
  }
  return true;
}

// CookieExpiredException - 当 Cookie 失效时抛出
class CookieExpiredException implements Exception {
  final String message;
  final String? platform;
  CookieExpiredException(this.message, {this.platform});
}
```

### 6. 队列持久化与任务模型

```dart
// SharedPreferences JSON 存储
static const String _queueKey = 'scraper_task_queue';

// 任务模型（@JsonSerializable）
@JsonSerializable()
class ScraperTask {
  final int noteId;
  final String url;
  final String platform;
  TaskStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  String? errorMessage;
  int retryCount;
  DateTime? nextRetryAt;
  
  // 是否可以立即执行
  bool get canExecuteNow {
    if (status != TaskStatus.pending) return false;
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }
  
  // 是否可以重试（最多 3 次）
  bool get canRetry => retryCount < 3;
}

// 任务状态枚举
enum TaskStatus { pending, running, completed, failed, cancelled }

// DateTime 序列化（ISO8601 字符串格式）
DateTime _dateTimeFromJson(String json) => DateTime.parse(json);
String _dateTimeToJson(DateTime dateTime) => dateTime.toIso8601String();
```

### 7. 前台服务生命周期

```kotlin
// ScraperForegroundService.kt - 静态方法调用
companion object {
    const val METHOD_CHANNEL = "com.doublez.pocketmind/scraper"
    
    // 启动前台服务
    fun start(context: Context, taskCount: Int = 0)
    
    // 停止前台服务
    fun stop(context: Context)
    
    // 更新任务进度
    fun updateProgress(context: Context, currentUrl: String, pendingCount: Int)
}

// Android 8.0+ 必须使用前台服务
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
        ACTION_START -> {
            taskCount = intent.getIntExtra(EXTRA_TASK_COUNT, 0)
            startForeground(NOTIFICATION_ID, createNotification())
        }
        ACTION_STOP -> {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
        ACTION_UPDATE_PROGRESS -> {
            // 更新通知并检查是否完成
            if (pendingCount <= 0 && taskCount > 0) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }
    return START_NOT_STICKY
}
```

## 数据流：分享链接（当前）

```
1. ShareActivity.kt 接收分享 Intent（或剪贴板触发）
2. MethodChannel('com.doublez.pocketmind/share') -> Flutter main_share.dart
3. main_share._handleMethodCall('showShare')：
  - noteService.addNote() 先落库
  - noteService.enqueuePendingUrlIfAbsent(url) 写入 needCallBackUrl（幂等）
4. 用户关闭分享页 -> main_share._dismissUI()：
  - 调用 noteService.processPendingUrls(userQuestion?)（统一入口）
5. NoteService.processPendingUrls()：
  - evaluateRetryEligibility() 做重试资格筛选
  - 达上限 URL：markUrlsAsFailedAndStopRetry() + notifyRetryExhausted
  - 可重试 URL：注册 Workmanager 任务 scrapeAndSave
6. callbackDispatcher.scrapeAndSave()：
  - MetadataManager 多策略抓取（平台爬虫/后端/API/本地）
  - 成功 URL 清理 pending + 清理重试计数
  - 失败 URL 累计重试次数，达到 3 次则终态 FAILED
7. NotificationService 展示结果通知（成功/失败/三次失败）
```

## 短链接处理

小红书分享的短链接 (`xhslink.com/xxx`) 无法直接提取笔记 ID：
- **预期行为**：`_extractNoteId()` 返回 null
- **降级策略**：WebView 自动重定向到真实 URL，使用 OG 标签提取
- **日志级别**：Debug（不是错误）

## 扩展新平台

1. 实现 `IPlatformScraper` 接口（包括  `scrape()`, `getRequiredCookieNames()`, `validateCookies()`）
2. 在 `PlatformType` 枚举添加新平台（包含 displayName 和 identifier）
3. 在 `PlatformDetector` 添加 URL 匹配正则和 `getScraper()` 分支
4. 在 `scraper.dart` 添加导出
5. 更新此 SKILL.md

## 常见问题

### Cookie 过期
- 爬取时检测到 Cookie 无效会抛出 `CookieExpiredException`
- `CookieManagerService.markAsExpired()` 标记过期
- `markFailed(canRetry: false)` 不允许自动重试
- 用户需重新登录获取 Cookie
- **小红书必需 Cookie**：`a1`, `webId`
- **知乎必需 Cookie**：`d_c0`, `z_c0`

### WebView 检测
- 确保 stealth.js 正确注入（`UserScriptInjectionTime.AT_DOCUMENT_START`）
- 检查 UserAgent 配置（模拟 Chrome 126/128）
- 确认 Cookie 域名正确（小红书：`.xiaohongshu.com`，知乎：`.zhihu.com`）

### 前台服务未启动 / MissingPluginException
- **原因**：`MainActivity` 和 `ShareActivity` 运行在不同 FlutterEngine
- **解决**：两个 Activity 都必须注册 `com.doublez.pocketmind/scraper` Channel
- 检查 AndroidManifest.xml 的 `FOREGROUND_SERVICE` 权限

### 短链接无法提取笔记 ID
- **不是错误**：短链接 (xhslink.com) 无法直接解析
- WebView 会自动重定向，降级使用 OG 标签提取
- 日志 `无法从 URL 提取笔记 ID（可能是短链接）` 是 Debug 级别

### 知乎 js-initialData 提取失败
- **降级策略**：依次尝试 OG 标签 → 页面结构提取
- 检查页面是否需要登录（弹出登录框）
- 确认 URL 格式正确（回答/文章/视频三种类型）

### 重试机制
- 失败 URL 使用 SharedPreferences 计数（`share_url_retry_count_map`）
- 自动重试与手动重试共用同一计数，最多 3 次
- 达到 3 次立即标记 `resourceStatus=FAILED`，并发送终态失败通知
- 终态 URL 从 `needCallBackUrl` 移除，同时清理对应重试计数

### 备份机制
- 分享时 URL 持久化到 `needCallBackUrl`
- 主应用启动与 resumed 会通过 `processPendingUrls()` 自动续跑
- 成功、取消或终态失败后都会从备份列表移除并清理计数
