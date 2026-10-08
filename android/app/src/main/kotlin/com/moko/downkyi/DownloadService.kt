package com.moko.downkyi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * 下载前台服务：仅负责保活 + 通知栏进度展示，真正的下载逻辑在 Dart 侧。
 */
class DownloadService : Service() {

    companion object {
        const val CHANNEL_ID = "downkyi_download"
        private const val CHANNEL_NAME = "下载任务"
        private const val NOTIFICATION_ID = 10086

        const val ACTION_START = "com.moko.downkyi.action.START"
        const val ACTION_UPDATE = "com.moko.downkyi.action.UPDATE"
        const val ACTION_STOP = "com.moko.downkyi.action.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"

        fun start(context: Context, title: String, text: String, progress: Int) {
            send(context, ACTION_START, title, text, progress)
        }

        fun update(context: Context, title: String, text: String, progress: Int) {
            send(context, ACTION_UPDATE, title, text, progress)
        }

        fun stop(context: Context) {
            try {
                val intent = Intent(context, DownloadService::class.java).apply {
                    action = ACTION_STOP
                }
                context.startService(intent)
            } catch (_: Throwable) {
                // 忽略：服务已结束
            }
        }

        private fun send(context: Context, action: String, title: String, text: String, progress: Int) {
            try {
                val intent = Intent(context, DownloadService::class.java).apply {
                    this.action = action
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_TEXT, text)
                    putExtra(EXTRA_PROGRESS, progress)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Throwable) {
                // 忽略：后台启动限制等情况
            }
        }
    }

    private var titleText: String = "哔哩哔哩下载姬"
    private var bodyText: String = "准备下载"
    private var progressValue: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        intent?.getStringExtra(EXTRA_TITLE)?.let { titleText = it }
        intent?.getStringExtra(EXTRA_TEXT)?.let { bodyText = it }
        progressValue = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW).apply {
            description = "显示下载进度"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder.setSmallIcon(R.drawable.ic_stat_downkyi)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
        if (progressValue < 0) {
            builder.setProgress(0, 0, true)
        } else {
            builder.setProgress(100, progressValue.coerceIn(0, 100), false)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        builder.setContentIntent(contentIntent)
        return builder.build()
    }
}
