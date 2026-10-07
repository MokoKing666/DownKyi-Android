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
    版本号标签，默认 v1.3.1。APK 文件名会按 DownKyi-<Tag>-arm64-v8a.apk 推导。

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
    [string] $Tag = 'v1.3.1',
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

### 修复

- **批量下载的清晰度选项是「假」的**：v1.3.0 为了让批量入口也能选清晰度，
  直接给了一张通用档位表，结果**视频没有 8K 也会列出 8K**；
  而且这张表和「解析结果页」是两套实现，容易各自漂移。
  现在改为**下载前先解析一次**：取第一个选中项的真实 `playurl`，
  用它的 `dash` 数据填充选项，只列出该视频确实支持的清晰度与该档位真实存在的编码。
  其余视频在下载时由 `DashInfo.pickVideo` / `pickAudio` 自动回退到各自可用的档位。
- **批量下载面板缺少「音频」选项**：现在与解析结果页完全一致，
  可以挑选具体音轨（含 Hi-Res 无损 / 杜比全景声）。
- 参考视频解析失败时（未登录 / 会员内容 / 网络异常）不再静默给出假档位，
  而是明确提示失败原因，并说明已退回通用档位。

### 改进

- 把「解析结果页」的清晰度 / 编码 / 音频 / 下载内容四个分区抽成共享组件
  `DownloadOptionsPanel`，解析结果页与批量下载弹窗共用同一份实现
  （`card` 参数区分卡片样式），两个入口的选项逻辑不会再各自漂移。

## 🎯 功能概览

- **解析**：链接 / BV 号 / av 号 / ep、ss 号 / 收藏夹 / 合集 / 观看历史 / 稍后再看 / UP 主投稿
- **下载**：内置多线程分片下载器（断点续传 + 前台服务保活），可选 Aria2（JSON-RPC）远程下载
- **合并**：系统 `MediaMuxer` 无损重新封装，不重新编码
- **转换**：FFmpeg 支持 MP4 / MKV 封装、MP3 / M4A 提取、GIF、压缩、H.264 ↔ H.265 互转
- **存储**：默认保存到系统相册（MediaStore），也支持应用目录 / 自定义目录
- **外观**：简洁白 / 少女粉 / 主题黑三套主题，可跟随系统深色模式
- **其它**：弹幕、字幕、封面下载，仅 Wi-Fi 下载，并发数与失败重试可调

## ⚠️ 已知限制

- FFmpeg 使用 full-gpl 变体，APK 体积约 63 MB
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
