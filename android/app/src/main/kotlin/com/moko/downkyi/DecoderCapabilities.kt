package com.moko.downkyi

import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.util.Log

/**
 * 设备硬件解码能力探测（评审第 17 项）。
 *
 * 为什么要探测：B 站现在同一个视频会给出 AVC / HEVC / AV1 三种编码、以及
 * HDR / 杜比视界等档位。选错了不是「画质差一点」，而是**下完根本放不出来**——
 * 花 40 分钟下了 4K HDR HEVC，结果手机没有 10-bit 硬解，播放器要么黑屏要么
 * 软解到掉帧。所以在用户选档之前，先把设备的真实能力摆出来。
 *
 * 实现上只问 `MediaCodecList`（系统已知的硬解器），不做实际解码试探——
 * 后者要真的喂一帧数据，代价和风险都不合适。
 *
 * 已知边界：
 *   - 只反映**解码**能力，不含编码。本项目不依赖硬件编码（FFmpeg 软编）。
 *   - 某些设备的 profileLevels 上报不全，可能把能播的判成不能播。
 *     所以界面上的定位是「推荐」而不是「禁止」——用户仍然可以无视建议。
 *   - 判断不了「能不能流畅播 8K」这种性能问题，只能判断「能不能解」。
 */
object DecoderCapabilities {
    private const val TAG = "DecoderCaps"

    fun probe(): Map<String, Boolean> {
        val result = mutableMapOf(
            "avc" to false,
            "hevc" to false,
            "av1" to false,
            "hevc10bit" to false,
            "hdr" to false,
            "dolbyVision" to false
        )

        try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            for (info in codecList.codecInfos) {
                if (info.isEncoder) continue
                for (type in info.supportedTypes) {
                    when (type.lowercase()) {
                        "video/avc" -> result["avc"] = true
                        "video/hevc" -> {
                            result["hevc"] = true
                            val profiles = profilesOf(info, type)
                            // 下面这些常量都是编译期 final int，会被内联进字节码，
                            // 因此在 API < 29 的设备上引用它们也不会 NoSuchFieldError。
                            if (profiles.contains(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10) ||
                                profiles.contains(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10) ||
                                profiles.contains(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus)
                            ) {
                                result["hevc10bit"] = true
                            }
                            if (profiles.contains(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10) ||
                                profiles.contains(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus)
                            ) {
                                result["hdr"] = true
                            }
                            if (profiles.contains(MediaCodecInfo.CodecProfileLevel.DolbyVisionProfileDvheSt) ||
                                profiles.contains(MediaCodecInfo.CodecProfileLevel.DolbyVisionProfileDvheDtr) ||
                                profiles.contains(MediaCodecInfo.CodecProfileLevel.DolbyVisionProfileDvheStn)
                            ) {
                                result["dolbyVision"] = true
                            }
                        }
                        "video/av01" -> result["av1"] = true
                    }
                }
            }
        } catch (error: Exception) {
            // 探测失败不该影响任何功能，全部按「不支持」处理即可
            Log.w(TAG, "解码能力探测失败", error)
        }
        return result
    }

    private fun profilesOf(info: MediaCodecInfo, type: String): Set<Int> = try {
        info.getCapabilitiesForType(type).profileLevels?.map { it.profile }?.toSet() ?: emptySet()
    } catch (error: Exception) {
        emptySet()
    }
}
