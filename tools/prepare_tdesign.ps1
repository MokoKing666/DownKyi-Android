# ============================================================================
# 生成「已修补的 tdesign_flutter」到 third_party/，并写入 pubspec_overrides.yaml
#
# 背景
#   tdesign_flutter 0.2.7（当前最新稳定版，2026-01-21）的 lib/src/components/icon/
#   td_icons.dart 里写了：
#       @immutable
#       class _TDIconsData extends IconData { ... }
#   而 Flutter 3.47 起 IconData 已声明为 `final class`（本项目 3.49 实测确认：
#   packages/flutter/lib/src/widgets/icon_data.dart 里就是 `final class IconData`），
#   继承它直接是编译错误：
#       The class 'IconData' can't be extended outside of its library.
#
#   上游修复只出现在 1.0.0-alpha.1（把图标拆为独立的 tdesign_flutter_icons 包，
#   并移除内置 TDIcons 字体），属预发布版本，不能用于正式构建；
#   0.2.8-fix.1 未做结构性改动。因此补丁在可预见的未来仍需保留。
#
# 为什么不用「直接改 pub 缓存」的老办法
#   老脚本 tools/patch_tdesign_icons.ps1 直接改写
#   %LOCALAPPDATA%\Pub\Cache\...\td_icons.dart，有三个问题：
#     1. 不可重复构建——CI / 换机器 / 缓存被清都要重来，容易漏掉；
#     2. 改写的是所有工程共享的缓存，会污染别的项目；
#     3. `flutter pub get` 一旦重下该包，补丁就静默失效，现象是莫名其妙编译失败。
#
# 本方案
#   从 pub 缓存复制「运行所需的最小集合」（lib / assets / pubspec.yaml / LICENSE），
#   在副本上打补丁，落到 third_party/tdesign_flutter/（**已 gitignore，不进仓库**），
#   再写入 pubspec_overrides.yaml（同样 gitignore）让 pub 指过去。
#
#   于是：pub 缓存不被改写、别的工程不受影响、同一 pub 版本必然产出同一份代码、
#   仓库不因此膨胀。代价是 clone 之后需要执行一次本脚本。
#
# 用法
#   powershell -ExecutionPolicy Bypass -File tools\prepare_tdesign.ps1
#
#   脚本会自己编排顺序（需要两次 pub get，因为 override 指向的路径必须先存在）：
#     1. 缓存里没有 tdesign_flutter 时，先跑一次 flutter pub get 把它拉下来
#     2. 生成 third_party/tdesign_flutter 并打补丁
#     3. 写入 pubspec_overrides.yaml
#     4. 再跑一次 flutter pub get 让 override 生效
# ============================================================================
[CmdletBinding()]
param(
    # 跳过最后的 flutter pub get（由调用方自己负责时使用）
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetDir = Join-Path $repoRoot 'third_party/tdesign_flutter'
$overrideFile = Join-Path $repoRoot 'pubspec_overrides.yaml'

# pub 缓存位置跨平台：
#   Windows PowerShell 5.1 下 $IsWindows 未定义（$null），靠 $env:OS 兜底
#   Linux / macOS（CI 用）是 ~/.pub-cache
#   PUB_CACHE 环境变量优先级最高
function Resolve-PubCacheRoot {
    if ($env:PUB_CACHE) { return $env:PUB_CACHE }
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'Pub/Cache') }
    }
    $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
    if ($homeDir) { return (Join-Path $homeDir '.pub-cache') }
    return $null
}

$cacheHome = Resolve-PubCacheRoot
if (-not $cacheHome) { throw '无法定位 pub 缓存目录，请设置 PUB_CACHE 环境变量。' }
$cacheRoot = Join-Path $cacheHome 'hosted/pub.dev'

if (-not (Test-Path $cacheRoot)) {
    throw "未找到 pub 缓存目录：$cacheRoot（请先执行 flutter pub get）"
}
Write-Host ("[环境] pub 缓存: {0}" -f $cacheRoot)

# ---------------------------------------------------------------------------
# 1. 确保 pub 缓存里有 tdesign_flutter
# ---------------------------------------------------------------------------
function Get-TdesignCache {
    Get-ChildItem $cacheRoot -Directory -Filter 'tdesign_flutter-*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'tdesign_flutter_*' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

$source = Get-TdesignCache
if (-not $source) {
    Write-Host '=== 1/4 pub 缓存里没有 tdesign_flutter，先执行 flutter pub get ==='
    Push-Location $repoRoot
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败（退出码 $LASTEXITCODE）" }
    } finally {
        Pop-Location
    }
    $source = Get-TdesignCache
}
if (-not $source) {
    throw 'flutter pub get 之后缓存里仍然没有 tdesign_flutter，请检查网络与 pubspec.yaml。'
}
Write-Host ("=== 1/4 源包: {0} ===" -f $source.Name)

# 一律用正斜杠：PowerShell Core 在 Linux 上不会把 `\` 当分隔符转换，
# Join-Path 会拼出一个带反斜杠的字面路径直接找不到文件。Windows 也接受 `/`。
$iconFile = Join-Path $source.FullName 'lib/src/components/icon/td_icons.dart'
if (-not (Test-Path $iconFile)) { throw "源包里找不到 td_icons.dart：$iconFile" }

# ---------------------------------------------------------------------------
# 2. 复制最小集合并打补丁
# ---------------------------------------------------------------------------
Write-Host '=== 2/4 复制并修补 ==='
if (Test-Path $targetDir) { Remove-Item $targetDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
# example / demo_tool / test 是 4.21MB 里的大部分，运行不需要
foreach ($item in @('lib', 'assets', 'pubspec.yaml', 'LICENSE')) {
    $from = Join-Path $source.FullName $item
    if (Test-Path $from) { Copy-Item $from (Join-Path $targetDir $item) -Recurse -Force }
}

$patched = Join-Path $targetDir 'lib/src/components/icon/td_icons.dart'
$text = [System.IO.File]::ReadAllText($patched)

if ($text.Contains('extends IconData')) {
    # 2.1 删掉继承 IconData 的私有类。
    #     它的 name 字段没有被库内任何代码使用；应用侧也从未直接引用 TDIcons.*
    #     （全项目 grep 确认），所以退化为普通 IconData 构造不影响渲染——
    #     fontFamily 与 fontPackage 都原样保留。
    $text = [regex]::Replace(
        $text,
        "@immutable\s*class _TDIconsData extends IconData \{[\s\S]*?\r?\n\}\r?\n",
        ''
    )
    # 2.2 图标常量改为原生 IconData 构造
    $text = [regex]::Replace(
        $text,
        "_TDIconsData\(0x([0-9A-Fa-f]+), '[^']*'\)",
        "IconData(0x`$1, fontFamily: 'TDIcons', fontPackage: 'tdesign_flutter')"
    )
    # 2.3 名称 -> 图标 映射表的泛型参数
    $text = $text.Replace('<String, _TDIconsData>', '<String, IconData>')
    # 2.4 兜底：把残留下来的类型标注也换成 IconData。
    #     不同小版本的声明写法不完全一致（有的写 `static const IconData x = _TDIconsData(...)`，
    #     有的写 `static const _TDIconsData x = ...`），只靠上面两条正则会在后者上残留，
    #     而残留会导致编译失败。到这一步若还有 _TDIconsData，它只可能是类型标注。
    $text = $text.Replace('_TDIconsData', 'IconData')
    [System.IO.File]::WriteAllText($patched, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '  [已修补] td_icons.dart'
} else {
    Write-Host '  [跳过] td_icons.dart 已无需修补'
}

$remain = ([regex]::Matches($text, '_TDIconsData')).Count
if ($remain -ne 0) { throw "补丁未完成，仍有 $remain 处 _TDIconsData" }

# ---------------------------------------------------------------------------
# 3. 写入 pubspec_overrides.yaml
# ---------------------------------------------------------------------------
Write-Host '=== 3/4 写入 pubspec_overrides.yaml ==='
# 相对路径交给 pub 解析；这里用 POSIX 分隔符，避免 Windows 反斜杠在 YAML 里的转义问题
$yaml = @"
# 由 tools/prepare_tdesign.ps1 生成，请勿手工编辑。
# 作用：把 tdesign_flutter 指向 third_party/ 里那份修补过的副本，
#       从而不必改写 pub 缓存（详见脚本头部说明）。
dependency_overrides:
  tdesign_flutter:
    path: third_party/tdesign_flutter
"@
[System.IO.File]::WriteAllText($overrideFile, $yaml, (New-Object System.Text.UTF8Encoding($true)))

$files = Get-ChildItem $targetDir -Recurse -File
$sum = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host ("  输出: {0}" -f $targetDir)
Write-Host ("  体积: {0:N2} MB / {1} 个文件（未包含 example / demo_tool）" -f ($sum / 1MB), $files.Count)

# ---------------------------------------------------------------------------
# 4. 让 override 生效
# ---------------------------------------------------------------------------
if ($SkipPubGet) {
    Write-Host '=== 4/4 已跳过 flutter pub get（调用方负责）==='
    exit 0
}

Write-Host '=== 4/4 flutter pub get（让 override 生效）==='
Push-Location $repoRoot
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败（退出码 $LASTEXITCODE）" }
} finally {
    Pop-Location
}
Write-Host '完成。'
