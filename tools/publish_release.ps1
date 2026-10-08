<#
.SYNOPSIS
    为 DownKyi-Android 创建 GitHub Release 并上传 APK。

.DESCRIPTION
    通过 GitHub REST API 发布版本：
      1. 创建 Release（自动打 tag）
      2. 上传 APK 作为 Release 附件
      3. 自动计算 APK 的 SHA256 与体积，写入 Release 说明

    Token 仅在本机内存中使用，不会写入文件、不会发送给任何第三方。

.PARAMETER Token
    GitHub Personal Access Token（需要 Contents: 读写 权限）。
    不传则依次尝试：环境变量 GITHUB_TOKEN -> 交互式安全输入。

.PARAMETER Tag
    版本号标签，默认 v1.7.0。APK 文件名会按 DownKyi-<Tag>-arm64-v8a.apk 推导。

.PARAMETER Draft
    加此参数则发布为草稿，不公开。

.EXAMPLE
    $env:GITHUB_TOKEN = 'ghp_xxxxxxxxxxxx'
    .\tools\publish_release.ps1

.EXAMPLE
    .\tools\publish_release.ps1 -Tag v1.2.2 -Draft
#>
param(
    [string] $Token,
    [string] $Tag = 'v1.7.0',
    [string] $Repo = 'MokoKing666/DownKyi-Android',
    [string] $Branch = 'main',
    [string] $ApkPath,
    [switch] $Draft
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------------------------------------------------------------- 定位路径
$root = Split-Path -Parent $PSScriptRoot
if (-not $ApkPath) {
    $ApkPath = Join-Path $root "DownKyi-$Tag-arm64-v8a.apk"
}
if (-not (Test-Path $ApkPath -PathType Leaf)) {
    throw "找不到 APK: $ApkPath`n请先执行 .\tools\build_apk.ps1 构建，或用 -ApkPath 指定。"
}

# ---------------------------------------------------------------- 取 Token
if (-not $Token) { $Token = $env:GITHUB_TOKEN }
if (-not $Token) {
    $cred = Get-Credential -Message 'GitHub Token（用户名随意填，密码填 Personal Access Token）'
    $Token = $cred.GetNetworkCredential().Password
}
if (-not $Token) { throw '未提供 Token。' }

$fileName = [System.IO.Path]::GetFileName($ApkPath)
$headers = @{
    'Authorization' = "Bearer $Token"
    'Accept'        = 'application/vnd.github+json'
    'User-Agent'    = 'DownKyi-Release-Script'
}

# ---------------------------------------------------------------- 计算校验值
$sha = (Get-FileHash -Path $ApkPath -Algorithm SHA256).Hash.ToLower()
$sizeMb = '{0:N1} MB' -f ((Get-Item $ApkPath).Length / 1MB)

# ---------------------------------------------------------------- Release 说明
$notes = @'
## 📦 下载

| 文件 | 大小 | 架构 |
|---|---|---|
| `DownKyi-{TAG}-arm64-v8a.apk` | {SIZE} | arm64-v8a |

SHA256：`{SHA256}`

> 仅提供 arm64-v8a 单架构包，覆盖绝大多数现代 Android 设备且体积更小。
> 需要其它架构请自行 `flutter build apk --release`。

## ✨ 本次更新（{TAG}）

### 修复：状态栏图标「改了不变」的真正原因

- 对比两个 APK 的资源表：`ic_stat_downkyi` 与上一版的 `ic_stat_download`
  拿到的是**同一个资源 ID `0x7f070065`**。Android 的
  `NotificationManagerService.IconManager` 按「包名 + 资源 ID」缓存通知图标位图，
  且收到 `ACTION_PACKAGE_REMOVED` 时**会跳过 `EXTRA_REPLACING = true`**，
  即**覆盖安装不会清缓存**——所以改名也没用，系统一直显示缓存里的旧箭头。
- **这条缓存在 system_server 内存里，重启手机即清**；彻底卸载重装同样有效。
- 图标本身也做了修正：把 logo 渲染到 192px 后做腐蚀，
  K 的缝隙从约 0.6px 加宽到约 1.6px，避免 24px 下糊成一个白三角。

### 改进：缓存清理改为「缓存分析」

- 扫描工作目录并按文件类型分组（分段临时文件 / 媒体分片 / 成品 / 封面 / 弹幕字幕 / 其它），
  每组显示文件数量与体积，由用户自己勾选。
- **区分「可清理」与「占用中」**：仍被任务引用的文件（未完成任务的临时分片、
  未导出成品的路径）单独列出并标注原因，不会被删除，避免破坏断点续传或丢文件。

### v1.6.0 起已具备：合并卡顿修复

- `MediaMuxerHelper` 过去为了保证「时间戳单调递增」，把回退的 PTS 强行改写成
  `lastWritten + 1`。但 **B 站视频普遍带 B 帧**，而 B 帧在解码顺序里的 PTS 本来
  就是回退的（例如 `I(0) P(3) B(1) B(2)`），改写后帧的显示时刻被压平、显示顺序错乱，
  表现就是「合并出来的视频卡卡的」。
- 实际上 **MediaMuxer 从 Android 7.1（API 25 / Nougat MR1）起就支持把 B 帧封装进 MP4**，
  所以 API 25+ 现在原样写入真实 PTS；只有 API 24 才退回单调处理。
- 交错顺序改为按「各轨已读到的最大时间戳」比较，避免 B 帧 PTS 回退导致交错抖动；
  单帧缓冲从 1MB 提到 4MB（1MB 装不下 4K 关键帧）。

### 修复：状态栏图标

- 资源名不变时 SystemUI 会**按资源名复用缓存下来的旧图标位图**，
  出现「换了图标但通知栏没变」。现在改名 `ic_stat_downkyi`（五套密度）。
- 注意 v1.4.0 的 Release APK 因构建脚本未做镜像同步，
  实际打进的是旧的 `ic_stat_download.xml`，也需要升级到本版。

### 新增

- **解析 / 下载处可直接选保存位置**：新增「保存位置」选项，
  支持系统相册 / 应用目录 / 自定义目录，自定义目录可就地编辑。
- **可以只下载封面 / 弹幕 / 字幕**：不再被「请至少选择视频或音频」拦住。
- **清理缓存**：工具箱新增入口，显示可释放空间并删除临时分片；
  正在下载 / 已暂停的任务分片会保留，不影响断点续传。

### 改进：附加文件不再「不知道去哪了」

- 过去封面按 MIME 被送进 `Pictures/<album>`，弹幕 / 字幕却在 `Downloads/<album>`。
- 现在视频 → `Movies/<album>`，**封面 / 弹幕 / 字幕 / 单独下载的音轨 → `Download/<album>`**。

### v1.5.0 起已具备：站内搜索

- 解析页右上角新增搜索按钮，输入关键词即可在 App 内搜视频，**不用再切到 B 站复制链接**。
- 结果有两种用法：**点整行**直接解析该视频并进入解析结果页（单下载）；
  **勾选后点「下载选中」**走批量链路（含真实清晰度的选项弹窗）。
- 粘贴内容不是链接时（比如只有标题），点「开始解析」会弹窗询问是否用这段文字去搜索。
- 走 `/x/web-interface/wbi/search/type`（新接口，旧接口已废弃）：
  需要 WBI 签名 + `buvid3` Cookie + `.bilibili.com` 下的 Referer；
  **没有 `page_size` 参数**，每页固定 20 条；`-412` 是 Cookies 校验不足的风控返回。
- 搜索结果的图标与 App logo 保持一致（从 `docs/logo.png` 抽取的单色剪影）。

### v1.4.0 起已具备：订阅

- 订阅持久化（UP 主投稿 / 合集 / 收藏夹 / 番剧整季），增量检查 + 主动通知 + 周期调度。

- **订阅持久化**：新增独立的订阅库（与下载任务库分开，版本号互不牵制）。
  支持四类：UP 主投稿 / UP 主合集 / 收藏夹 / 番剧整季。
  添加入口在解析页「常用入口」最下方，复用现有链接识别，没有另写一套。
- **增量检查**：每次只拉第 1 页与已发现集合做差，不做全量翻页。
  合集接口默认按发布时间**升序**（第 1 页最旧），因此给它加了倒序参数，
  检查时倒序拉才能看到最新内容。
- **主动通知**：发现新内容后发通知，点击直达该订阅的新内容页。
- **周期调度**：WorkManager 周期任务，默认 6 小时，可在设置里调整或关闭；
  重启后由 WorkManager 的 `RescheduleReceiver` 自动恢复。
- **发现即判重**：已发现内容记在独立表里，键是 `bvid + epId`。
  番剧条目没有 `bvid`，只存 bvid 会让所有番剧记录互相覆盖。
- **自动下载默认关闭**：默认只通知。8K 视频单个动辄数 GB，
  默认自动下载会迅速吃满存储；开启后走现有下载管理器。
- **首次检查只播种**：第一次检查把当前内容全部记为「已知」但不通知，
  否则新加订阅会立刻被推送一屏存量内容。

### 设计取舍

- 后台检查跑在 WorkManager 的后台 isolate 里，那是**全新的 Dart 环境**，
  必须自己重新装配依赖（Cookie 会从本地恢复，登录态可用）。
- 通知使用 `flutter_local_notifications` 而非 App 自建通道：
  后台 isolate 的 `FlutterEngine` 由 workmanager 创建，**里面没有 MainActivity**，
  自建通道在后台拿不到 handler，通知会静默丢失。
- 通知渠道独立于下载进度渠道：后者是 `IMPORTANCE_LOW` 的前台服务渠道，
  渠道重要性创建后 App 无法修改，放进去等于静默无提醒。
- 因为通知插件的要求，构建开启了 core library desugaring。

## 🎯 功能概览

- **解析**：链接 / BV 号 / av 号 / ep、ss 号 / 收藏夹 / 合集 / 观看历史 / 稍后再看 / UP 主投稿
- **下载**：内置多线程分片下载器（断点续传 + 前台服务保活），可选 Aria2（JSON-RPC）远程下载
- **合并**：系统 `MediaMuxer` 无损重新封装，不重新编码
- **转换**：FFmpeg 支持 MP4 / MKV 封装、MP3 / M4A 提取、GIF、压缩、H.264 ↔ H.265 互转
- **存储**：默认保存到系统相册（MediaStore），也支持应用目录 / 自定义目录
- **外观**：简洁白 / 少女粉 / 主题黑三套主题，可跟随系统深色模式
- **其它**：弹幕、字幕、封面下载，仅 Wi-Fi 下载，并发数与失败重试可调

## ⚠️ 已知限制

- FFmpeg 使用 full-gpl 变体，APK 体积约 64 MB
- 订阅的周期任务由系统调度，**不保证准时**，因此打开 App 时还会补检查一次
- 追番订阅暂不支持课程（`cheese`）；单集链接（`ep`）不构成订阅，需改用整季（`ss`）
- Aria2 模式为**远程下载**：文件落在 aria2 所在设备，App 不自动合并、也不会进相册
- 极少数老设备不支持把 AV1 / HEVC 封装进 MP4，此时会保留原始 `.m4s`，可在工具箱「重新合并」

## 📄 许可

GPL-3.0，第三方组件清单见仓库内 `THIRD-PARTY-NOTICES.md`。
'@
$notes = $notes -replace '\{TAG\}', $Tag
$notes = $notes -replace '\{SIZE\}', $sizeMb
$notes = $notes -replace '\{SHA256\}', $sha

# ---------------------------------------------------------------- 创建 Release
$body = @{
    tag_name         = $Tag
    target_commitish = $Branch
    name             = "DownKyi $Tag"
    body             = $notes
    draft            = [bool] $Draft
    prerelease       = $false
} | ConvertTo-Json -Depth 5

Write-Host "创建 Release $Tag ..." -ForegroundColor Cyan
$release = $null
try {
    $release = Invoke-RestMethod -Method Post `
        -Uri "https://api.github.com/repos/$Repo/releases" `
        -Headers $headers -ContentType 'application/json; charset=utf-8' `
        -Body ([Text.Encoding]::UTF8.GetBytes($body))
}
catch {
    $status = $null
    if ($_.Exception.Response) { $status = [int] $_.Exception.Response.StatusCode }
    if ($status -eq 422) {
        Write-Host "该 tag 已存在，改为获取已有 Release 并追加附件..." -ForegroundColor Yellow
        $release = Invoke-RestMethod -Method Get `
            -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" -Headers $headers
    }
    else {
        $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        throw "创建 Release 失败（HTTP $status）：$($reader.ReadToEnd())"
    }
}

Write-Host "  Release id: $($release.id)" -ForegroundColor Green

# ---------------------------------------------------------------- 上传 APK
$uploadBase = $release.upload_url -replace '\{.*\}$', ''
$uploadUri = '{0}?name={1}' -f $uploadBase, [System.Uri]::EscapeDataString($fileName)

Write-Host "上传附件 $fileName （$sizeMb）..." -ForegroundColor Cyan
$asset = Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $headers `
    -ContentType 'application/vnd.android.package-archive' -InFile $ApkPath

Write-Host ''
Write-Host '✅ 发布完成' -ForegroundColor Green
Write-Host "   Release 页面 : $($release.html_url)"
Write-Host "   APK 下载地址 : $($asset.browser_download_url)"
Write-Host "   SHA256       : $sha"
if ($Draft) { Write-Host '   （当前为草稿状态，需到网页端点击 Publish release 才会公开）' -ForegroundColor Yellow }
