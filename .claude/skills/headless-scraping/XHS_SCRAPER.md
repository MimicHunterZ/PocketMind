# XHS 爬虫实现细节

## HeadlessInAppWebView 配置

```dart
HeadlessInAppWebView(
    initialSettings: InAppWebViewSettings(
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/126.0.0.0 Safari/537.36',
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: false,
    ),
)
```

## Stealth.js 注入时机

```dart
onLoadStop: (controller, url) async {
    // 页面加载完成后注入 stealth.js
    await controller.evaluateJavascript(source: stealthJs);
    
    // 等待 Vue 渲染
    await Future.delayed(Duration(seconds: 2));
    
    // 提取数据
    final metadata = await _extractMetadata(controller);
}
```

## 数据提取策略

### 1. 优先从 window.__INITIAL_STATE__ 提取

```dart
Future<ScrapedMetadata?> _extractFromInitialState(
    InAppWebViewController controller
) async {
    final result = await controller.evaluateJavascript(source: '''
        (function() {
            var state = window.__INITIAL_STATE__;
            if (!state || !state.note || !state.note.noteDetailMap) return null;
            
            var noteId = Object.keys(state.note.noteDetailMap)[0];
            var note = state.note.noteDetailMap[noteId];
            if (!note) return null;
            
            return JSON.stringify({
                title: note.note.title,
                description: note.note.desc,
                images: note.note.imageList.map(i => i.urlDefault),
            });
        })()
    ''');
    
    if (result != null) {
        return ScrapedMetadata.fromJson(jsonDecode(result));
    }
    return null;
}
```

### 2. 回退到 OG Tags

```dart
Future<ScrapedMetadata?> _extractFromOgTags(
    InAppWebViewController controller
) async {
    final result = await controller.evaluateJavascript(source: '''
        (function() {
            var title = document.querySelector('meta[property="og:title"]');
            var desc = document.querySelector('meta[property="og:description"]');
            var image = document.querySelector('meta[property="og:image"]');
            
            return JSON.stringify({
                title: title ? title.content : null,
                description: desc ? desc.content : null,
                images: image ? [image.content] : [],
            });
        })()
    ''');
    
    return ScrapedMetadata.fromJson(jsonDecode(result));
}
```

## Cookie 注入

```dart
Future<void> _setCookies(Map<String, String> cookieDict) async {
    final cookieManager = CookieManager.instance();
    
    for (var entry in cookieDict.entries) {
        await cookieManager.setCookie(
            url: WebUri(_domain),
            name: entry.key,
            value: entry.value,
            domain: _cookieDomain,
            path: '/',
        );
    }
}
```

## 必需 Cookie 列表

| Cookie | 作用 |
|--------|------|
| `a1` | 设备标识，反爬关键 |
| `webId` | 会话标识 |

## 超时与重试

```dart
static const Duration _renderWaitTime = Duration(seconds: 2);
static const Duration _timeout = Duration(seconds: 20);

// ScraperQueueManager 重试策略
static const int maxRetryCount = 3;
static const Duration _retryDelay = Duration(seconds: 30);

// 指数退避
task.nextRetryAt = DateTime.now().add(_retryDelay * (task.retryCount + 1));
```

## 图片本地化

```dart
Future<List<String>> _localizeImages(List<String> imageUrls) async {
    // 去重
    final uniqueUrls = imageUrls.toSet().toList();
    
    // 分批并发下载（控制并发数为 3）
    for (var i = 0; i < uniqueUrls.length; i += 3) {
        final batch = uniqueUrls.skip(i).take(3);
        await Future.wait(batch.map(downloadAndSaveImage));
    }
    
    return localPaths;
}
```
