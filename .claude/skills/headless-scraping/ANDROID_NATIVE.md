# Android 原生通信技术细节

## FlutterEngine 缓存机制

ShareActivity 使用缓存的 FlutterEngine 实现快速启动：

```kotlin
// ShareActivity.kt
companion object {
    private const val ENGINE_ID = "share_engine"
}

override fun provideFlutterEngine(context: Context): FlutterEngine? {
    var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
    
    if (engine == null) {
        // 冷启动：创建新引擎
        engine = FlutterEngine(this).apply {
            dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    appBundlePath,
                    "package:pocketmind/main_share.dart",
                    "mainShare"  // 独立入口函数
                )
            )
        }
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
    // 热启动：复用缓存引擎
    return engine
}
```

## 分享 Activity 生命周期

```
冷启动流程：
onCreate() 
  → provideFlutterEngine() [创建引擎]
  → onResume() 
  → onWindowFocusChanged(true) [剪贴板读取时机]
  → setupMethodChannel()
  → Dart 端发送 "engineReady"
  → notifyDartToShowShare()

热启动流程：
onNewIntent() 
  → onResume()
  → onWindowFocusChanged(true)
  → notifyDartToShowShare() [引擎已就绪]
```

## MethodChannel 详细实现

### MainActivity.kt 注册

```kotlin
// 爬虫服务 Channel
MethodChannel(messenger, "com.doublez.pocketmind/scraper")
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "startForegroundService" -> {
                val taskCount = call.argument<Int>("taskCount") ?: 0
                ScraperForegroundService.start(this, taskCount)
                result.success(true)
            }
            "stopForegroundService" -> {
                ScraperForegroundService.stop(this)
                result.success(true)
            }
            "updateProgress" -> {
                val currentUrl = call.argument<String>("currentUrl") ?: ""
                val pendingCount = call.argument<Int>("pendingCount") ?: 0
                ScraperForegroundService.updateProgress(this, currentUrl, pendingCount)
                result.success(true)
            }
        }
    }
```

### ScraperQueueManager.dart 调用

```dart
static const MethodChannel _channel = MethodChannel(
    'com.doublez.pocketmind/scraper',
);

Future<void> startForegroundService() async {
    await _channel.invokeMethod('startForegroundService', {
        'taskCount': getQueueLength(),
    });
}

Future<void> _updateNotification(ScraperTask task) async {
    await _channel.invokeMethod('updateProgress', {
        'currentUrl': task.truncatedUrl,
        'pendingCount': getQueueLength(),
    });
}
```

## 前台服务通知配置

```kotlin
// ScraperForegroundService.kt
private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "后台抓取",
            NotificationManager.IMPORTANCE_LOW  // 低优先级，不发出声音
        ).apply {
            description = "后台抓取网页内容"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
```

## AndroidManifest 权限声明

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<service
    android:name=".service.ScraperForegroundService"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

## 剪贴板访问时机

Android 10+ 后台应用无法访问剪贴板，必须在 `onWindowFocusChanged(true)` 中读取：

```kotlin
override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    
    if (hasFocus && pendingClipboardRead) {
        pendingClipboardRead = false
        val clipboardData = parseClipboardIntent()
        // 此时 Activity 已完全前台，可以访问剪贴板
    }
}
```

## 进程间 SharedPreferences 同步

```dart
// main_share.dart 和主应用是不同进程
// 需要显式 reload 获取最新数据
await sharedPreferences.reload();
var urls = sharedPreferences.getStringList('needCallBackUrl') ?? [];
```
