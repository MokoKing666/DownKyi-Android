package com.moko.downkyi

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val REQ_PICK_FILE = 3401
    }

    private var channel: MethodChannel? = null

    /** 系统文件选择器的待返回结果（同一时刻只允许一个） */
    private var pendingPick: MethodChannel.Result? = null

    /** 从系统分享进来的文本（分享链接 → 自动解析） */
    var sharedText: String? = null
        private set

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharedText = extractSharedText(intent)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NativeBridge.CHANNEL)
        ch.setMethodCallHandler { call, result -> NativeBridge.handle(this, call, result) }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 必须回写，否则后续 getIntent() 拿到的还是旧的启动 Intent
        setIntent(intent)
        sharedText = extractSharedText(intent)
    }

    /**
     * 打开系统文件选择器（SAF），选中后通过 MethodChannel 返回 content uri。
     *
     * 这里用经典的 startActivityForResult 而不是 registerForActivityResult：
     * 后者要求宿主是 ComponentActivity，兼容性不如前者。
     */
    fun pickDocument(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        pendingPick = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("video/*", "audio/*", "application/octet-stream")
                )
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQ_PICK_FILE)
        } catch (_: Throwable) {
            pendingPick = null
            result.success(null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_FILE) return
        val pending = pendingPick ?: return
        pendingPick = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        pending.success(uri?.toString())
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
