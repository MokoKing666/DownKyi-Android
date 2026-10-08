<#
.SYNOPSIS
    一键构建 arm64-v8a 的 release APK。

.DESCRIPTION
    流程：
      1. 解析工具链（优先用已有环境变量，否则探测常见安装位置）
      2. flutter pub get
      3. 准备修补过的 tdesign_flutter（tools/prepare_tdesign.ps1）
      4. flutter build apk --release --target-platform android-arm64
      5. 把产物复制为 DownKyi-v<版本>-arm64-v8a.apk 放到工程根目录

.PARAMETER SkipPubGet
    跳过 flutter pub get（依赖已就绪时可加快速度）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/build_apk.ps1

.NOTES
    工程路径不能包含中文：AGP 会报 non-ASCII characters 并拒绝构建，
    Dart 分析器也会因 LSP 通道 URI 编码问题崩溃。含中文时脚本会给出提示。
#>
[CmdletBinding()]
param(
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# 工具探测
# ---------------------------------------------------------------------------

function Resolve-Tool {
    param([string[]]$Candidates)
    foreach ($pattern in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        try {
            $hit = Get-Item -Path $pattern -ErrorAction Stop | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        } catch {
            # 继续尝试下一个候选
        }
    }
    return $null
}

# JDK：优先复用已有的 JAVA_HOME
if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $env:JAVA_HOME = Resolve-Tool @(
        "$env:USERPROFILE\Android\jdk\jdk-*",
        'C:\Android\jdk\jdk-*',
        'C:\Program Files\Eclipse Adoptium\jdk-*',
        'C:\Program Files\Java\jdk-*',
        'C:\Program Files\Microsoft\jdk-*'
    )
}
if (-not $env:JAVA_HOME) {
    Write-Error '未找到 JDK（需要 17 及以上）。请设置 JAVA_HOME 环境变量后重试。'
    exit 1
}

# Android SDK
if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    $env:ANDROID_HOME = Resolve-Tool @(
        "$env:LOCALAPPDATA\Android\Sdk",
        'C:\Android\sdk',
        'D:\Android\Sdk'
    )
}
if (-not $env:ANDROID_HOME) {
    Write-Error '未找到 Android SDK。请设置 ANDROID_HOME 环境变量后重试。'
    exit 1
}
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

# Flutter
$flutterBin = Resolve-Tool @(
    $(if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT 'bin' }),
    "$env:USERPROFILE\flutter\bin",
    'C:\flutter\bin',
    'C:\src\flutter\bin',
    'D:\flutter\bin'
)
if (-not $flutterBin) {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { $flutterBin = Split-Path $cmd.Source -Parent }
}
if (-not $flutterBin) {
    Write-Error '未找到 Flutter SDK。请设置 FLUTTER_ROOT 或把 flutter 加入 PATH 后重试。'
    exit 1
}

$env:PATH = "$flutterBin;$env:JAVA_HOME\bin;$env:PATH"
# JVM 走 IPv6 时下载 Maven 依赖容易超时，强制 IPv4
$env:GRADLE_OPTS = '-Djava.net.preferIPv4Stack=true'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host '=== 工具链 ==='
Write-Host "Flutter : $flutterBin"
Write-Host "JDK     : $env:JAVA_HOME"
Write-Host "SDK     : $env:ANDROID_HOME"
Write-Host "工程    : $projectRoot"

if ($projectRoot -match '[^\x00-\x7F]') {
    Write-Warning "工程路径包含非 ASCII 字符（$projectRoot）。"
    Write-Warning 'AGP 会拒绝构建、Dart 分析器会崩溃，请先复制到纯英文路径（例如 C:\DownKyi）再执行。'
}

# ---------------------------------------------------------------------------
# 构建
# ---------------------------------------------------------------------------

if (-not $SkipPubGet) {
    Write-Host "`n=== 1/4 flutter pub get ==="
    flutter pub get
}

Write-Host "`n=== 2/4 准备修补过的 tdesign_flutter ==="
# 生成 third_party/tdesign_flutter 与 pubspec_overrides.yaml（pub 缓存不被改写）
& (Join-Path $PSScriptRoot 'prepare_tdesign.ps1') -SkipPubGet
if ($LASTEXITCODE -ne 0) {
    Write-Error '准备 tdesign_flutter 失败'
    exit 1
}
# override 发生变化时必须重新解析依赖
flutter pub get

Write-Host "`n=== 3/4 构建 arm64-v8a release APK ==="
flutter build apk --release --target-platform android-arm64

Write-Host "`n=== 4/4 结果 ==="
$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Error '未生成 APK，请查看上面的构建日志'
    exit 1
}

$version = 'unknown'
if ((Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw) -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $version = $Matches[1]
}
$target = Join-Path $projectRoot "DownKyi-v$version-arm64-v8a.apk"
Copy-Item $apk $target -Force

$size = [Math]::Round((Get-Item $target).Length / 1MB, 2)
Write-Host "打包成功：$target（$size MB）"
