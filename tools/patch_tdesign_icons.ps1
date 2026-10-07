# ============================================================================
# 修补 tdesign_flutter 的 td_icons.dart
#
# 背景：tdesign_flutter 0.2.7 / 0.2.8-fix.1 的图标常量通过
#       `class _TDIconsData extends IconData` 实现，
#       而 Flutter 3.47+ 已把 IconData 声明为 `final class`，
#       导致编译期报错：The class 'IconData' can't be extended outside of its library。
#
# 本脚本把 pub 缓存中的该文件改写为「直接构造 IconData」，
# 保留 fontFamily / fontPackage，因此图标字体仍然正常渲染。
#
# 用法：flutter pub get 之后执行一次（每次 pub 重新下载该包后都需要重跑）
#   powershell -ExecutionPolicy Bypass -File tools\patch_tdesign_icons.ps1
# ============================================================================
$ErrorActionPreference = 'Stop'

$cacheRoot = Join-Path $env:LOCALAPPDATA 'Pub\Cache\hosted\pub.dev'
if (-not (Test-Path $cacheRoot)) { throw "未找到 pub 缓存目录：$cacheRoot" }

$packages = Get-ChildItem $cacheRoot -Directory -Filter 'tdesign_flutter-*' -ErrorAction SilentlyContinue
if (-not $packages) { throw 'pub 缓存中没有 tdesign_flutter，请先执行 flutter pub get' }

$patched = 0
foreach ($pkg in $packages) {
    $file = Join-Path $pkg.FullName 'lib\src\components\icon\td_icons.dart'
    if (-not (Test-Path $file)) { continue }

    $text = [System.IO.File]::ReadAllText($file)
    if (-not $text.Contains('extends IconData')) {
        Write-Host "[跳过] $($pkg.Name) 无需修补"
        continue
    }

    # 1) 删除继承 IconData 的私有类（其 name 字段未被库内任何代码使用）
    $text = [regex]::Replace(
        $text,
        "@immutable\s*class _TDIconsData extends IconData \{[\s\S]*?\r?\n\}\r?\n",
        ''
    )
    # 2) 所有图标常量改为原生 IconData 构造
    $text = [regex]::Replace(
        $text,
        "_TDIconsData\(0x([0-9A-Fa-f]+), '[^']*'\)",
        "IconData(0x`$1, fontFamily: 'TDIcons', fontPackage: 'tdesign_flutter')"
    )
    # 3) 名称 -> 图标 映射表也用 IconData
    $text = $text.Replace('<String, _TDIconsData>', '<String, IconData>')

    [System.IO.File]::WriteAllText($file, $text, (New-Object System.Text.UTF8Encoding($false)))
    $remain = ([regex]::Matches($text, '_TDIconsData')).Count
    Write-Host "[已修补] $($pkg.Name)  残留 _TDIconsData=$remain"
    $patched++
}

Write-Host "完成：共修补 $patched 个包"
