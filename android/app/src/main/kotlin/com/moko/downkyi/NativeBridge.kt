package com.moko.downkyi

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * Dart 侧 MethodChannel 的原生实现。
 * 通过它完成三件 Flutter 做不了的事：
 * 1. MediaMuxer 无损合并 m4s；
 * 2. 前台服务保活 + 通知栏进度；
 * 3. 通过 FileProvider / MediaStore 打开与导出文件。
 */
object NativeBridge {

    const val CHANNEL = "com.moko.downkyi/native"
    private const val REQ_NOTIFICATION = 3301

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mux" -> submit(activity, result) {
                val video = call.argument<String>("video")
                val audio = call.argument<String>("audio")
                val output = call.argument<String>("output")
                if (output == null) {
                    false
                } else {
                    MediaMuxerHelper.remux(video, audio, output)
                }
            }

            "openFile" -> {
                val path = call.argument<String>("path")
                val mime = call.argument<String>("mime") ?: "*/*"
                result.success(path != null && openFile(activity, path, mime))
            }

            "exportToPublic" -> submit(activity, result) {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime") ?: "video/mp4"
                val album = call.argument<String>("album") ?: "DownKyi"
                if (path == null || name == null) null
                else exportToPublic(activity, path, name, mime, album)
            }

            "fileSize" -> {
                val path = call.argument<String>("path")
                result.success(path?.let { sizeOf(activity, it) } ?: 0L)
            }

            "deleteFile", "deletePath" -> {
                val path = call.argument<String>("path")
                result.success(path != null && deletePath(activity, path))
            }

            // 把 MediaStore 的 content uri 复制成真实文件，供 FFmpeg 读取
            "copyToFile" -> submit(activity, result) {
                val path = call.argument<String>("path")
                val dest = call.argument<String>("dest")
                if (path == null || dest == null) false else copyToFile(activity, path, dest)
            }

            // 打开系统文件选择器（必须在主线程，且结果异步返回）
            "pickFile" -> {
                val host = activity as? MainActivity
                if (host == null) {
                    result.success(null)
                } else {
                    host.pickDocument(result)
                }
            }

            "renameFile" -> {
                val from = call.argument<String>("from")
                val to = call.argument<String>("to")
                if (from == null || to == null) {
                    result.success(false)
                } else {
                    result.success(rename(from, to))
                }
            }

            "externalFilesDir" -> {
                val sub = call.argument<String>("sub") ?: ""
                val dir = activity.getExternalFilesDir(if (sub.isEmpty()) null else sub)
                result.success(dir?.absolutePath)
            }

            "startService" -> {
                DownloadService.start(
                    activity,
                    call.argument<String>("title") ?: "哔哩下载姬",
                    call.argument<String>("text") ?: "下载中",
                    call.argument<Int>("progress") ?: -1
                )
                result.success(true)
            }

            "updateService" -> {
                DownloadService.update(
                    activity,
                    call.argument<String>("title") ?: "哔哩下载姬",
                    call.argument<String>("text") ?: "下载中",
                    call.argument<Int>("progress") ?: -1
                )
                result.success(true)
            }

            "stopService" -> {
                DownloadService.stop(activity)
                result.success(true)
            }

            "isWifi" -> result.success(isWifi(activity))

            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val granted = activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                        PackageManager.PERMISSION_GRANTED
                    if (!granted) {
                        activity.requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQ_NOTIFICATION
                        )
                    }
                    result.success(true)
                } else {
                    result.success(true)
                }
            }

            "sharedText" -> {
                val text = (activity as? MainActivity)?.sharedText
                result.success(text)
            }

            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------
    // 异步方法包装：mux / exportToPublic 不能在主线程跑
    // ------------------------------------------------------------------

    /** 把耗时任务放到子线程执行，结果回到主线程返回给 Dart */
    private fun <T> submit(activity: Activity, result: MethodChannel.Result, task: () -> T) {
        Thread {
            val value = try {
                task()
            } catch (_: Throwable) {
                null
            }
            activity.runOnUiThread { result.success(value) }
        }.start()
    }

    // ------------------------------------------------------------------
    // 具体实现
    // ------------------------------------------------------------------

    private fun rename(from: String, to: String): Boolean {
        return try {
            val src = File(from)
            if (!src.exists()) return false
            val dest = File(to)
            dest.parentFile?.mkdirs()
            src.renameTo(dest)
        } catch (_: Throwable) {
            false
        }
    }

    private fun openFile(activity: Activity, path: String, mime: String): Boolean {
        return try {
            val uri: Uri = if (path.startsWith("content://")) {
                // 已导出到 MediaStore 的文件，直接用 content uri
                val parsed = Uri.parse(path)
                val stream = try {
                    activity.contentResolver.openInputStream(parsed)
                } catch (_: Throwable) {
                    null
                }
                if (stream == null) return false
                stream.close()
                parsed
            } else {
                val file = File(path)
                if (!file.exists()) return false
                FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.fileprovider",
                    file
                )
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(Intent.createChooser(intent, "打开方式"))
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** 删除本地文件或 MediaStore 条目 */
    private fun deletePath(activity: Activity, path: String): Boolean {
        return try {
            if (path.startsWith("content://")) {
                activity.contentResolver.delete(Uri.parse(path), null, null) > 0
            } else {
                File(path).let { it.exists() && it.delete() }
            }
        } catch (_: Throwable) {
            false
        }
    }

    /** 把文件或 content uri 复制为真实文件（FFmpeg 只能读真实路径） */
    private fun copyToFile(activity: Activity, source: String, dest: String): Boolean {
        return try {
            val destFile = File(dest)
            destFile.parentFile?.mkdirs()
            if (destFile.exists()) destFile.delete()
            if (source.startsWith("content://")) {
                val input = activity.contentResolver.openInputStream(Uri.parse(source)) ?: return false
                input.use { from -> destFile.outputStream().use { to -> from.copyTo(to) } }
            } else {
                val src = File(source)
                if (!src.exists()) return false
                src.copyTo(destFile, overwrite = true)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** 文件大小，兼容 content uri */
    private fun sizeOf(activity: Activity, path: String): Long {
        return try {
            if (path.startsWith("content://")) {
                activity.contentResolver.openAssetFileDescriptor(Uri.parse(path), "r")?.use { it.length }
                    ?: 0L
            } else {
                File(path).takeIf { it.exists() }?.length() ?: 0L
            }
        } catch (_: Throwable) {
            0L
        }
    }

    /**
     * 导出到系统公共目录（相册）：
     * - Android 10+ 走 MediaStore（无需存储权限，相册/文件管理器可见）
     * - Android 9 及以下直接写入公共目录（需要 WRITE_EXTERNAL_STORAGE）
     *
     * 默认保存位置就是「系统相册」，因此下载完成后会走这里。
     */
    private fun exportToPublic(
        activity: Activity,
        path: String,
        displayName: String,
        mime: String,
        album: String
    ): String? {
        val src = File(path)
        if (!src.exists()) return null
        val isVideo = mime.startsWith("video")
        val isImage = mime.startsWith("image")
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val relativePath = when {
                    isVideo -> Environment.DIRECTORY_MOVIES
                    isImage -> Environment.DIRECTORY_PICTURES
                    else -> Environment.DIRECTORY_DOWNLOADS
                } + "/" + album
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val collection = when {
                    isVideo -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    isImage -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    else -> MediaStore.Downloads.EXTERNAL_CONTENT_URI
                }
                val uri = activity.contentResolver.insert(collection, values) ?: return null
                activity.contentResolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(src).use { input -> input.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                activity.contentResolver.update(uri, values, null, null)
                uri.toString()
            } else {
                val publicDir = File(
                    Environment.getExternalStoragePublicDirectory(
                        when {
                            isVideo -> Environment.DIRECTORY_MOVIES
                            isImage -> Environment.DIRECTORY_PICTURES
                            else -> Environment.DIRECTORY_DOWNLOADS
                        }
                    ),
                    album
                )
                if (!publicDir.exists()) publicDir.mkdirs()
                val dest = File(publicDir, displayName)
                FileInputStream(src).use { input -> dest.outputStream().use { input.copyTo(it) } }
                dest.absolutePath
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun isWifi(activity: Activity): Boolean {
        val manager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = manager.activeNetwork ?: return false
            val caps = manager.getNetworkCapabilities(network) ?: return false
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        } else {
            @Suppress("DEPRECATION")
            manager.activeNetworkInfo?.type == ConnectivityManager.TYPE_WIFI
        }
    }
}
