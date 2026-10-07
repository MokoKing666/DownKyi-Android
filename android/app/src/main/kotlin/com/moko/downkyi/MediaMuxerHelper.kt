package com.moko.downkyi

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * 用系统 MediaMuxer 把 B 站的 m4s 重新封装为可正常播放的 mp4。
 *
 * 关键设计：**输入文件里的所有音视频轨都会被原样搬运**，而不是只取第一条视频轨。
 * 这一点很关键 ——
 * - durl 直链下载到的是一个完整 mp4，音视频在同一个文件里；
 *   若只 selectTrack 第一条视频轨，音频会被静默丢掉（表现为「合并出来的视频没声音」）；
 * - 单独下载音频时，输出应当是 m4a，不能因为没有视频轨就整体失败；
 * - 视频 m4s + 音频 m4s 两个文件时，两条轨都会被搬到同一个 mp4 里。
 *
 * 全程不重新编码，只做封装，因此速度快、画质无损。
 */
object MediaMuxerHelper {

    private const val BUFFER_SIZE = 1 shl 20

    /** 一条待搬运的轨道：(所属输入, 输入轨下标) -> 输出轨下标 */
    private class TrackRef(val extractor: MediaExtractor, val source: Int) {
        var target: Int = -1
    }

    fun remux(videoPath: String?, audioPath: String?, outputPath: String): Boolean {
        val inputs = listOfNotNull(
            videoPath?.takeIf { it.isNotEmpty() && File(it).exists() },
            audioPath?.takeIf { it.isNotEmpty() && File(it).exists() },
        ).distinct()
        if (inputs.isEmpty()) return false

        val extractors = mutableListOf<MediaExtractor>()
        var muxer: MediaMuxer? = null
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
                        refs.add(TrackRef(extractor, index))
                        accepted++
                    }
                    if (accepted > 0) {
                        extractors.add(extractor)
                    } else {
                        extractor.release()
                    }
                } catch (error: Throwable) {
                    try {
                        extractor.release()
                    } catch (_: Throwable) {
                        // 忽略
                    }
                }
            }
            if (refs.isEmpty()) return false

            File(outputPath).parentFile?.let { if (!it.exists()) it.mkdirs() }
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            for (ref in refs) {
                ref.target = muxer.addTrack(ref.extractor.getTrackFormat(ref.source))
            }
            muxer.start()

            val buffer = ByteBuffer.allocateDirect(BUFFER_SIZE)
            val info = MediaCodec.BufferInfo()
            val finished = BooleanArray(refs.size)
            val lastWritten = LongArray(refs.size) { Long.MIN_VALUE }

            // 把所有轨道的样本按时间戳交错写入
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
                    if (time < pickTime) {
                        pickTime = time
                        pick = index
                    }
                }
                if (pick < 0) break

                val ref = refs[pick]
                buffer.clear()
                val size = ref.extractor.readSampleData(buffer, 0)
                if (size < 0) {
                    finished[pick] = true
                    continue
                }
                var time = ref.extractor.sampleTime
                // MediaMuxer 要求同一轨道的时间戳严格递增，重复时间戳会直接抛异常
                if (time <= lastWritten[pick]) time = lastWritten[pick] + 1
                lastWritten[pick] = time

                info.offset = 0
                info.size = size
                info.presentationTimeUs = time
                info.flags = ref.extractor.sampleFlags
                muxer.writeSampleData(ref.target, buffer, info)
                ref.extractor.advance()
            }
            return true
        } catch (_: Throwable) {
            try {
                File(outputPath).delete()
            } catch (_: Throwable) {
                // 忽略
            }
            return false
        } finally {
            try {
                muxer?.stop()
            } catch (_: Throwable) {
                // 忽略
            }
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
}
