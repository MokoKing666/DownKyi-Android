import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/formatter.dart';
import '../core/logger.dart';
import '../data/bili_api.dart';
import '../data/download_task.dart';
import '../data/http_client.dart';
import '../data/models.dart';
import '../data/settings_store.dart';
import '../data/task_dao.dart';
import '../native/bridge.dart';
import 'aria2_client.dart';
import 'danmaku_writer.dart';
import 'segment_downloader.dart';

class _Job {
  _Job(this.task, this.token);

  final DownloadTask task;
  final CancelToken token;
  final Map<String, int> streamTotals = <String, int>{};
  final Map<String, int> streamDone = <String, int>{};

  /// Aria2 引擎下每个流的 gid（流名 -> gid），用于暂停 / 删除
  final Map<String, String> aria2Gids = <String, String>{};
  int lastPersistAt = 0;

  void recalc() {
    task.totalBytes = streamTotals.values.fold(0, (sum, value) => sum + value);
    task.downloadedBytes = streamDone.values.fold(0, (sum, value) => sum + value);
  }
}

/// 下载调度中心：队列 / 并发控制 / 分片下载 / 合并 / 附加资源 / 前台服务通知。
///
/// 支持两种下载引擎：
/// - [DownloadEngine.builtin]：内置多线程分片下载器，下载到本机，自动合并并默认存入系统相册；
/// - [DownloadEngine.aria2]：通过 JSON-RPC 把任务交给 aria2 执行，文件落在 aria2 所在设备
///   （常见用法是 NAS / 电脑上常驻 aria2）。这种模式下 App 负责下发任务与显示进度，
///   不参与合并与相册导出。
class DownloadManager extends ChangeNotifier {
  DownloadManager({required this.settings, required this.api});

  final SettingsStore settings;
  final BiliApi api;

  final TaskDao _dao = TaskDao.instance;
  final List<DownloadTask> tasks = <DownloadTask>[];
  final Map<int, _Job> _jobs = <int, _Job>{};
  final Map<int, int> _lastBytes = <int, int>{};

  Timer? _ticker;
  bool _serviceRunning = false;
  String? _lastCompletedTitle;
  int _completedCount = 0;

  Aria2Client? _aria2Client;
  String _aria2Key = '';

  String? get lastCompletedTitle => _lastCompletedTitle;
  int get completedCount => _completedCount;

  List<DownloadTask> get activeTasks =>
      tasks.where((task) => task.isActive || task.status == TaskStatus.queued).toList();

  List<DownloadTask> get finishedTasks =>
      tasks.where((task) => task.status == TaskStatus.completed).toList();

  // ------------------------------------------------------------------
  // 引擎
  // ------------------------------------------------------------------

  Aria2Client get aria2 {
    final key = '${settings.aria2RpcUrl}|${settings.aria2Secret}';
    if (_aria2Client == null || _aria2Key != key) {
      _aria2Client?.close();
      _aria2Client = Aria2Client(rpcUrl: settings.aria2RpcUrl, secret: settings.aria2Secret);
      _aria2Key = key;
    }
    return _aria2Client!;
  }

  bool get usesAria2 => settings.downloadEngine == DownloadEngine.aria2;

  /// aria2 是否跑在本机。只有本机运行的 aria2 才可能把文件交回 App 做后续处理。
  bool get aria2RunsLocally {
    final host = Uri.tryParse(settings.aria2RpcUrl.trim())?.host.toLowerCase() ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '10.0.2.2';
  }

  Future<void> init() async {
    final loaded = await _dao.loadAll();
    for (final task in loaded) {
      // 上次退出时还在跑的任务，恢复为暂停
      if (task.status == TaskStatus.running || task.status == TaskStatus.merging) {
        task.status = TaskStatus.paused;
        task.speed = 0;
        await _dao.update(task);
      }
      tasks.add(task);
    }
    _completedCount = tasks.where((task) => task.status == TaskStatus.completed).length;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // 队列操作
  // ------------------------------------------------------------------

  Future<DownloadTask?> enqueue({
    required MediaItem item,
    required int quality,
    required String qualityName,
    int? audioId,
    String codec = 'avc',
    int? flags,
    DanmakuFormat? danmakuFormat,
  }) async {
    final effectiveFlags = flags ??
        ((settings.downloadVideo ? DownloadFlags.video : 0) |
            (settings.downloadAudio ? DownloadFlags.audio : 0) |
            (settings.downloadCover ? DownloadFlags.cover : 0) |
            (settings.downloadDanmaku ? DownloadFlags.danmaku : 0) |
            (settings.downloadSubtitle ? DownloadFlags.subtitle : 0));

    final key = '${item.bvid.isEmpty ? 'ep${item.epId}' : item.bvid}_${item.cid}_${quality}_$effectiveFlags';
    if (tasks.any((task) => task.key == key && task.status != TaskStatus.failed)) {
      AppLog.d('Task', '任务已存在，跳过：$key');
      return null;
    }

    final task = DownloadTask(
      key: key,
      title: item.title,
      subTitle: item.ownerName,
      cover: item.cover,
      owner: item.ownerName,
      bvid: item.bvid,
      cid: item.cid,
      epId: item.epId,
      btype: item.btype,
      durationMs: item.durationMs,
      quality: quality,
      qualityName: qualityName,
      audioId: audioId,
      codec: codec,
      flags: effectiveFlags,
      danmakuFormat: danmakuFormat ?? settings.danmakuFormat,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    task.fileName = buildFileName(task);
    await _dao.insert(task);
    tasks.add(task);
    notifyListeners();
    _pump();
    return task;
  }

  String buildFileName(DownloadTask task) {
    var name = settings.fileNameTemplate
        .replaceAll('{title}', task.title)
        .replaceAll('{quality}', task.qualityName.isEmpty ? '${task.quality}' : task.qualityName)
        .replaceAll('{owner}', task.owner);
    if (name.trim().isEmpty) name = task.title;
    return sanitizeFileName(name);
  }

  void _pump() {
    final maxConcurrent = settings.concurrentTasks.clamp(1, 5);
    var running = _jobs.length;
    for (final task in tasks) {
      if (running >= maxConcurrent) break;
      if (task.status != TaskStatus.queued) continue;
      if (_jobs.containsKey(task.id)) continue;
      final job = _Job(task, CancelToken());
      _jobs[task.id] = job;
      running++;
      unawaited(_execute(job));
    }
    _syncTicker();
  }

  void pause(int id) {
    final job = _jobs[id];
    if (job == null) return;
    job.token.cancel();
    // Aria2 模式下同时通知远端暂停
    for (final gid in job.aria2Gids.values) {
      unawaited(aria2.pause(gid));
    }
  }

  void resume(int id) {
    final task = _firstWhereOrNull(id);
    if (task == null) return;
    if (task.status == TaskStatus.completed) return;
    task.status = TaskStatus.queued;
    task.error = null;
    unawaited(_dao.update(task));
    notifyListeners();
    _pump();
  }

  void pauseAll() {
    for (final job in _jobs.values.toList()) {
      pause(job.task.id);
    }
  }

  void resumeAll() {
    for (final task in tasks) {
      if (task.status == TaskStatus.paused || task.status == TaskStatus.failed) {
        task.status = TaskStatus.queued;
        task.error = null;
        unawaited(_dao.update(task));
      }
    }
    notifyListeners();
    _pump();
  }

  Future<void> remove(int id, {bool deleteFiles = true}) async {
    final task = _firstWhereOrNull(id);
    if (task == null) return;
    final job = _jobs[id];
    job?.token.cancel();
    if (job != null) {
      for (final gid in job.aria2Gids.values) {
        unawaited(aria2.remove(gid));
      }
    }
    _jobs.remove(id);
    if (deleteFiles) {
      await _deleteTaskFiles(task);
    }
    tasks.removeWhere((item) => item.id == id);
    await _dao.delete(id);
    notifyListeners();
    _pump();
  }

  Future<void> clearFinished({bool deleteFiles = false}) async {
    final finished = tasks.where((task) => task.status == TaskStatus.completed).toList();
    for (final task in finished) {
      if (deleteFiles) await _deleteTaskFiles(task);
      tasks.removeWhere((item) => item.id == task.id);
      await _dao.delete(task.id);
    }
    notifyListeners();
  }

  Future<void> retry(int id) {
    final task = _firstWhereOrNull(id);
    if (task == null) return Future<void>.value();
    task.status = TaskStatus.queued;
    task.error = null;
    task.downloadedBytes = 0;
    task.totalBytes = 0;
    task.videoSegments = '';
    task.audioSegments = '';
    task.aria2Gid = null;
    task.exported = false;
    task.exportedPath = null;
    return _dao.update(task).then((_) {
      notifyListeners();
      _pump();
    });
  }

  DownloadTask? _firstWhereOrNull(int id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 执行
  // ------------------------------------------------------------------

  /// 补齐 cid。
  ///
  /// 收藏夹（cid 在 `ugc.first_cid`）、UP 主投稿与合集接口都拿不到顶层 cid，
  /// 直接用 cid=0 去请求 playurl 会返回 -400，表现为「一进去下载就请求失败」。
  /// 这里统一补一次详情查询，成功后会回写任务与数据库。
  Future<void> _ensureCid(DownloadTask task) async {
    if (task.cid > 0) return;
    if (task.bvid.isEmpty) {
      throw ApiException(-1, '缺少 cid 与 bvid，无法获取播放地址');
    }
    AppLog.d('Task', '任务缺少 cid，补查详情：${task.bvid}');
    final detail = await api.videoDetail(task.bvid);
    if (detail.cid <= 0) {
      throw ApiException(-1, '无法获取该视频的 cid，可能已下架或需要登录');
    }
    task.cid = detail.cid;
    await _dao.update(task);
  }

  Future<void> _execute(_Job job) async {
    final task = job.task;
    final token = job.token;
    try {
      if (settings.wifiOnly && !await NativeBridge.isWifi()) {
        task.status = TaskStatus.paused;
        task.error = '已开启「仅 Wi-Fi 下载」，当前不是 Wi-Fi 网络';
        await _dao.update(task);
        notifyListeners();
        return;
      }

      final dir = await ensureDownloadDir();
      final tmpDir = Directory('$dir/.tmp');
      await tmpDir.create(recursive: true);

      task.status = TaskStatus.running;
      task.error = null;
      task.speed = 0;
      task.downloadedBytes = 0;
      task.totalBytes = 0;
      job.streamDone.clear();
      job.streamTotals.clear();
      _touch();
      await _startServiceIfNeeded();

      // 收藏夹 / UP 主投稿 / 合集等来源没有 cid，补齐后才能取到播放地址
      await _ensureCid(task);
      if (token.isCancelled) return;

      // 只勾了封面 / 弹幕 / 字幕：既不需要播放地址，也不涉及合并，
      // 直接去抓附加资源，省掉一次 playurl 请求
      if (!task.wantVideo && !task.wantAudio) {
        task.videoPath = null;
        task.audioPath = null;
        await _finishTask(task, dir);
        return;
      }

      if (usesAria2) {
        await _executeAria2(task, job);
        return;
      }

      final videoTmp = '${tmpDir.path}/${task.key}_v.m4s';
      final audioTmp = '${tmpDir.path}/${task.key}_a.m4s';

      final dash = await api.playUrl(
        btype: task.btype,
        cid: task.cid,
        bvid: task.bvid,
        epId: task.epId,
        quality: task.quality,
      );
      if (token.isCancelled) return;

      final video = dash.pickVideo(task.quality, task.codec);
      final audio = dash.pickAudio(task.audioId);

      if ((video == null && audio == null) || (task.wantVideo && video == null)) {
        // 回退到 durl 直链（部分老视频没有 DASH）
        await _downloadDirect(task, job, dir, tmpDir.path);
        return;
      }

      final wantVideo = task.wantVideo && video != null;
      final wantAudio = task.wantAudio && audio != null;

      final futures = <Future<void>>[];
      if (wantVideo) {
        futures.add(_downloadStream(
          job: job,
          streamKey: 'video',
          url: video.url,
          path: videoTmp,
          resumeState: task.videoSegments ?? '',
          onState: (state) => task.videoSegments = state,
        ));
      }
      if (wantAudio) {
        futures.add(_downloadStream(
          job: job,
          streamKey: 'audio',
          url: audio.url,
          path: audioTmp,
          resumeState: task.audioSegments ?? '',
          onState: (state) => task.audioSegments = state,
        ));
      }
      await Future.wait(futures);
      if (token.isCancelled) return;

      task.videoPath = wantVideo ? videoTmp : null;
      task.audioPath = wantAudio ? audioTmp : null;

      await _finishTask(task, dir);
    } catch (error) {
      if (token.isCancelled) {
        task.status = TaskStatus.paused;
        task.speed = 0;
        await _dao.update(task);
        notifyListeners();
        return;
      }
      AppLog.e('Task', '任务失败：${task.title}', error);
      task.status = TaskStatus.failed;
      task.speed = 0;
      task.error = error is ApiException ? error.message : error.toString();
      await _dao.update(task);
      notifyListeners();
    } finally {
      _jobs.remove(task.id);
      await _stopServiceIfIdle();
      _pump();
    }
  }

  /// 附加资源 + 合并 + 收尾
  Future<void> _finishTask(DownloadTask task, String dir) async {
    await _downloadExtras(task, dir);

    if (task.videoPath == null && task.audioPath == null) {
      // 只勾了封面 / 弹幕 / 字幕：没有媒体流可合并，直接收尾
      task.merged = false;
      task.outputPath = null;
      AppLog.d('Task', '没有媒体流，跳过合并：${task.title}');
    } else if (!settings.mergeAv) {
      // 设置里关掉了「自动合并音视频」：只保留分片，之后可在工具箱手动合并
      task.merged = false;
      task.outputPath = task.videoPath ?? task.audioPath;
      AppLog.d('Task', '已按设置跳过自动合并：${task.title}');
    } else {
      task.status = TaskStatus.merging;
      _touch();
      await _merge(task, dir);
    }

    task.status = TaskStatus.completed;
    task.speed = 0;
    task.finishedAt = DateTime.now().millisecondsSinceEpoch;
    if (task.totalBytes <= 0) task.totalBytes = task.downloadedBytes;
    task.downloadedBytes = task.totalBytes;
    _completedCount++;
    _lastCompletedTitle = task.title;
    await _dao.update(task);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Aria2 引擎
  // ------------------------------------------------------------------

  /// 把任务交给 aria2。
  ///
  /// aria2 的落盘位置永远是「aria2 所在设备」，因此这里不做本地合并：
  /// - 优先使用 durl 直链（单个完整 mp4）；
  /// - 没有直链时下发 DASH 的视频流与音频流两个文件。
  Future<void> _executeAria2(DownloadTask task, _Job job) async {
    final client = aria2;

    // 先握手，地址/密钥错误能立刻报出来
    final version = await client.getVersion();
    AppLog.d('Aria2', '已连接 aria2 $version，本机=$aria2RunsLocally');

    final jobs = <String, String>{}; // 流名 -> url

    final direct = await api.plainUrl(
      btype: task.btype,
      cid: task.cid,
      bvid: task.bvid,
      epId: task.epId,
      quality: task.quality,
    );
    if (direct != null) {
      jobs['direct'] = direct;
    } else {
      final dash = await api.playUrl(
        btype: task.btype,
        cid: task.cid,
        bvid: task.bvid,
        epId: task.epId,
        quality: task.quality,
      );
      final video = dash.pickVideo(task.quality, task.codec);
      final audio = dash.pickAudio(task.audioId);
      if (task.wantVideo && video != null) jobs['video'] = video.url;
      if (task.wantAudio && audio != null) jobs['audio'] = audio.url;
      if (jobs.isEmpty) {
        throw ApiException(-1, '未获取到可用下载地址，可能是大会员 / 付费内容或已下架');
      }
    }

    final gids = <String, String>{};
    for (final entry in jobs.entries) {
      final gid = await client.addUri(
        url: entry.value,
        options: Aria2Client.optionsFor(
          dir: settings.aria2Dir,
          out: _aria2FileName(task, entry.key),
          referer: BiliConst.webBase,
          userAgent: BiliConst.userAgent,
          cookie: AppHttp.instance.cookieHeader,
          split: settings.aria2Split,
        ),
      );
      gids[entry.key] = gid;
      job.aria2Gids[entry.key] = gid;
      task.aria2Gid = gid;
      AppLog.d('Aria2', '已下发 ${entry.key} -> $gid');
    }
    await _dao.update(task);
    _touch();

    await _pollAria2(job, gids);
    if (job.token.isCancelled) return;

    // 文件在 aria2 所在设备，App 侧无法合并 / 导出相册
    task.status = TaskStatus.completed;
    task.speed = 0;
    task.merged = false;
    task.outputPath = null;
    task.exported = false;
    task.exportedPath = null;
    task.finishedAt = DateTime.now().millisecondsSinceEpoch;
    if (task.totalBytes <= 0) task.totalBytes = task.downloadedBytes;
    task.downloadedBytes = task.totalBytes;
    task.error = settings.aria2Dir.isEmpty
        ? '已由 Aria2 下载完成（落盘于 aria2 所在设备）'
        : '已由 Aria2 下载完成，位置：${settings.aria2Dir}';
    _completedCount++;
    _lastCompletedTitle = task.title;
    await _dao.update(task);
    notifyListeners();
  }

  /// aria2 落盘文件名：音轨用 m4a，视频流 / 直链用 mp4
  String _aria2FileName(DownloadTask task, String streamKey) =>
      streamKey == 'audio' ? '${task.fileName}.m4a' : '${task.fileName}.mp4';

  /// 轮询 aria2 任务状态，直到全部结束或被取消
  Future<void> _pollAria2(_Job job, Map<String, String> gids) async {
    final client = aria2;
    final pending = Map<String, String>.from(gids);
    while (pending.isNotEmpty && !job.token.isCancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      for (final entry in pending.entries.toList()) {
        final Aria2Status status;
        try {
          status = await client.tellStatus(entry.value);
        } catch (error) {
          AppLog.e('Aria2', '查询状态失败：${entry.key}', error);
          continue;
        }
        job.streamTotals[entry.key] = status.totalLength;
        job.streamDone[entry.key] = status.completedLength;
        job.recalc();
        if (status.isComplete) {
          pending.remove(entry.key);
        } else if (status.isError) {
          throw ApiException(-1, 'Aria2 下载失败（${entry.key}）：${status.errorMessage}');
        }
      }
      _persistProgress(job);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // 内置下载器
  // ------------------------------------------------------------------

  Future<void> _downloadStream({
    required _Job job,
    required String streamKey,
    required String url,
    required String path,
    required String resumeState,
    required void Function(String state) onState,
  }) async {
    final downloader = SegmentDownloader(
      url: url,
      filePath: path,
      segmentCount: settings.segmentConcurrency.clamp(1, 16),
      concurrency: settings.segmentConcurrency.clamp(1, 16),
      resumeState: resumeState,
    );
    await downloader.download(
      onTotal: (total) {
        job.streamTotals[streamKey] = total;
        job.recalc();
      },
      onProgress: (downloaded) {
        job.streamDone[streamKey] = downloaded;
        job.recalc();
        _persistProgress(job);
      },
      onState: onState,
      token: job.token,
    );
    _persistProgress(job, force: true);
  }

  /// 没有 DASH 时的直链下载
  Future<void> _downloadDirect(
    DownloadTask task,
    _Job job,
    String dir,
    String tmpDir,
  ) async {
    final url = await api.plainUrl(
      btype: task.btype,
      cid: task.cid,
      bvid: task.bvid,
      epId: task.epId,
      quality: task.quality,
    );
    if (url == null) {
      throw ApiException(-1, '未获取到下载地址，可能是大会员 / 付费内容或已下架');
    }
    final tmp = '$tmpDir/${task.key}_direct.mp4';
    job.streamTotals['direct'] = 0;
    final downloader = SegmentDownloader(
      url: url,
      filePath: tmp,
      segmentCount: settings.segmentConcurrency.clamp(1, 16),
      concurrency: settings.segmentConcurrency.clamp(1, 16),
    );
    await downloader.download(
      onTotal: (total) {
        job.streamTotals['direct'] = total;
        job.recalc();
      },
      onProgress: (downloaded) {
        job.streamDone['direct'] = downloaded;
        job.recalc();
        _persistProgress(job);
      },
      onState: (state) => task.videoSegments = state,
      token: job.token,
    );
    if (job.token.isCancelled) return;
    task.videoPath = tmp;
    task.audioPath = null;
    await _finishTask(task, dir);
  }

  Future<void> _downloadExtras(DownloadTask task, String dir) async {
    final base = '$dir/${task.fileName}';
    final toGallery = settings.saveToGallery;

    if (task.wantCover && task.cover.isNotEmpty) {
      try {
        final bytes = await api.http.getBytes(Uri.parse(task.cover), referer: BiliConst.webBase);
        final local = '$base.jpg';
        await File(local).writeAsBytes(bytes, flush: true);
        await _placeFile(localPath: local, fileName: '${task.fileName}.jpg', toGallery: toGallery);
      } catch (error) {
        AppLog.e('Task', '封面下载失败', error);
      }
    }

    if (task.wantDanmaku) {
      try {
        final items = await api.danmaku(cid: task.cid, durationMs: task.durationMs);
        final content = switch (task.danmakuFormat) {
          DanmakuFormat.xml => DanmakuWriter.toXml(items),
          DanmakuFormat.ass => DanmakuWriter.toAss(items, title: task.title),
          DanmakuFormat.txt => DanmakuWriter.toText(items),
          DanmakuFormat.none => '',
        };
        if (content.isNotEmpty) {
          final local = '$base.${task.danmakuFormat.ext}';
          await File(local).writeAsString(content, flush: true);
          await _placeFile(
            localPath: local,
            fileName: '${task.fileName}.${task.danmakuFormat.ext}',
            toGallery: toGallery,
          );
        }
      } catch (error) {
        AppLog.e('Task', '弹幕下载失败', error);
      }
    }

    if (task.wantSubtitle) {
      try {
        final subtitles = await api.subtitles(cid: task.cid, bvid: task.bvid, epId: task.epId);
        if (subtitles.isNotEmpty) {
          final chosen = subtitles.firstWhere(
            (item) => item.lan.toLowerCase().contains('zh'),
            orElse: () => subtitles.first,
          );
          final srt = await api.subtitleToSrt(chosen.url);
          if (srt.isNotEmpty) {
            final local = '$base.srt';
            await File(local).writeAsString(srt, flush: true);
            await _placeFile(localPath: local, fileName: '${task.fileName}.srt', toGallery: toGallery);
          }
        }
      } catch (error) {
        AppLog.e('Task', '字幕下载失败', error);
      }
    }
  }

  Future<void> _merge(DownloadTask task, String dir) async {
    final videoPath = task.videoPath;
    final audioPath = task.audioPath;
    if (videoPath == null && audioPath == null) {
      throw ApiException(-1, '没有下载到任何媒体流');
    }
    final extension = videoPath != null ? 'mp4' : 'm4a';
    final output = '$dir/${task.fileName}.$extension';

    // durl 直链下载到的本身就是完整 mp4（音视频在同一个文件里），改名即可。
    // 之前这里还会再封装一遍，而封装逻辑只取第一条视频轨，音频会被静默丢掉。
    final isCompleteMp4 = audioPath == null && videoPath != null && videoPath.endsWith('.mp4');

    var ok = true;
    if (isCompleteMp4) {
      try {
        await File(videoPath).rename(output);
      } catch (error) {
        AppLog.e('Task', '移动直链文件失败，改为重新封装', error);
        ok = await NativeBridge.mux(video: videoPath, audio: null, output: output);
      }
    } else {
      // 音频要无条件传进去：只有音频没有视频时也必须输出 m4a，
      // 不能因为「缺少视频轨」就把音频丢掉导致封装必然失败
      ok = await NativeBridge.mux(video: videoPath, audio: audioPath, output: output);
    }

    if (ok) {
      await _deleteFile(videoPath);
      await _deleteFile(audioPath);

      // 默认落盘位置是系统相册：导出成功就删掉本机私有副本，避免文件重复
      final placed = await _placeFile(
        localPath: output,
        fileName: '${task.fileName}.$extension',
        toGallery: settings.saveToGallery,
        // 只有视频进 Movies；单独下的音轨进 Download，免得混进相册
        category: videoPath != null ? 'video' : 'file',
      );
      task.outputPath = placed;
      task.exported = placed != null && placed != output;
      task.exportedPath = task.exported ? placed : null;
      task.merged = true;
      task.error = null;
      return;
    }

    // 合并失败：保留原始分片，用户可在工具箱里重试
    task.merged = false;
    task.outputPath = videoPath ?? audioPath;
    task.error = '封装失败，已保留原始文件，可在「工具」里重新合并或改用 FFmpeg 转换';
    AppLog.e('Task', '封装失败：${task.title}');
  }

  /// 按保存位置落盘。
  ///
  /// - 系统相册：通过 MediaStore 导出，目标目录由 [category] 决定
  ///   （`video` → Movies，`image` → Pictures，其余 → Download）
  /// - 应用目录 / 自定义目录：原地保留
  ///
  /// 导出失败时回退为本地路径，绝不丢文件。
  Future<String?> _placeFile({
    required String localPath,
    required String fileName,
    required bool toGallery,
    String category = 'file',
  }) async {
    if (!toGallery) return localPath;
    final target = await NativeBridge.exportToPublic(
      path: localPath,
      name: fileName,
      mime: mimeOf(localPath),
      album: AppInfo.englishName,
      category: category,
    );
    if (target == null) {
      AppLog.e('Task', '导出到系统相册失败，保留本地副本：$fileName');
      return localPath;
    }
    await _deleteFile(localPath);
    return target;
  }

  // ------------------------------------------------------------------
  // 目录与文件
  // ------------------------------------------------------------------

  // ------------------------------------------------------------------
  // 缓存
  // ------------------------------------------------------------------

  /// 缓存占用（工作目录，含 .tmp 临时分片目录）
  Future<int> cacheBytes() async {
    try {
      final dir = await ensureDownloadDir();
      return await _dirSize(Directory(dir));
    } catch (error) {
      AppLog.e('Task', '统计缓存失败', error);
      return 0;
    }
  }

  /// 分析工作目录，按文件类型分组，用于「缓存分析」界面。
  ///
  /// 每个分组区分两部分：
  /// - **可清理**：没有任何任务引用的文件；
  /// - **占用中**：仍被任务引用（未完成任务的临时分片、未导出成品的路径），
  ///   界面只展示数量与体积，**不会删除**，避免误删用户文件或破坏断点续传。
  Future<List<CacheGroup>> analyzeCache() async {
    final groups = <String, CacheGroupBuilder>{};
    for (final meta in cacheCategories) {
      groups[meta.key] = CacheGroupBuilder(meta);
    }

    try {
      final dir = await ensureDownloadDir();
      final root = Directory(dir);
      if (!await root.exists()) return const <CacheGroup>[];

      // 任务正在引用的路径
      final usedPaths = <String>{};
      // 未完成任务的分片前缀（含 .partN）
      final activePrefixes = <String>[];
      for (final task in tasks) {
        for (final path in <String?>[
          task.videoPath,
          task.audioPath,
          task.outputPath,
          task.exportedPath,
        ]) {
          if (path != null && path.isNotEmpty && !path.startsWith('content://')) {
            usedPaths.add(path);
          }
        }
        if (task.status != TaskStatus.completed && task.status != TaskStatus.failed) {
          activePrefixes.add('${task.key}_v.m4s');
          activePrefixes.add('${task.key}_a.m4s');
        }
      }

      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final builder = groups[_cacheCategoryOf(name)] ?? groups['other']!;
        final kept = usedPaths.contains(entity.path) || activePrefixes.any(name.startsWith);
        int size = 0;
        try {
          size = await entity.length();
        } catch (_) {
          // 忽略
        }
        if (kept) {
          builder.keptCount++;
          builder.keptBytes += size;
        } else {
          builder.paths.add(entity.path);
          builder.bytes += size;
        }
      }
    } catch (error) {
      AppLog.e('Task', '缓存分析失败', error);
    }

    return groups.values
        .where((builder) => !builder.isEmpty)
        .map((builder) => builder.build())
        .toList(growable: false);
  }

  /// 清理指定分组里「可清理」的文件，返回释放的字节数
  Future<int> clearCacheGroups(List<String> keys) async {
    final selected = keys.toSet();
    var freed = 0;
    try {
      final groups = await analyzeCache();
      for (final group in groups) {
        if (!selected.contains(group.key)) continue;
        for (final path in group.paths) {
          try {
            final file = File(path);
            if (await file.exists()) {
              freed += await file.length();
              await file.delete();
            }
          } catch (_) {
            // 单个文件失败不影响整体
          }
        }
      }
      AppLog.d('Task', '清理缓存释放 ${(freed / 1024 / 1024).toStringAsFixed(1)} MB');
    } catch (error) {
      AppLog.e('Task', '清理缓存失败', error);
    }
    return freed;
  }

  /// 按文件名判断所属的缓存分组
  static String _cacheCategoryOf(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('.part')) return 'part';
    final extension = lower.contains('.') ? lower.split('.').last : '';
    return switch (extension) {
      'm4s' => 'm4s',
      'mp4' || 'mkv' || 'm4a' || 'mp3' => 'media',
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => 'image',
      'ass' || 'xml' || 'srt' || 'txt' => 'text',
      _ => 'other',
    };
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // 忽略单个文件的读取失败
        }
      }
    }
    return total;
  }

  /// 本机工作目录（下载过程中的临时文件、未选择相册时的落盘位置）
  Future<String> ensureDownloadDir() async {
    var dir = settings.usesCustomDir ? settings.downloadDir : '';
    if (dir.isEmpty) {
      dir = await NativeBridge.externalFilesDir('DownKyi') ?? '';
    }
    if (dir.isEmpty) {
      dir = '${Directory.systemTemp.path}/DownKyi';
    }
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return dir;
  }

  /// 设置页展示用：当前文件会保存到哪里
  Future<String> describeSaveLocation() async {
    switch (settings.saveLocation) {
      case SaveLocation.gallery:
        return '系统相册 · Movies/${AppInfo.englishName}';
      case SaveLocation.appDir:
        return await ensureDownloadDir();
      case SaveLocation.custom:
        return settings.downloadDir.isEmpty ? '未设置（将回退到应用目录）' : settings.downloadDir;
    }
  }

  Future<void> _deleteTaskFiles(DownloadTask task) async {
    for (final path in <String?>[task.outputPath, task.exportedPath]) {
      if (path != null && path.isNotEmpty) {
        if (path.startsWith('content://')) {
          await NativeBridge.deletePath(path);
        } else {
          await _deleteFile(path);
        }
      }
    }
    for (final path in <String?>[task.videoPath, task.audioPath]) {
      if (path != null && path.isNotEmpty) {
        await _deleteFile(path);
        await SegmentDownloader.cleanParts(path);
      }
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    if (path.startsWith('content://')) {
      await NativeBridge.deletePath(path);
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略
    }
  }

  Future<bool> openFile(DownloadTask task) async {
    final path = task.outputPath ?? task.exportedPath;
    if (path == null || path.isEmpty) return false;
    return NativeBridge.openFile(path, mime: mimeOf(path));
  }

  /// 手动导出到系统相册；已经导出过的直接返回原位置
  Future<String?> exportFile(DownloadTask task) async {
    final existing = task.exportedPath;
    if (task.exported && existing != null && existing.isNotEmpty) {
      return existing;
    }
    final path = task.outputPath;
    if (path == null || path.isEmpty) return null;
    final extension = path.split('.').last;
    final target = await NativeBridge.exportToPublic(
      path: path,
      name: '${task.fileName}.$extension',
      mime: mimeOf(path),
      album: AppInfo.englishName,
      category: exportCategoryOf(path),
    );
    if (target != null) {
      task.exported = true;
      task.exportedPath = target;
      await _dao.update(task);
      notifyListeners();
    }
    return target;
  }

  static String mimeOf(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'mp4' || 'm4s' => 'video/mp4',
      'mkv' => 'video/x-matroska',
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'ass' || 'srt' || 'xml' || 'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  /// 导出到公共目录时的目标文件夹类别。
  ///
  /// 只有视频进 `Movies`，图片进 `Pictures`；
  /// **封面 / 弹幕 / 字幕 / 单独下载的音轨统一进 `Download`**——
  /// 过去封面按 MIME 被送进 `Pictures/`，弹幕字幕却在 `Downloads/`，
  /// 用户根本不知道文件去哪了。
  static String exportCategoryOf(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'mp4' || 'mkv' => 'video',
      'jpg' || 'jpeg' || 'png' || 'gif' => 'image',
      _ => 'file',
    };
  }

  // ------------------------------------------------------------------
  // 进度、通知与定时器
  // ------------------------------------------------------------------

  void _persistProgress(_Job job, {bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - job.lastPersistAt < 2000) return;
    job.lastPersistAt = now;
    unawaited(_dao.update(job.task));
  }

  void _touch() => notifyListeners();

  /// 供工具箱等外部逻辑在改写任务字段后刷新界面
  void refresh() => notifyListeners();

  void _syncTicker() {
    if (_jobs.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      var changed = false;
      for (final job in _jobs.values) {
        final task = job.task;
        final previous = _lastBytes[task.id] ?? 0;
        final delta = task.downloadedBytes - previous;
        task.speed = delta > 0 ? delta * 2 : 0;
        _lastBytes[task.id] = task.downloadedBytes;
        changed = true;
      }
      if (changed) {
        notifyListeners();
        unawaited(_syncNotification());
      }
    });
  }

  Future<void> _startServiceIfNeeded() async {
    if (_serviceRunning) return;
    _serviceRunning = true;
    await NativeBridge.startService(title: AppInfo.name, text: '准备下载…', progress: -1);
  }

  Future<void> _stopServiceIfIdle() async {
    if (_jobs.isNotEmpty) return;
    if (!_serviceRunning) return;
    _serviceRunning = false;
    await NativeBridge.stopService();
  }

  Future<void> _syncNotification() async {
    if (!_serviceRunning) return;
    final active = tasks.where((task) => task.isActive).toList();
    if (active.isEmpty) return;
    final total = active.fold<int>(0, (sum, task) => sum + task.totalBytes);
    final done = active.fold<int>(0, (sum, task) => sum + task.downloadedBytes);
    final progress = total > 0 ? ((done / total) * 100).round().clamp(0, 100) : -1;
    final text = active.length == 1
        ? '${formatBytes(done)} / ${formatBytes(total)} · ${formatSpeed(active.first.speed)}'
        : '共 ${active.length} 个任务 · ${formatBytes(done)} / ${formatBytes(total)}';
    await NativeBridge.updateService(title: AppInfo.name, text: text, progress: progress);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _aria2Client?.close();
    _aria2Client = null;
    super.dispose();
  }
}

/// 缓存分析的分组定义（数组顺序即界面展示顺序）
const List<({String key, String label, String description})> cacheCategories =
    <({String key, String label, String description})>[
  (key: 'part', label: '分段临时文件', description: '.partN —— 多线程分片下载的中间产物'),
  (key: 'm4s', label: '媒体分片', description: 'video / audio 的 .m4s，尚未合并'),
  (key: 'media', label: '视频 / 音频成品', description: '已合并的 mp4 / mkv / m4a / mp3'),
  (key: 'image', label: '封面图片', description: 'jpg / png 等图片'),
  (key: 'text', label: '弹幕 / 字幕', description: 'ass / xml / srt / txt'),
  (key: 'other', label: '其它文件', description: '不属于以上分类'),
];

/// 「缓存分析」里的一个分组。
///
/// 区分「可清理」与「占用中」：占用中的文件仍被任务引用
/// （未完成任务的临时分片、未导出成品的路径），界面只展示不删除。
class CacheGroup {
  const CacheGroup({
    required this.key,
    required this.label,
    required this.description,
    required this.bytes,
    required this.paths,
    required this.keptCount,
    required this.keptBytes,
  });

  final String key;
  final String label;
  final String description;

  /// 可清理部分
  final int bytes;
  final List<String> paths;

  /// 仍被任务占用、不会被删除的部分
  final int keptCount;
  final int keptBytes;

  int get fileCount => paths.length;

  bool get hasKept => keptCount > 0;

  int get totalBytes => bytes + keptBytes;

  int get totalCount => fileCount + keptCount;
}

/// [CacheGroup] 的可变累加器
class CacheGroupBuilder {
  CacheGroupBuilder(this.meta);

  final ({String key, String label, String description}) meta;

  final List<String> paths = <String>[];
  int bytes = 0;
  int keptCount = 0;
  int keptBytes = 0;

  bool get isEmpty => paths.isEmpty && keptCount == 0;

  CacheGroup build() => CacheGroup(
        key: meta.key,
        label: meta.label,
        description: meta.description,
        bytes: bytes,
        paths: List<String>.unmodifiable(paths),
        keptCount: keptCount,
        keptBytes: keptBytes,
      );
}
