package com.doublez.pocketmind.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.doublez.pocketmind.MainActivity
import com.doublez.pocketmind.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 爬虫前台服务
 *
 * 在后台执行爬虫任务时启动前台服务，防止进程被系统杀死
 * 通过 MethodChannel 与 Flutter 通信
 */
class ScraperForegroundService : Service() {

    companion object {
        private const val TAG = "ScraperForegroundService"
        private const val CHANNEL_ID = "scraper_channel"
        private const val CHANNEL_NAME = "后台抓取"
        private const val NOTIFICATION_ID = 1001
        const val METHOD_CHANNEL = "com.doublez.pocketmind/scraper"

        private var instance: ScraperForegroundService? = null

        /**
         * 启动前台服务
         */
        fun start(context: Context, taskCount: Int = 0) {
            val intent = Intent(context, ScraperForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_COUNT, taskCount)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * 停止前台服务
         */
        fun stop(context: Context) {
            val intent = Intent(context, ScraperForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        /**
         * 更新任务进度
         */
        fun updateProgress(context: Context, currentUrl: String, pendingCount: Int) {
            val intent = Intent(context, ScraperForegroundService::class.java).apply {
                action = ACTION_UPDATE_PROGRESS
                putExtra(EXTRA_CURRENT_URL, currentUrl)
                putExtra(EXTRA_PENDING_COUNT, pendingCount)
            }
            context.startService(intent)
        }

        private const val ACTION_START = "com.doublez.pocketmind.action.START_SCRAPER"
        private const val ACTION_STOP = "com.doublez.pocketmind.action.STOP_SCRAPER"
        private const val ACTION_UPDATE_PROGRESS = "com.doublez.pocketmind.action.UPDATE_PROGRESS"
        private const val EXTRA_TASK_COUNT = "task_count"
        private const val EXTRA_CURRENT_URL = "current_url"
        private const val EXTRA_PENDING_COUNT = "pending_count"
    }

    private var taskCount = 0
    private var currentUrl: String = ""
    private var pendingCount = 0

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                taskCount = intent.getIntExtra(EXTRA_TASK_COUNT, 0)
                currentUrl = ""
                pendingCount = taskCount
                startForeground(NOTIFICATION_ID, createNotification())
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_UPDATE_PROGRESS -> {
                currentUrl = intent.getStringExtra(EXTRA_CURRENT_URL) ?: ""
                pendingCount = intent.getIntExtra(EXTRA_PENDING_COUNT, 0)
                updateNotification()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    /**
     * 创建通知渠道（Android 8.0+）
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // 低优先级，不发出声音
            ).apply {
                description = "后台抓取网页内容"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * 创建通知
     */
    private fun createNotification(): Notification {
        // 点击通知打开主界面
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentText = if (currentUrl.isNotEmpty()) {
            val displayUrl = if (currentUrl.length > 40) {
                currentUrl.take(40) + "..."
            } else {
                currentUrl
            }
            "正在抓取: $displayUrl"
        } else {
            "准备中..."
        }

        val subText = if (pendingCount > 0) "等待: $pendingCount" else null

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("正在抓取内容")
            .setContentText(contentText)
            .setSubText(subText)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    /**
     * 更新通知
     */
    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, createNotification())

        // 如果所有任务完成，停止服务
        if (pendingCount <= 0 && taskCount > 0) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }
}
