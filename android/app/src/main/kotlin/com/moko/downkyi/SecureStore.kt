package com.moko.downkyi

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 敏感数据的加密存储。
 *
 * 为什么需要它：SESSDATA / bili_jct / DedeUserID / aria2 RPC 密钥此前和普通设置一起
 * 明文躺在 SharedPreferences 里。这两类东西的性质完全不同——
 * 设置被看到只是隐私问题，**Cookie 被拿到就等于账号被拿走**（SESSDATA 可直接
 * 用来调用任意已登录接口）。Android 的 SharedPreferences 位于应用私有目录，
 * root 设备、备份导出、部分定制 ROM 的「应用数据查看」都能读到明文。
 *
 * 实现：
 *   - 密钥由 **AndroidKeyStore** 生成并保管，`setKeySize(256)` + AES/GCM。
 *     密钥永远不离开 keystore（即使 root 也导不出），应用只能请求它做加解密。
 *   - 密文存进独立的 SharedPreferences（`downkyi_secure`），格式为 `IV || 密文`。
 *     每次加密都生成新 IV（GCM 的要求，复用 IV 会直接毁掉安全性）。
 *
 * 已知边界（写清楚，免得误以为它万能）：
 *   - 卸载重装 / 用户「清除数据」/ 系统重置会销毁 keystore 里的密钥，旧密文再也解不开。
 *     这时 [read] 会丢弃该条目并返回空串，让用户重新登录，而不是抛异常崩掉。
 *   - 它防的是「拿到文件」，不防「拿到已解锁且已 root 的设备」。
 */
object SecureStore {
    private const val TAG = "SecureStore"
    private const val KEY_ALIAS = "downkyi_secrets_v1"
    private const val PREFS_NAME = "downkyi_secure"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128
    private const val IV_BYTES = 12

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** 取出或首次生成密钥 */
    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getEntry(KEY_ALIAS, null)
        if (existing is KeyStore.SecretKeyEntry) return existing.secretKey

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    fun write(context: Context, key: String, value: String) {
        if (value.isEmpty()) {
            remove(context, key)
            return
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = cipher.iv + encrypted
        prefs(context).edit()
            .putString(key, Base64.encodeToString(payload, Base64.NO_WRAP))
            .apply()
    }

    fun read(context: Context, key: String): String {
        val stored = prefs(context).getString(key, null) ?: return ""
        return try {
            val payload = Base64.decode(stored, Base64.NO_WRAP)
            if (payload.size <= IV_BYTES) throw IllegalStateException("密文长度异常")
            val iv = payload.copyOfRange(0, IV_BYTES)
            val body = payload.copyOfRange(IV_BYTES, payload.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            String(cipher.doFinal(body), Charsets.UTF_8)
        } catch (error: Exception) {
            // 密钥没了（卸载重装/清除数据/系统重置）或密文损坏：丢弃，让用户重新登录。
            // 这里绝不能抛出去——否则一启动就在通道上炸，用户连设置页都进不去。
            Log.w(TAG, "无法解密 $key，已丢弃该条目", error)
            prefs(context).edit().remove(key).apply()
            ""
        }
    }

    fun remove(context: Context, key: String) {
        prefs(context).edit().remove(key).apply()
    }

    /** 退出登录时清空全部敏感数据 */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }
}
