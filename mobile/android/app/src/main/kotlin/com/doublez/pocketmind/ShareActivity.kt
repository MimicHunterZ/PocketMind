package com.doublez.pocketmind // 请替换为你的包名

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/**
 * 透明的分享接收 Activity (单一 FlutterActivity 架构)
 *
 * 职责：
 * 1. 作为 Manifest.xml 中的分享入口 (ACTION_SEND)
 * 2. 使用 singleTask 模式，支持冷启动和热启动
 * 3. 预热并缓存 Flutter 引擎（仅在冷启动时）
 * 4. 通过 MethodChannel 通知 Dart 端显示新的分享 UI
 *
 * 架构说明：
 * - 冷启动：onCreate() -> 初始化引擎 -> onWindowFocusChanged() -> 调用 handleShare()
 * - 热启动：onNewIntent() -> onWindowFocusChanged() -> 直接调用 handleShare()
 *
 * 剪贴板读取说明：
 * - Android 10+ 只允许前台应用访问剪贴板
 * - 在 onWindowFocusChanged(true) 中读取，这是最可靠的时机
 * - 使用 pendingClipboardRead 标记，避免在错误时机读取
 */
class ShareActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ShareActivity"
        private const val CHANNEL = "com.doublez.pocketmind/share"
        private const val ENGINE_ID = "share_engine"
    }
    

    private var methodChannel: MethodChannel? = null
    private var pendingShareData: ShareData? = null // 保存待处理的分享数据
    private var isEngineReady = false // 引擎是否已准备好

    // 标记是否需要在 onWindowFocusChanged 中读取剪贴板
    private var pendingClipboardRead = false

    // 默认情况下，FlutterActivity 出于性能考虑，会使用一种名为 BackgroundMode.opaque（不透明）的渲染模式
    // 通过重写 getBackgroundMode()，强制要求它使用透明背景。
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "========================================")
        Log.d(TAG, "ShareActivity onCreate - 冷启动")
        Log.d(TAG, "========================================")

        val customAction = intent?.getStringExtra("action")
        Log.d(TAG, "onCreate: customAction = $customAction")

        // 分离剪贴板和 ACTION_SEND
        if (customAction == "read_clipboard") {
            Log.d(TAG, "onCreate: 来源是 QSTile/Notification. 标记待处理。")
            // 1. 仅标记需要读取剪贴板
            pendingClipboardRead = true
            // 2. ✅ 修复：不要设置 pendingShareData 占位符
            Log.d(TAG, "onCreate: pendingClipboardRead 已设置为 true")
        } else {
            Log.d(TAG, "onCreate: 来源是 ACTION_SEND")
            // 1. 正常解析
            val shareData = parseShareIntent(intent)
            if (shareData != null) {
                // 2. 保存真实数据
                pendingShareData = shareData
                Log.d(TAG, "onCreate: 保存待处理的分享数据: title:${shareData.title},content:${shareData.content.take(50)}")

                // 3. 检查引擎（热启动时 provideFlutterEngine 先执行，isEngineReady 可能为 true）
                if (isEngineReady && methodChannel != null) {
                    Log.d(TAG, "onCreate: 引擎已就绪（热启动），立即处理分享")
                    notifyDartToShowShare(shareData)
                    pendingShareData = null
                } else {
                    Log.d(TAG, "onCreate: 引擎未就绪，等待引擎准备")
                }
            } else {
                Log.w(TAG, "onCreate: 无法解析的 ACTION_SEND 数据")
                finish()
            }
        }

        Log.d(TAG, "onCreate 结束: pendingClipboardRead=$pendingClipboardRead, isEngineReady=$isEngineReady")
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "onStart: pendingClipboardRead=$pendingClipboardRead")
    }

    //  只处理 ACTION_SEND 的冷启动待处理数据
    // 剪贴板读取逻辑移至 onWindowFocusChanged
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "========================================")
        Log.d(TAG, "=== onResume 开始 ===")
        Log.d(TAG, "========================================")
        Log.d(TAG, "onResume: Activity 已完全前台")
        Log.d(TAG, "onResume: pendingClipboardRead = $pendingClipboardRead")
        Log.d(TAG, "onResume: isEngineReady = $isEngineReady")
        Log.d(TAG, "onResume: methodChannel = ${if (methodChannel != null) "已初始化" else "null"}")
        Log.d(TAG, "onResume: pendingShareData = ${pendingShareData?.title ?: "null"}")

        if (pendingClipboardRead) {
            // 等待 onWindowFocusChanged(true)
            Log.d(TAG, "onResume: 是剪贴板读取请求，等待窗口获得焦点...")
        } else {
            // 处理 ACTION_SEND 在冷启动时引擎未就绪的情况
            // (此时 isEngineReady 可能刚变为 true, 但 onWindowFocusChanged 不会处理它)
            pendingShareData?.let { data ->
                if (isEngineReady && methodChannel != null) {
                    Log.d(TAG, "onResume: 引擎已就绪，发送待处理的 ACTION_SEND 数据")
                    notifyDartToShowShare(data)
                    pendingShareData = null
                } else {
                    Log.d(TAG, "onResume: 引擎未就绪，继续等待 (ACTION_SEND)")
                }
            }
        }

        Log.d(TAG, "========================================")
        Log.d(TAG, "=== onResume 结束 ===")
        Log.d(TAG, "onResume 结束状态: pendingShareData=${pendingShareData?.title ?: "null"}")
        Log.d(TAG, "========================================")
    }

    /**
     * 重点：！！！！在窗口获得焦点时读取剪贴板，只有在这边才能获取，onResume 那边获取不到！！！！！
     *
     * 这是比 onResume() 更可靠的时机，因为它保证了 Activity 真正对用户可见并获得了焦点，
     * 解决了因系统动画或窗口切换延迟导致剪贴板访问失败的问题。
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.d(TAG, "onWindowFocusChanged: hasFocus = $hasFocus, pendingClipboardRead = $pendingClipboardRead")

        // 仅在 获得焦点 且 标记 了需要读取剪贴板时 执行一次
        if (hasFocus && pendingClipboardRead) {
            Log.d(TAG, "onWindowFocusChanged: ✅ 获得焦点，开始读取剪贴板")
            pendingClipboardRead = false // 清除标记，防止重复执行

            val clipboardData = parseClipboardIntent()

            // 在这里才设置 pendingShareData
            pendingShareData = clipboardData

            if (clipboardData != null) {
                Log.d(TAG, "onWindowFocusChanged: ✅ 成功读取剪贴板")
                Log.d(TAG, "onWindowFocusChanged: 剪贴板数据 - title: ${clipboardData.title}")

                // 检查引擎是否已准备好
                if (isEngineReady && methodChannel != null) {
                    Log.d(TAG, "onWindowFocusChanged: 引擎已就绪，立即发送剪贴板数据")
                    notifyDartToShowShare(clipboardData)
                    pendingShareData = null // 发送后清除
                } else {
                    Log.d(TAG, "onWindowFocusChanged: 引擎未就绪，保存剪贴板数据等待")
                    // 数据已保存在 pendingShareData，等待 setupMethodChannel 中的 'engineReady' 信号
                }
            } else {
                Log.e(TAG, "onWindowFocusChanged: ❌ 剪贴板为空或读取失败")
                Toast.makeText(this, "剪贴板为空", Toast.LENGTH_SHORT).show()
                // pendingShareData 此时为 null，这是正确的。
                // 'engineReady' 处理器后续触发时，会发现 pendingShareData == null，不会做任何事。
                finish()
            }
        } else if (hasFocus) {
            Log.d(TAG, "onWindowFocusChanged: 获得焦点，但无需读取剪贴板")
        }
    }


    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause: isFinishing=$isFinishing, pendingClipboardRead=$pendingClipboardRead, pendingShareData=${pendingShareData?.title ?: "null"}")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "onStop: isFinishing=$isFinishing, pendingClipboardRead=$pendingClipboardRead, pendingShareData=${pendingShareData?.title ?: "null"}")
    }

    // 添加异常处理和更详细的日志
    private fun parseClipboardIntent(): ShareData? {
        Log.d(TAG, "parseClipboardIntent: 开始读取剪贴板")

        try {
            // 使用 Activity 的 context，确保是前台应用
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            Log.d(TAG, "parseClipboardIntent: ClipboardManager 已获取")

            val hasPrimaryClip = clipboard.hasPrimaryClip()
            Log.d(TAG, "parseClipboardIntent: hasPrimaryClip = $hasPrimaryClip")

            if (!hasPrimaryClip) {
                Log.w(TAG, "parseClipboardIntent: 剪贴板为空 (hasPrimaryClip = false)")
                return null
            }

            val clip = clipboard.primaryClip
            Log.d(TAG, "parseClipboardIntent: primaryClip = ${if (clip != null) "存在" else "null"}")

            // 确保剪贴板有内容
            if (clip == null) {
                Log.w(TAG, "parseClipboardIntent: clip is null")
                return null
            }

            val itemCount = clip.itemCount
            Log.d(TAG, "parseClipboardIntent: itemCount = $itemCount")

            if (itemCount == 0) {
                Log.w(TAG, "parseClipboardIntent: itemCount = 0")
                return null
            }

            val item = clip.getItemAt(0)
            Log.d(TAG, "parseClipboardIntent: item = ${if (item != null) "存在" else "null"}")

            val text = item?.text?.toString()
            Log.d(TAG, "parseClipboardIntent: text = ${if (text != null) "存在(长度=${text.length})" else "null"}")

            if (text.isNullOrBlank()) {
                Log.w(TAG, "parseClipboardIntent: 剪贴板文本内容为空或仅包含空白字符")

                // 尝试获取其他类型的数据
                val uri = item?.uri
                Log.d(TAG, "parseClipboardIntent: uri = $uri")

                val coerceText = item?.coerceToText(this)?.toString()
                Log.d(TAG, "parseClipboardIntent: coerceText = ${if (coerceText != null) "存在(长度=${coerceText.length})" else "null"}")

                // ✅ 修复：如果 coerceText 也有内容，应该返回它
                if (!coerceText.isNullOrBlank()) {
                    Log.d(TAG, "parseClipboardIntent: 使用 coerceToText() 作为备选: ${coerceText.take(50)}")
                    return ShareData("来自剪贴板", coerceText)
                }

                return null
            }

            val title = "来自剪贴板"
            // 记录读取成功的日志（截取前50个字符避免日志过长）
            Log.d(TAG, "parseClipboardIntent: ✅ 成功读取剪贴板")
            Log.d(TAG, "parseClipboardIntent: 内容预览: ${text.take(50)}${if (text.length > 50) "..." else ""}")

            // 复用 ShareData
            return ShareData(title, text)

        } catch (e: SecurityException) {
            // Android 10+ 后台访问剪贴板会抛出 SecurityException
            Log.e(TAG, "parseClipboardIntent: ❌ 无权限访问剪贴板 (SecurityException): ${e.message}")
            Toast.makeText(this, "无权限访问剪贴板", Toast.LENGTH_SHORT).show()
            e.printStackTrace()
            return null
        } catch (e: Exception) {
            // 捕获其他可能的异常
            Log.e(TAG, "parseClipboardIntent: ❌ 读取剪贴板失败: ${e.message}", e)
            e.printStackTrace()
            return null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "========================================")
        Log.d(TAG, "ShareActivity onNewIntent - 热启动")
        Log.d(TAG, "========================================")

        val customAction = intent.getStringExtra("action")
        Log.d(TAG, "onNewIntent: customAction = $customAction")

        // 分离剪贴板和 ACTION_SEND
        if (customAction == "read_clipboard") {
            Log.d(TAG, "onNewIntent: 来源是 QSTile/Notification. 标记待处理。")
            // 1. 标记读取
            pendingClipboardRead = true
            // 2. 清除可能存在的旧 ACTION_SEND 数据
            pendingShareData = null
            Log.d(TAG, "onNewIntent: pendingClipboardRead 已设置为 true")
        } else {
            Log.d(TAG, "onNewIntent: 来源是 ACTION_SEND")
            // 1. 清除剪贴板标记
            pendingClipboardRead = false
            // 2. 解析新数据
            val shareData = parseShareIntent(intent)
            if (shareData != null) {
                Log.d(TAG, "onNewIntent: 保存待处理的分享数据: ${shareData.title}")
                pendingShareData = shareData

                // 3. 引擎已就绪（热启动），立即处理
                if (isEngineReady && methodChannel != null) {
                    Log.d(TAG, "onNewIntent: 引擎已就绪（热启动），立即处理分享")
                    notifyDartToShowShare(shareData)
                    pendingShareData = null
                } else {
                    // 这种情况几乎不会发生，因为热启动 = 引擎已就绪
                    Log.w(TAG, "onNewIntent: 引擎未就绪 (异常情况)，等待引擎准备")
                }
            } else {
                Log.w(TAG, "onNewIntent: 无法解析的分享数据，关闭 Activity")
                finish()
            }
        }

        Log.d(TAG, "onNewIntent 结束: pendingClipboardRead=$pendingClipboardRead")
    }

    /**
     * 提供缓存的 Flutter 引擎
     * 仅在冷启动时创建引擎，热启动时直接复用
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        Log.d(TAG, "provideFlutterEngine 开始")

        var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
        val isHotStart = engine != null // 引擎存在说明是热启动

        Log.d(TAG, "provideFlutterEngine: isHotStart = $isHotStart")

        if (engine == null) {
            Log.d(TAG, "创建新的 Flutter 引擎 (main_share)")

            val flutterLoader = FlutterInjector.instance().flutterLoader()
            // 确保 FlutterLoader 已初始化
            if (!flutterLoader.initialized()) {
                Log.d(TAG, "初始化 FlutterLoader")
                flutterLoader.startInitialization(applicationContext)
                flutterLoader.ensureInitializationComplete(context, null)
            }

            val appBundlePath = flutterLoader.findAppBundlePath()
            // flutterLoader 已经初始化了的话 appBundlePath 不会为空
            engine = FlutterEngine(this).apply {
                dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        appBundlePath,
                        // 启动flutter应用的第二个入口
                        "package:pocketmind/main_share.dart",
                        "mainShare"
                    )
                )
            }

            // 缓存引擎供后续使用
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

            Log.d(TAG, "Flutter 引擎已创建并缓存")
        } else {
            Log.d(TAG, "复用缓存的 Flutter 引擎（热启动）")
            // 热启动时，引擎已经存在，Dart 端也已经准备好了
            isEngineReady = true
            Log.d(TAG, "provideFlutterEngine: isEngineReady 设置为 true")
        }

        // 关键：无论冷启动还是热启动，都重新设置 MethodChannel
        // 因为 Activity 重新创建后，methodChannel 实例变量会被重置为 null
        setupMethodChannel(engine)

        Log.d(TAG, "provideFlutterEngine 结束")
        return engine
    }

    /**
     * 设置 MethodChannel
     */
    private fun setupMethodChannel(engine: FlutterEngine) {
        Log.d(TAG, "setupMethodChannel 开始")

        engine.dartExecutor.binaryMessenger.let { messenger ->
            methodChannel = MethodChannel(messenger, CHANNEL)
            Log.d(TAG, "setupMethodChannel: MethodChannel 已创建")

            // 设置方法调用处理器，监听 Dart 端的"准备好"信号
            methodChannel?.setMethodCallHandler { call, result ->
                Log.d(TAG, "setupMethodChannel: 收到来自 Dart 的调用: ${call.method}")

                when (call.method) {
                    "engineReady" -> {
                        Log.d(TAG, "收到 Dart 端准备就绪信号")
                        isEngineReady = true
                        Log.d(TAG, "setupMethodChannel: isEngineReady 设置为 true")
                        result.success(null)

                        // 引擎准备好后，处理待处理的分享数据
                        pendingShareData?.let { data ->
                            Log.d(TAG, "setupMethodChannel: 发现待处理数据: ${data.title}")
                            // 现在 pendingShareData 要么是 null, 要么是真实数据
                            // 无论是剪贴板(冷启动)还是 ACTION_SEND(冷启动)，都直接发送
                            Log.d(TAG, "处理待处理的分享数据: ${data.title}")
                            notifyDartToShowShare(data)
                            pendingShareData = null // 清除已处理的数据
                        } ?: Log.d(TAG, "setupMethodChannel: 无待处理数据")
                    }
                    
                    else -> result.notImplemented()
                }
            }

            Log.d(TAG, "MethodChannel 已重新设置，isEngineReady=$isEngineReady")

            // 注册日志通道
            val loggerChannel = MethodChannel(messenger, "com.doublez.pocketmind/logger")
            loggerChannel.setMethodCallHandler { call, result ->
                if (call.method == "log") {
                    Log.d(call.argument("tag") ?: "FlutterLog", call.argument("message") ?: "")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }


        }

        Log.d(TAG, "setupMethodChannel 结束")
    }

    /**
     * 解析分享 Intent 并返回数据
     */
    private fun parseShareIntent(intent: Intent?): ShareData? {
        val action = intent?.action
        val type = intent?.type

        Log.d(TAG, "解析 Intent: action=$action, type=$type")

        when {
            action == Intent.ACTION_SEND && type != null -> {
                return when {
                    type.startsWith("text/") -> {
                        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: "分享内容"
                        ShareData(title, text)
                    }
                    type.startsWith("image/") -> {
                        val uri: android.net.Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            // Android 13 (API 33) 及以上使用新方法
                            intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
                        } else {
                            // Android 13 以下使用旧方法
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(Intent.EXTRA_STREAM)
                        }
                        if (uri == null) return null
                        ShareData(title = "分享图片", content = uri.toString())
                    }
                    else -> {
                        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: "分享内容"
                        ShareData(title, text)
                    }
                }
            }
            action == Intent.ACTION_SEND_MULTIPLE && type != null -> {
                val uris = intent.getParcelableArrayListExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                    ?: return null
                if (uris.isEmpty()) return null
                val title = "分享 ${uris.size} 项"
                val content = uris.joinToString("\n") { it.toString() }
                return ShareData(title, content)
            }
            else -> return null
        }
    }

    /**
     * 通过 MethodChannel 通知 Dart 端显示分享 UI
     */
    private fun notifyDartToShowShare(data: ShareData) {
        Log.d(TAG, "notifyDartToShowShare 开始")
        Log.d(TAG, "notifyDartToShowShare: title=${data.title}, content长度=${data.content.length}")

        // 确保 MethodChannel 已初始化
        if (methodChannel == null) {
            Log.w(TAG, "notifyDartToShowShare: methodChannel 为 null，尝试重新设置")
            flutterEngine?.let { setupMethodChannel(it) }
        }

        // 再次检查
        if (methodChannel == null) {
            Log.e(TAG, "notifyDartToShowShare: methodChannel 仍然为 null！无法发送。")
            return
        }

        val payload = mapOf(
            "title" to data.title,
            "content" to data.content,
            "timestamp" to System.currentTimeMillis()
        )

        Log.d(TAG, "发送 showShare 到 Dart: ${data.title}")
        // 对应 dart 中的 showShare 方法调用
        methodChannel?.invokeMethod("showShare", payload, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.d(TAG, "✅ Dart 已接收 showShare")
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e(TAG, "❌ Dart 处理失败: $errorMessage")
            }
            override fun notImplemented() {
                Log.w(TAG, "❌ showShare 方法未实现")
            }
        })

        Log.d(TAG, "notifyDartToShowShare 结束")
    }

    /**
     * 用于封装分享数据的简单类
     */
    data class ShareData(val title: String, val content: String)

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "ShareActivity onDestroy")
        // 注意：引擎不销毁，保持缓存供下次使用
    }
}