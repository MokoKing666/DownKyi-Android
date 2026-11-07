# ============================================================================
# 构建精简包（DownKyi Lite）
#
# APK 体积几乎全被 FFmpeg 吃掉：arm64-v8a 下 libavcodec 21MB、libavfilter 10MB、
# libavformat 8MB，合计约 42MB，而整个 APK 约 64MB。
# 但相当一部分用户只想要「下载 + 直接播放」，转码、GIF、H.265 都用不上。
#
# 本脚本通过 Gradle 属性 downkyi.lite=true 让 AGP 在打包时排除 FFmpeg 的 .so，
# 同时给 Dart 侧传 --dart-define=DOWNKYI_LITE=true，让工具箱里的转换入口
# 直接给出「精简包不含此功能」的提示，而不是点了之后崩在 native 库里。
#
# 注意：这**不是** productFlavors。一旦声明 flavor，`flutter build apk`
# 就必须带 --flavor，现有的 CI 与 tools/build_apk.ps1 会全部失效——
# 这个代价不该由一个体积优化来付。所以做成了显式开关。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\build_lite.ps1
# ============================================================================
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# 复用主构建脚本里的工具链探测与 tdesign 准备逻辑
Write-Host '=== 1/2 准备依赖与 tdesign ==='
& (Join-Path $PSScriptRoot 'prepare_tdesign.ps1')

Write-Host "`n=== 2/2 构建精简包（排除 FFmpeg 原生库）==="
& flutter build apk `
    --release `
    --target-platform android-arm64 `
    --dart-define=DOWNKYI_LITE=true `
    -Pdownkyi.lite=true

if ($LASTEXITCODE -ne 0) {
    Write-Error '精简包构建失败'
    exit 1
}

$apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Error '未生成 APK'
    exit 1
}

$version = 'unknown'
if ((Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw) -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $version = $Matches[1]
}
$target = Join-Path $repoRoot "DownKyi-v$version-lite-arm64-v8a.apk"
Copy-Item $apk $target -Force

$size = [Math]::Round((Get-Item $target).Length / 1MB, 2)
Write-Host "`n精简包：$target（$size MB）"
Write-Host '功能差异：不含格式转换 / GIF / H.264<->H.265；下载、合并、相册落盘、弹幕字幕全部可用。'
