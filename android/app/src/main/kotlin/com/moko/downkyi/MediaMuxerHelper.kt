package com.moko.downkyi

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import java.io.File
import java.nio.ByteBuffer

/**
 * 用系统 MediaMuxer 把 B 站的 m4s 重新封装为可正常播放的 mp4。
 *
 * 关键设计：**输入文件里的所有音视频轨都会被原样搬运**，而不是只取第一条视频轨。
 * - durl 直链下载到的是一个完整 mp4，音视频在同一个文件里；若只 selectTrack
 *   第一条视频轨，音频会被静默丢掉（表现为「合并出来的视频没声音」）；
 * - 单独下载音频时，输出应当是 m4a，不能因为没有视频轨就整体失败；
 * - 视频 m4s + 音频 m4s 两个文件时，两条轨都会被搬到同一个 mp4 里。
 *
 * 全程不重新编码，只做封装，因此速度快、画质无损。
 */
object MediaMuxerHelper {

    /** 单帧缓冲初始 4MB */
    private const val INITIAL_BUFFER_SIZE = 4 shl 20

    /** 动态扩容上限 64MB，避免极端 8K 关键帧把内存吃穿 */
    private const val MAX_BUFFER_SIZE = 64 shl 20

    /**
     * MediaMuxer **从 Android 7.1（API 25 / Nougat MR1）起才支持把 B 帧封装进 MP4**。
     *
     * B 站视频普遍带 B 帧，而 B 帧在解码顺序里的 PTS 本来就是回退的
     * （例如 I(0) P(3) B(1) B(2)），所以 API 25+ 必须**原样写入真实 PTS**。
     * 早先的实现为了满足「时间戳必须单调」把回退的 PTS 改写成 last+1，
     * 结果帧的显示时刻被压平、显示顺序错乱，表现就是「合并出来的视频卡卡的」。
     *
     * 只有 API 24 需要退回单调处理——那里本来就不支持 B 帧，压平是唯一能封装成功的办法。
     */
    private val supportsBFrames = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1

    /** 一条待搬运的轨道：(所属输入, 输入轨下标) -> 输出轨下标 */
    private class TrackRef(val extractor: MediaExtractor, val source: Int) {
        var target: Int = -1
        var isVideo: Boolean = false
        var isAudio: Boolean = false
    }

    fun remux(videoPath: String?, audioPath: String?, outputPath: String): Boolean {
        val inputs = listOfNotNull(
            videoPath?.takeIf { it.isNotEmpty() && File(it).exists() },
            audioPath?.takeIf { it.isNotEmpty() && File(it).exists() },
        ).distinct()
        if (inputs.isEmpty()) return false

        val extractors = mutableListOf<MediaExtractor>()
        var muxer: MediaMuxer? = null
        var muxerStopped = false
        try {
            val refs = mutableListOf<TrackRef>()
            for (path in inputs) {
                val extractor = MediaExtractor()
                var accepted = 0
                try {
                    extractor.setDataSource(path)
                    for (index in 0 until extractor.trackCount) {
                        val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)
                        if (mime == null) continue
                        if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue
                        extractor.selectTrack(index)
                        val ref = TrackRef(extractor, index)
                        ref.isVideo = mime.startsWith("video/")
                        ref.isAudio = mime.startsWith("audio/")
                        refs.add(ref)
                        accepted++
                    }
                    if (accepted > 0) {
                        extractors.add(extractor)
                    } else {
                        extractor.release()
                    }
                } catch (_: Throwable) {
                    try {
                        extractor.release()
                    } catch (_: Throwable) {
                        // 忽略
                    }
                }
            }
            if (refs.isEmpty()) return false

            val expectVideo = refs.any { it.isVideo }
            val expectAudio = refs.any { it.isAudio }

            File(outputPath).parentFile?.let { if (!it.exists()) it.mkdirs() }
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            for (ref in refs) {
                ref.target = muxer.addTrack(ref.extractor.getTrackFormat(ref.source))
            }
            muxer.start()

            var buffer = ByteBuffer.allocateDirect(INITIAL_BUFFER_SIZE)
            val info = MediaCodec.BufferInfo()
            val finished = BooleanArray(refs.size)
            val lastWritten = LongArray(refs.size) { Long.MIN_VALUE }
            // 交错用的进度键：记录该轨已读到的最大时间戳，保证单调
            val progress = LongArray(refs.size) { Long.MIN_VALUE }

            // 所有轨道的样本按时间戳交错写入；每条轨内部始终保持 extractor 的读取顺序
            // （也就是解码顺序），不会因为 PTS 回退而被重排
            while (true) {
                var pick = -1
                var pickTime = Long.MAX_VALUE
                for (index in refs.indices) {
                    if (finished[index]) continue
                    val time = refs[index].extractor.sampleTime
                    if (time < 0) {
                        finished[index] = true
                        continue
                    }
                    // 用「已读到的最大值」而不是当前 PTS 做交错依据：
                    // B 帧的 PTS 会回退，直接拿它比较会让交错顺序来回抖动
                    if (time > progress[index]) progress[index] = time
                    if (progress[index] < pickTime) {
                        pickTime = progress[index]
                        pick = index
                    }
                }
                if (pick < 0) break

                val ref = refs[pick]
                buffer.clear()
                val size: Int
                try {
                    size = ref.extractor.readSampleData(buffer, 0)
                } catch (tooSmall: IllegalArgumentException) {
                    // 极端 4K/8K 关键帧可能超过当前缓冲，按倍扩容后重试同一个样本
                    // （此时还没 advance，extractor 仍停在这一帧）
                    val current = buffer.capacity()
                    if (current >= MAX_BUFFER_SIZE) throw tooSmall
                    val grown = minOf(current * 2, MAX_BUFFER_SIZE)
                    buffer = ByteBuffer.allocateDirect(grown)
                    continue
                }
                if (size < 0) {
                    finished[pick] = true
                    continue
                }
                var time = ref.extractor.sampleTime
                if (!supportsBFrames) {
                    // 仅 API 24：MediaMuxer 还不支持 B 帧，只能把时间戳压成单调递增
                    if (time <= lastWritten[pick]) time = lastWritten[pick] + 1
                    lastWritten[pick] = time
                }

                info.offset = 0
                info.size = size
                info.presentationTimeUs = time
                info.flags = ref.extractor.sampleFlags
                muxer.writeSampleData(ref.target, buffer, info)
                ref.extractor.advance()
            }

            // 必须先 stop() 写出 moov，校验才有意义
            muxer.stop()
            muxerStopped = true

            // MediaMuxer 返回成功 ≠ 文件一定能播，这里再做一次轻量校验
            if (!verifyOutput(outputPath, expectVideo, expectAudio)) {
                File(outputPath).delete()
                return false
            }
            return true
        } catch (_: Throwable) {
            try {
                if (!muxerStopped) File(outputPath).delete()
            } catch (_: Throwable) {
                // 忽略
            }
            return false
        } finally {
            try {
                muxer?.release()
            } catch (_: Throwable) {
                // 忽略
            }
            for (extractor in extractors) {
                try {
                    extractor.release()
                } catch (_: Throwable) {
                    // 忽略
                }
            }
        }
    }

    /**
     * 封装后的轻量校验。
     *
     * MediaMuxer 返回成功并不代表文件可播放——轨道缺失、时长为 0、
     * 或根本读不出样本的情况都可能出现，而这些文件交到用户手里就是「下坏了」。
     * 校验失败时调用方会删掉产物，让上层保留原始分片并提示「重新合并」。
     */
    private fun verifyOutput(path: String, expectVideo: Boolean, expectAudio: Boolean): Boolean {
        val file = File(path)
        if (!file.exists() || file.length() < 1024) return false

        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(path)
            if (extractor.trackCount <= 0) return false

            var hasVideo = false
            var hasAudio = false
            var durationUs = 0L
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    durationUs = maxOf(durationUs, format.getLong(MediaFormat.KEY_DURATION))
                }
                if (mime.startsWith("video/")) hasVideo = true
                if (mime.startsWith("audio/")) hasAudio = true
            }
            if (expectVideo && !hasVideo) return false
            if (expectAudio && !hasAudio) return false
            if (durationUs <= 0) return false

            // 至少能读出一个样本
            extractor.selectTrack(0)
            val probe = ByteBuffer.allocateDirect(1 shl 16)
            extractor.readSampleData(probe, 0) >= 0
        } catch (_: Throwable) {
            false
        } finally {
            try {
                extractor.release()
            } catch (_: Throwable) {
                // 忽略
            }
        }
    }
}
