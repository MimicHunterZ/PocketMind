package com.doublez.pocketmind

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.doublez.pocketmind.service.ScraperForegroundService

class MainActivity : FlutterActivity() {

	companion object {
		private const val LOG_CHANNEL = "com.doublez.pocketmind/logger"
		private const val SCRAPER_CHANNEL = "com.doublez.pocketmind/scraper"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "configureFlutterEngine")

		// 日志 Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL).setMethodCallHandler { call, result ->
			if (call.method != "log") {
				result.notImplemented()
				return@setMethodCallHandler
			}

			val tag = call.argument<String>("tag")?.ifBlank { "pocketmind" } ?: "pocketmind"
			val level = call.argument<String>("level")?.lowercase() ?: "debug"
			val message = call.argument<String>("message") ?: ""
			val error = call.argument<String>("error")
			val stackTrace = call.argument<String>("stackTrace")

			val fullMessage = buildString {
				if (message.isNotBlank()) {
					append(message)
				}
				if (!error.isNullOrBlank()) {
					if (isNotEmpty()) append('\n')
					append("error: ")
					append(error)
				}
				if (!stackTrace.isNullOrBlank()) {
					if (isNotEmpty()) append('\n')
					append(stackTrace)
				}
			}

			when (level) {
				"verbose" -> Log.v(tag, fullMessage)
				"debug" -> Log.d(tag, fullMessage)
				"info" -> Log.i(tag, fullMessage)
				"warn" -> Log.w(tag, fullMessage)
				"error" -> Log.e(tag, fullMessage)
				"fatal" -> Log.wtf(tag, fullMessage)
				else -> Log.d(tag, fullMessage)
			}

			result.success(null)
		}

		// 爬虫服务 Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCRAPER_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"startForegroundService" -> {
					val taskCount = call.argument<Int>("taskCount") ?: 0
					ScraperForegroundService.start(this, taskCount)
					Log.d("MainActivity", "启动爬虫前台服务, taskCount=$taskCount")
					result.success(true)
				}
				"stopForegroundService" -> {
					ScraperForegroundService.stop(this)
					Log.d("MainActivity", "停止爬虫前台服务")
					result.success(true)
				}
				"updateProgress" -> {
					val currentUrl = call.argument<String>("currentUrl") ?: ""
					val pendingCount = call.argument<Int>("pendingCount") ?: 0
					ScraperForegroundService.updateProgress(this, currentUrl, pendingCount)
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}
	}

    override fun onResume() {
        super.onResume()
        Log.d("MainActivity", "onResume")
    }

    override fun onPause() {
        super.onPause()
        Log.d("MainActivity", "onPause")
    }

    override fun onStop() {
        super.onStop()
        Log.d("MainActivity", "onStop")
    }
}
