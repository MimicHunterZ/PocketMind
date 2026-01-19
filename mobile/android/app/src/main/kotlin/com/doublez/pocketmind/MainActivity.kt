package com.doublez.pocketmind

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
