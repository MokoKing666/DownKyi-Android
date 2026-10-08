/// FFmpeg 工具箱的参数构造（评审第 23 项）。
///
/// 刻意与 [FfmpegService] 分开、且全部是纯函数：ffmpeg 的参数顺序是有语义的，
/// 拼错了不会编译报错，只会得到一句难懂的运行时报错，或者更糟——
/// **静默地重新编码**（`-c copy` 放错位置），本来几秒的活儿变成几十分钟。
///
/// 所以这里只负责「把参数拼对」，单测直接断言拼出来的数组。
class FfmpegOps {
  const FfmpegOps._();

  /// ffmpeg 需要的 `HH:MM:SS.mmm`
  static String formatTimestamp(int milliseconds) {
    final value = milliseconds < 0 ? 0 : milliseconds;
    final ms = value % 1000;
    final totalSeconds = value ~/ 1000;
    final second = totalSeconds % 60;
    final minute = (totalSeconds ~/ 60) % 60;
    final hour = totalSeconds ~/ 3600;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(hour)}:${two(minute)}:${two(second)}.${ms.toString().padLeft(3, '0')}';
  }

  /// 无损截取。全程 `-c copy`，不重新编码，因此**几乎不花时间**——
  /// 这是工具箱里最实用的一项：把一段直播回放裁成片段，几秒就完成。
  static List<String> trim({
    required String input,
    required String output,
    required int startMs,
    required int endMs,
  }) {
    final start = startMs < 0 ? 0 : startMs;
    final end = endMs <= start ? start + 1000 : endMs;
    return <String>[
      '-y',
      // -ss 放在 -i 之前是「快速定位」：直接从最近的关键帧开始解复用。
      // 放到 -i 之后会先解码再丢弃（精确但慢），配合 -c copy 也没有意义。
      '-ss', formatTimestamp(start),
      '-i', input,
      // 用「时长」而不是结束时间：copy 模式下 -t 更可靠
      '-t', formatTimestamp(end - start),
      '-c', 'copy',
      // copy + 定位会产生负时间戳，不归零的话开头几帧会被播放器吞掉
      '-avoid_negative_ts', 'make_zero',
      output,
    ];
  }

  /// 无损重新封装（视频与音频分别来自两个文件的场景）。
  ///
  /// **为什么优先用 FFmpeg 而不是系统 MediaMuxer**：
  /// B 站视频普遍带 B 帧，而 B 帧在解码顺序里的 PTS 本来就是回退的
  /// （例如 I(0) P(3) B(1) B(2)）。MP4 要表达这种回退必须写 `ctts` 表，
  /// 而 MediaMuxer 对非单调时间戳的处理在**各 Android 版本 / 各 OEM 的实现上并不一致**，
  /// 最坏的情况是直接把回退的样本丢掉——表现就是「画面一顿一顿的」，
  /// 但文件大小、轨道数、时长全都正常，所以极难从产物上判定。
  ///
  /// FFmpeg 的 `-c copy` 会正确生成 `ctts`，这是它作为重封装工具的标准用法，
  /// 不依赖设备实现。因此合并优先走这条路，MediaMuxer 只作兜底（精简包）。
  static List<String> remux({
    required String video,
    String? audio,
    required String output,
    bool fastStart = true,
  }) {
    final args = <String>['-y', '-i', video];
    if (audio != null && audio.isNotEmpty) {
      // 显式 -map：只要第一条视频轨和第一条音频轨，
      // 免得输入里的数据轨 / 封面轨被一起搬进产物
      args.addAll(<String>['-i', audio, '-map', '0:v:0', '-map', '1:a:0']);
    }
    args.addAll(<String>['-c', 'copy']);
    if (fastStart) {
      // 把 moov 挪到文件头：播放器不用先读完整段就能起播，
      // 拖动进度条也不会卡一下。代价是封装时多一次尾部数据搬移。
      args.addAll(<String>['-movflags', '+faststart']);
    }
    args.add(output);
    return args;
  }

  /// 调整音量。只动音频滤镜，视频直接复制。
  static List<String> volume({
    required String input,
    required String output,
    required double multiplier,
  }) {
    final value = multiplier <= 0 ? 1.0 : multiplier;
    return <String>[
      '-y',
      '-i',
      input,
      '-filter:a',
      'volume=${value.toStringAsFixed(2)}',
      '-c:v',
      'copy',
      output,
    ];
  }

  /// 调整帧率。视频要重新编码，音频复制。
  static List<String> fps({
    required String input,
    required String output,
    required int fps,
  }) {
    final value = fps <= 0 ? 30 : fps;
    return <String>[
      '-y',
      '-i',
      input,
      '-vf',
      'fps=$value',
      '-c:a',
      'copy',
      output,
    ];
  }

  /// 调整分辨率，保持宽高比。
  ///
  /// 高度用 `-2` 而不是 `-1`：`-1` 可能算出奇数，而 H.264 要求宽高都是偶数，
  /// 奇数会直接编码失败（报错信息还很难懂）。
  static List<String> scale({
    required String input,
    required String output,
    required int width,
  }) {
    final value = width <= 0 ? 1280 : width;
    return <String>[
      '-y',
      '-i',
      input,
      '-vf',
      'scale=$value:-2',
      '-c:a',
      'copy',
      output,
    ];
  }

  /// 提取音轨。默认转成 AAC，也可以直接复制原始编码。
  static List<String> extractAudio({
    required String input,
    required String output,
    bool copy = false,
    int bitrateKbps = 192,
  }) =>
      <String>[
        '-y',
        '-i', input,
        // 不丢视频轨的话，音频容器里会混进一条没人要的视频流
        '-vn',
        if (copy) ...<String>[
          '-c:a',
          'copy'
        ] else ...<String>[
          '-c:a',
          'aac',
          '-b:a',
          '${bitrateKbps}k'
        ],
        output,
      ];

  /// 提取第一条字幕轨为 srt
  static List<String> extractSubtitle({
    required String input,
    required String output,
  }) =>
      <String>[
        '-y',
        '-i',
        input,
        '-map',
        '0:s:0',
        '-c:s',
        'srt',
        output,
      ];

  /// 提取封面（第一帧）
  static List<String> extractCover({
    required String input,
    required String output,
    int atMs = 0,
  }) =>
      <String>[
        '-y',
        '-ss',
        formatTimestamp(atMs),
        '-i',
        input,
        '-frames:v',
        '1',
        '-q:v',
        '2',
        output,
      ];
}
