<div align="center">

<img src="docs/logo.png" width="128" height="128" alt="哔哩哔哩下载姬" />

# 哔哩哔哩下载姬 · Android

**DownKyi for Android** — 哔哩哔哩视频下载工具，使用 Flutter + TDesign 重写

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TDesign](https://img.shields.io/badge/UI-TDesign%20Flutter-FB7299)](https://github.com/Tencent/tdesign-flutter)
[![minSdk](https://img.shields.io/badge/minSdk-24-orange)](#环境要求)
[![targetSdk](https://img.shields.io/badge/targetSdk-36-orange)](#环境要求)
[![ABI](https://img.shields.io/badge/ABI-arm64--v8a-informational)](#环境要求)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue)](LICENSE)
[![Author](https://img.shields.io/badge/Author-MokoKing666-FB7299)](https://github.com/MokoKing666)

</div>

---

## 📖 简介

这是桌面端 **哔哩下载姬（DownKyi）** 的 Android 移植实现，功能参考
[crazysmile-PhD/downkyicore](https://github.com/crazysmile-PhD/downkyicore)（哔哩下载姬跨平台版），
UI 采用腾讯 **TDesign Flutter** 官方组件库，音视频封装使用系统 `MediaMuxer`，
格式转换使用 **FFmpeg**，并支持把任务交给 **Aria2** 执行。

| 项目 | 值 |
|---|---|
| 包名 | `com.moko.downkyi` |
| 版本 | v1.3.0（versionCode 5） |
| 作者 | **MokoKing666** · 672627254@qq.com |
| 支持系统 | Android 7.0+（API 24 ~ 36） |
| 架构 | **仅 arm64-v8a** |
| APK 体积 | 约 63 MB（含 FFmpeg 全功能原生库约 42 MB） |
| 默认主题 | 简洁白（强调色哔哩哔哩粉 `#FB7299`） |
| 默认保存位置 | **系统相册**（MediaStore） |

> ⚠️ 本项目仅提供视频解析与本地下载能力，不提供任何内容存储服务，也不上传任何数据。
> 所有内容版权归原作者所有，仅供个人学习交流，请支持原始发布者。

---

## ✨ 功能特性

| 模块 | 能力 |
|---|---|
| **解析入口** | BV 号 / av 号 / 完整链接 / `b23.tv` 短链 / `ep`、`ss` 番剧 / 课程（cheese）/ 收藏夹 / UP 主空间投稿 / 合集（lists） |
| **资源类型** | 视频流、音频流、封面、弹幕（XML / ASS / TXT）、字幕（CC，自动转 srt） |
| **清晰度** | 8K / 杜比视界 / HDR / 4K / 1080P60 / 1080P+ / 1080P / 720P / 480P（DASH 全格式 `fnval=4048`） |
| **编码与音轨** | AVC / HEVC / AV1 自动匹配；音轨可选 64K / 132K / 192K / 杜比全景声 / Hi-Res 无损 |
| **下载引擎** | **内置下载器**（多线程分片 + 断点续传）或 **Aria2**（JSON-RPC，可交给 NAS / 电脑下载） |
| **下载控制** | 并发任务队列、暂停 / 继续、失败自动重试、仅 Wi-Fi 下载 |
| **后台能力** | 前台服务 + 通知栏实时进度，息屏 / 切后台不中断 |
| **保存位置** | **系统相册**（默认，MediaStore）/ 应用目录 / 自定义目录 |
| **媒体处理** | 系统 `MediaMuxer` **无损重新封装**（`video.m4s` + `audio.m4s` → `mp4`，不转码） |
| **格式转换** | **FFmpeg**：无损封装 MP4 / MKV、提取 MP3 / M4A、生成 GIF、压缩体积、H.264 ↔ H.265 互转，带实时进度与取消 |
| **工具箱** | 全部为可点击入口：格式转换（可选**设备上的文件**或已完成任务）、重新合并、重新生成弹幕、导出到相册 |
| **外观主题** | **简洁白**（默认）/ **少女粉** / **主题黑**，可跟随系统深色模式自动切换 |
| **账号** | 扫码登录（二维码轮询）、Cookie 粘贴登录、登录态持久化 |
| **设置** | 主题 / 保存位置 / 下载引擎（含 Aria2 配置与连通性测试）/ 并发 / 清晰度 / 编码 / 弹幕格式 / 命名模板 / GIF 帧率 / 运行日志 |

---

## 🎨 主题系统

已**移除原有的 TDesign 蓝色主题**（`#0052D9`），改为三套以**哔哩哔哩粉** `#FB7299` 为强调色的主题：

| 主题 | 说明 | 主要色值 |
|---|---|---|
| **简洁白**（默认） | 页面与卡片大面积留白，哔哩哔哩粉点缀，靠极细描边区分层次 | 底 `#FFFFFF` / 卡片 `#FFFFFF` / 强调 `#FB7299` |
| **少女粉** | 哔哩哔哩粉铺开做主色调，柔和粉底 | 底 `#FFF3F7` / 导航 `#FFE3EC` / 强调 `#FB7299` |
| **主题黑** | 深色护眼，适合夜间 | 底 `#121315` / 卡片 `#1C1D20` / 强调 `#FB7299` |

- **切换入口**：「我的」页右上角的主题按钮，或「我的 → 主题颜色」列表项，也可在「设置 → 主题外观」进入。
  弹出面板提供色板预览与「跟随系统深色模式」开关。
- **跟随系统**：开启后系统切到深色模式会自动套用「主题黑」，切回浅色恢复所选主题（默认开启）。
- **实现方式**：色板集中在 `lib/ui/theme.dart`（`AppThemeTokens`），
  根组件构建子树前用 `TdPalette.apply()` 注入，同时通过 `TDThemeData.copyWithTDThemeData`
  把品牌色阶覆写进 TDesign 主题 —— 因此 `TDButton` / `TDCell` / `TDSwitch` 等官方组件
  与自研组件会**同步换肤**，业务代码无需改动。

---

## 🧩 两种下载引擎

在「设置 → 下载引擎」切换：

### 内置下载器（默认）

自研多线程分片下载，完全在手机本地完成：下载 → `MediaMuxer` 无损封装 → 存入系统相册。

### Aria2（JSON-RPC）

把任务下发给 aria2 执行，**文件落在 aria2 所在设备**（NAS / 电脑 / Termux 等），
App 负责下发任务、显示进度、暂停 / 继续 / 删除。

配置项：`RPC 地址`（默认 `http://127.0.0.1:6800/jsonrpc`）、`RPC 密钥`、`落盘目录`、`单文件连接数`，
并提供「测试连接」按钮直接读取 aria2 版本与队列状态。

服务端示例（在 NAS / 电脑 / Termux 上执行一次）：

```bash
aria2c --enable-rpc --rpc-listen-all=true --rpc-secret=你的密钥 --continue=true
```

> **为什么 Aria2 模式下不自动合并、不进相册？**
> 因为文件由 aria2 写到了它自己所在设备的磁盘上，手机端拿不到这些文件。
> 如果需要「自动合并并保存到手机相册」，请使用内置下载器。
> Aria2 模式优先使用 `durl` 直链（单个完整 mp4）；没有直链时下发 DASH 视频流与音频流两个文件。

---

## 🧾 更新日志

### v1.3.0

**修复**

- **观看历史一直抓不到内容**：新版 `history/cursor` 接口把 `bvid` / `cid` / `oid`
  全部放在 `list[i].history` 子对象里，顶层只有 `kid`，而且**根本没有 `aid` 字段**
  （番剧时 `kid` 是 ssid，不能当 avid 用）。过去读的是顶层 `bvid`，它恒为空字符串，
  于是每条记录都在 `if (bvid.isEmpty) continue;` 处被跳过，最终返回空列表
  （表现为「没有可取的内容」）。现在改从 `history` 子对象取字段，并按业务类型分流：
  `archive` 稿件用 `bvid` + `cid`，`pgc` 番剧用 `epid` 走番剧播放地址，
  `live` / `article` / `article-list` 不是可下载的视频，直接过滤掉。

**新增**

- **批量下载前可选择清晰度 / 编码 / 下载内容**：收藏夹、合集、观看历史、稍后再看、
  整季番剧的「下载选中」现在会先弹出设置面板再创建任务。
  批量入口没有单个视频的 `playurl` 信息，面板给出的是通用清晰度列表，
  选到某个视频不支持的档位不会失败——服务端会回退到该视频实际可用的最高档
  （`DashInfo.pickVideo` 的兜底逻辑）。过去这些入口只能沿用「设置」里的默认值，
  无法针对某次批量下载单独调整。

**改进**

- **常用入口排版**：原来用固定 `width: 150` 的卡片，宽屏下每行只占 312px、
  右侧留出一条参差的空隙，窄屏又容易把文字挤成省略号。
  现在用 `LayoutBuilder` 按容器实际宽度等分两列（卡片宽度动态计算），
  并把卡片高度统一为 56，任何屏幕宽度都能铺满整行。

### v1.2.1

**修复**

- **合并出来的视频没有声音（重要）**：`MediaMuxerHelper` 过去只 `selectTrack` 第一条视频轨，
  于是 durl 直链下载到的**完整 mp4**（音视频同在一个文件里）在重新封装时音频被静默丢掉。
  现在改为**搬运输入文件里的全部音视频轨**，按时间戳交错写入，音画都不丢。
- **单独下载音频时必然封装失败**：`_merge` 里写成「没有视频轨就把音频也丢掉」，
  于是 `mux(null, null)` 直接返回失败、任务显示「已完成（未合并）」。现在音频会无条件传入。
- **「自动合并音视频」开关是死设置**：`settings.mergeAv` 从未被下载逻辑读取，
  关掉它仍然会合并。现在真正生效（关闭后只保留分片，可在工具箱手动合并）。
- durl 直链下载到的完整 mp4 不再重复封装，直接改名落地，省掉一次全文件拷贝。

**改进**

- 「清空记录」新增两个选项：**只删除记录**（保留已下载的文件）与
  **删除记录和源文件**（含已导出到系统相册的副本），后者有二次确认。
- 仓库整理：`.gitignore` 排除 APK 与构建日志，新增 `.gitattributes` 统一换行符。

### v1.2.0

**修复**

- **收藏夹 / UP 主投稿 / 合集 / 稍后再看 进去后下载报「请求失败」**：
  B 站各列表接口对 `cid` 的返回位置不统一（收藏夹在 `ugc.first_cid`，
  UP 主投稿与合集接口完全不返回），过去会拿 `cid=0` 去请求 `playurl`，必然失败。
  现在按多种形态解析 cid，并在下载前由 `DownloadManager._ensureCid` 补一次详情查询兜底（含回写缓存）。
- **观看历史抓取不到**：游标参数过去被显式传成 `max=0&view_at=0&business=`，
  容易被判定为参数不合法（-400）；现在首屏不传游标，交给服务端用默认值。
  同时给历史 / 稍后再看 / 收藏夹 / 合集等列表接口加上**容错的 WBI 签名**
  （取不到密钥时自动退回未签名请求，不会因签名环节失败而整个接口不可用）。
- 列表加载失败时不再只提示「加载失败」，而是直接显示接口返回的错误码与原因
  （例如 `-101 账号未登录（请重新登录刷新 Cookie）`），便于定位问题。
- 批量入口（收藏夹 / 合集 / 历史 / 稍后再看 / 整季）过去用字段初始值（1080P / AVC）下载，
  未遵循「默认清晰度 / 编码 / 默认下载内容」设置，现已修正。

**改进**

- 工具箱改造：原来的静态说明改为**可点击的工具入口**；
  格式转换支持「选择设备上的文件」（系统文件选择器，可转手机里任意视频）与
  「从已完成任务选择」两种来源；选文件后先显示时长 / 分辨率 / 编码再挑目标格式。

### v1.1.0

**新增**

- 三套主题（简洁白 / 少女粉 / 主题黑）与「跟随系统深色模式」，移除原有蓝色主题；
  「我的」页右上角新增主题颜色按钮
- FFmpeg 格式转换：MP4 / MKV 无损封装、MP3 / M4A 提取、GIF、压缩、H.264 ↔ H.265 互转
- Aria2（JSON-RPC）下载引擎，可在设置里与内置下载器切换，并支持连通性测试
- 默认保存到系统相册（MediaStore），可选应用目录 / 自定义目录

---

## 📥 下载安装

推荐从 [**Releases**](https://github.com/MokoKing666/DownKyi-Android/releases) 下载已构建好的 APK（arm64-v8a，约 63 MB）：

```bash
adb install -r DownKyi-v1.3.0-arm64-v8a.apk
```

> 仓库**不提交 APK 二进制**（`.gitignore` 已排除 `*.apk`），发版请走 GitHub Releases。
> 当前 APK 使用的是 **debug 签名**，可直接安装体验；正式分发请自行生成 release keystore 并配置 `signingConfigs`。

---

## 🚀 从源码构建

### 环境要求

| 组件 | 版本 / 说明 |
|---|---|
| Flutter SDK | **3.47+**（stable），工程按 3.47.6 的 Android 模板对齐 |
| JDK | 17 或以上（实测 Temurin 21） |
| Android SDK | `platforms;android-36`、`build-tools;36.0.0`、`platform-tools` |
| Gradle / AGP / Kotlin | `9.3.1` / `9.1.0` / `2.4.0`（与 Flutter 模板一致，已写入工程） |

```bash
git clone https://github.com/MokoKing666/DownKyi-Android.git
cd DownKyi-Android

flutter pub get

# ⚠️ 必须先修补 tdesign_flutter 的图标兼容问题（原因见下方「构建注意事项」）
powershell -ExecutionPolicy Bypass -File tools/patch_tdesign_icons.ps1

# 只出 arm64-v8a 的 release 包
flutter build apk --release --target-platform android-arm64
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

Windows 用户也可直接使用一键脚本（自动探测 Flutter / JDK / Android SDK，
按需设置环境变量即可覆盖；内含依赖安装、图标补丁、构建与产物命名）：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_apk.ps1
```

### 关于 APK 体积

FFmpeg 全功能库（`ffmpeg_kit_flutter_new`，含 x264 / x265 / lame 等 GPL 编解码器）
在 arm64-v8a 下约 **42 MB**：`libavcodec.so` 21 MB、`libavfilter.so` 10 MB、`libavformat.so` 8 MB。
若只想保留核心能力，可把 `pubspec.yaml` 中的依赖换成同系列的 `_min` 变体
（仅内置编解码器，体积显著变小，但不能用 `libx264` / `libmp3lame` 等外部编码器）。

### Android 侧配置

```kotlin
// android/app/build.gradle.kts
namespace = "com.moko.downkyi"
compileSdk = 36
defaultConfig {
    applicationId = "com.moko.downkyi"
    minSdk = 24
    targetSdk = 36
    ndk { abiFilters += listOf("arm64-v8a") }
}
packaging {
    // 依赖 AAR（FFmpeg、datastore 等）自带的其它 ABI 预编译库也一并排除
    jniLibs { excludes += setOf("lib/armeabi/**", "lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**") }
}
```

### 构建注意事项（实测踩坑记录）

1. **工程路径不能含中文**：AGP 会直接报 `Your project path contains non-ASCII characters`，
   Dart 分析器也会因 LSP 通道 URI 编码问题直接崩溃。
   工程里已加 `android.overridePathCheck=true`，但仍建议放在纯英文路径构建
   （本次即在 `C:\DownKyi` 完成构建与分析）。
2. **`tdesign_flutter` 与新版 Flutter 不兼容（必须处理）**：
   其 `td_icons.dart` 用 `class _TDIconsData extends IconData` 定义图标常量，
   而 Flutter 3.47+ 已把 `IconData` 改为 `final class`（0.2.7 与 0.2.8-fix.1 均未修复）。
   `tools/patch_tdesign_icons.ps1` 会把它改写为直接构造 `IconData`，保留 `fontFamily/fontPackage`，
   图标字体仍正常渲染。**每次 `flutter pub get` 重新下载该包后需要重跑一次。**
3. **JVM 走 IPv6 易导致依赖下载超时**：`android/gradle.properties` 已加
   `-Djava.net.preferIPv4Stack=true`；若 wrapper 下载 Gradle 发行包仍超时，
   可手动下载后放入 `~/.gradle/wrapper/dists/gradle-<版本>-bin/<hash>/` 并创建同名 `.ok` 文件。
4. **缺少 NDK 只会警告**：本项目无 C/C++ 代码，如需彻底消除提示，
   可删除 `app/build.gradle.kts` 中的 `ndkVersion = flutter.ndkVersion` 一行。
5. **`tools/*.ps1` 必须以 UTF-8 with BOM 保存**：Windows PowerShell 5.1 会按 ANSI（GBK）
   解析没有 BOM 的脚本，脚本里的中文会让字符串的收尾引号被吞掉，
   报出一堆莫名其妙的 `Missing type name after '['` 之类语法错误。
   修改这两个脚本后请确认编码仍带 BOM。

---

## 🗂 项目结构

```
lib/
├── main.dart                     应用入口：初始化设置 / 下载队列 / Provider
├── app.dart                      主题注入 + TDTheme + MaterialApp（换肤时重建子树）
├── core/
│   ├── constants.dart            接口地址、UA、清晰度/编码/引擎/保存位置/转换目标枚举
│   ├── wbi.dart                  WBI 签名（mixinKey 重排 + md5）
│   ├── link_parser.dart          链接识别（BV/av/ep/ss/收藏夹/合集/短链）
│   ├── protobuf_lite.dart        极简 protobuf 读取器（用于弹幕接口）
│   ├── formatter.dart            时长 / 体积 / 速度 / 文件名格式化
│   └── logger.dart               环形日志（设置页可查看）
├── data/
│   ├── http_client.dart          dart:io HttpClient 封装：Cookie、Referer、WBI 参数
│   ├── bili_api.dart             全部接口：view / playurl / pgc / pugv / nav / 二维码 / 收藏夹 / 合集 / 历史 / 字幕 / 弹幕
│   ├── danmaku_parser.dart       弹幕 protobuf 分片解析
│   ├── models.dart               手写 fromJson 的数据模型（不使用代码生成）
│   ├── download_task.dart        任务模型（分片进度、状态机、aria2 gid、相册导出状态）
│   ├── task_dao.dart             sqflite 任务持久化（version 2，含 aria2 / 导出字段迁移）
│   └── settings_store.dart       SharedPreferences 设置（含主题、引擎、Aria2、保存位置）
├── download/
│   ├── segment_downloader.dart   多线程分片 + 断点续传核心
│   ├── download_manager.dart     双引擎调度 / 合并 / 相册落盘 / 附加资源 / 通知
│   ├── aria2_client.dart         Aria2 JSON-RPC 客户端（addUri / tellStatus / pause …）
│   ├── ffmpeg_service.dart       FFmpeg 封装：探测、参数拼装、执行、进度、取消
│   └── danmaku_writer.dart       弹幕 → ASS（\move + 轨道避让）/ XML / TXT
├── native/bridge.dart            MethodChannel 封装（mux / 导出 / content uri 落地 / 服务）
├── state/                        Provider 控制器（解析、登录、底部导航）
└── ui/
    ├── theme.dart                三套主题的 Design Token + TDesign colorMap 映射
    ├── td.dart                   TDesign 设计令牌（可换肤）+ 通用组件
    ├── home_shell.dart           TDBottomTabBar 四标签框架
    ├── widgets/                  视频卡片、任务卡片、选项卡、主题选择面板
    └── pages/                    解析 / 结果 / 列表 / 下载 / 工具 / 我的 / 登录 / 设置

android/app/src/main/kotlin/com/moko/downkyi/
├── MainActivity.kt               注册 MethodChannel（并接收系统分享的链接）
├── NativeBridge.kt               mux / 通知服务 / 打开 / 导出到相册 / content uri 落地与删除 / Wi-Fi 判断
├── MediaMuxerHelper.kt           MediaMuxer 无损封装（支持仅视频、仅音频）
└── DownloadService.kt            前台服务：保活 + 通知栏进度

tools/
├── build_apk.ps1                 一键打包（环境变量 + 补丁 + 构建 + 校验）
└── patch_tdesign_icons.ps1       修补 tdesign_flutter 的 IconData 兼容问题
```

---

## 🔧 技术实现要点

- **断点续传用 part 文件而非文件偏移**：每个分片写入独立的 `.partN`，全部完成后顺序拼接。
  这样彻底避免多线程共用同一文件句柄导致的写入错位；恢复进度只需看 part 文件长度，
  且播放地址过期后重新解析（字节内容不变）依然能续传。
- **下载时的封装走 `MediaMuxer` 而不是 FFmpeg**：B 站 DASH 流是分片的 `m4s`，
  只需抽取样本重新封装，**不转码、无画质损失**。系统 API 没有进程 / 会话开销，作为下载热路径更快；
  FFmpeg 只在用户主动要求「格式转换 / 转码 / 提取音频」时按需调用。
  少数设备不支持某种编码封装时会回退为保留原始分片，并可在工具箱里重试或改用 FFmpeg 转换。
- **默认保存到系统相册**：Android 10+ 通过 `MediaStore` 写入
  （视频 → `Movies/DownKyi`，图片 → `Pictures/DownKyi`，弹幕 / 字幕 → `Downloads/DownKyi`），
  **无需任何存储权限**；Android 9 及以下直接写公共目录（`WRITE_EXTERNAL_STORAGE`，已限定 `maxSdkVersion=28`）。
  导出成功后删除应用私有副本，避免同一文件占两份空间；导出失败会自动回退为保留本地副本，绝不丢文件。
- **相册文件可继续加工**：默认落盘到相册后，任务里保存的是 `content://` URI。
  打开、删除、FFmpeg 转换都做了适配：删除走 `ContentResolver`，
  转换前先用原生方法把 URI 复制成真实文件（FFmpeg 只认真实路径）。
- **换肤不侵入业务代码**：色板用 `AppThemeTokens` 集中定义，
  根组件构建前注入静态令牌；同时给 `MaterialApp` 带上随主题变化的 `key` 强制重建子树，
  否则 `const` widget 会继续沿用旧配色。底部导航的选中态放在独立的 `ShellController` 中，
  保证换肤重建后仍停留在原标签页。
- **网络层零第三方依赖**：用 `dart:io` 的 `HttpClient` 自行管理 Cookie / Range / 重试，
  仅引入 `provider`、`sqflite`、`shared_preferences`、`path_provider`、`crypto`、`qr_flutter`、
  `tdesign_flutter`、`ffmpeg_kit_flutter_new`。

---

## ❓ 常见问题

<details>
<summary>主题在哪里切换？</summary>

「我的」页右上角的主题按钮，或「我的 → 主题颜色」，也可在「设置 → 主题外观」。
面板里有三套主题的色板预览，以及「跟随系统深色模式」开关（默认开启）。
</details>

<details>
<summary>下载的文件在哪里？</summary>

默认保存到**系统相册**：视频在 `Movies/DownKyi`，图片在 `Pictures/DownKyi`，
弹幕 / 字幕在 `Downloads/DownKyi`，其他应用与系统相册都能直接看到。
也可以在「设置 → 保存位置」改成「应用目录」或「自定义目录」，
这时需要长期保存就在工具箱用「导出到相册」。
</details>

<details>
<summary>Aria2 模式下载完成后为什么找不到文件？</summary>

Aria2 模式下文件由 aria2 写到了**它自己所在设备**（NAS / 电脑 / Termux）的磁盘，
手机上不会有副本。请在「设置 → 下载引擎」里确认「落盘目录」，
或直接去那台设备上查看。想要自动合并并进手机相册，请使用内置下载器。
</details>

<details>
<summary>测试连接提示连不上 aria2？</summary>

依次检查：① aria2 是否已用 `--enable-rpc` 启动；② 是否加了 `--rpc-listen-all=true`；
③ 地址写的是否为 `http://<设备IP>:6800/jsonrpc`（本机同一台手机用 `127.0.0.1`）；
④ 若设置了 `--rpc-secret`，需要在「RPC 密钥」里填一致的字符串；
⑤ 电脑 / NAS 的防火墙是否放行 6800 端口。
</details>

<details>
<summary>APK 为什么有 63 MB？</summary>

FFmpeg 全功能库在 arm64-v8a 下约 42 MB（`libavcodec.so` 就占 21 MB）。
如果不需要 H.264 / H.265 编码与 MP3 编码，可把依赖换成同系列的 `_min` 变体大幅瘦身，
但会失去部分格式转换能力。
</details>

<details>
<summary>下载 1080P+ / 4K 失败或只有低清晰度？</summary>

高清与会员内容需要在「我的 - 登录」中扫码或粘贴 Cookie 登录对应账号；
未登录时 B 站 `playurl` 只返回低清晰度，接口也可能返回 `-101`（未登录）。
</details>

<details>
<summary>任务显示「封装失败，已保留原始文件」怎么办？</summary>

说明该设备芯片不支持当前编码的 MP4 封装（多见于 AV1 / HEVC）。
可在「工具」页对已完成的任务点「重新合并」，
或点「格式转换（FFmpeg）」转成 H.264 后使用。
</details>

<details>
<summary>为什么只有 arm64-v8a？</summary>

Flutter 引擎产物按架构分发，只保留 arm64-v8a 可以显著减小 APK 体积；
目前 2017 年后的 Android 设备基本都是 arm64。
</details>

<details>
<summary>为什么没有「去水印」功能？</summary>

去水印需要逐帧图像处理流水线，资源开销与失败率都很高，
当前版本先保证解析、下载、封装与格式转换的稳定性；欢迎 PR 补充。
</details>

---

## 🤝 贡献与反馈

- **提 Issue**：<https://github.com/MokoKing666/DownKyi-Android/issues>
- **提 PR**：欢迎补充去水印、更多格式转换、Aria2 本地二进制集成等能力
- **联系作者**：MokoKing666 · 672627254@qq.com

提交代码前建议先自检一遍：

```bash
flutter analyze                                          # 当前为 0 issue
flutter build apk --release --target-platform android-arm64
```

> ⚠️ 本工程路径**不能包含中文**：AGP 会报 `non-ASCII characters`，
> Dart 分析器也会因为 LSP 通道 URI 编码问题直接崩溃。请放在纯英文路径下开发。

---

## 🙏 致谢

- 功能参考与图标来源：[**crazysmile-PhD/downkyicore**](https://github.com/crazysmile-PhD/downkyicore)
  —— 哔哩下载姬跨平台版（Avalonia / .NET），本项目是它在 Android 上的移植实现，
  应用图标取自该仓库 `script/pupnet/icons/logo.*.png`。
- 概念来源：**哔哩下载姬（Windows 版）**，跨平台版即基于其功能与交互重写。
- UI 组件：[**Tencent/tdesign-flutter**](https://github.com/Tencent/tdesign-flutter)（TDesign 官方 Flutter 组件库，MIT）
- 媒体处理：[**sk3llo/ffmpeg_kit_flutter**](https://github.com/sk3llo/ffmpeg_kit_flutter)
  （`ffmpeg_kit_flutter_new`，原 `ffmpeg-kit` 的社区维护分支，FFmpeg 8.x）
- 下载引擎：[**aria2**](https://github.com/aria2/aria2)（JSON-RPC 客户端集成）
- 其它依赖：`provider`、`sqflite`、`shared_preferences`、`path_provider`、`crypto`、`qr_flutter` 等，
  版权归各自作者所有，详见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

---

## 📜 开源声明

本项目基于 **[GPL-3.0](LICENSE)** 许可证开源，与所参考的上游项目保持一致。

Copyright (C) 2026 **MokoKing666** · 672627254@qq.com

由于本项目在功能实现与图标资源上参考了 GPL-3.0 协议的
[downkyicore](https://github.com/crazysmile-PhD/downkyicore)，
并且集成的 `ffmpeg_kit_flutter_new` 为 **full-gpl** 变体
（含 x264、x265、xvidcore、vid.stab 等 GPL 组件），
依据 GPL-3.0 的传染性要求，本项目同样以 **GPL-3.0** 发布：

- 你可以自由使用、修改、分发本项目；
- 分发（包括修改后分发、二次开发上架）时必须**保留原作者的版权声明**、
  **继续以 GPL-3.0 开源**，并提供完整对应源码；
- 本项目的名称、图标版权归原作者所有，不得用于误导他人认为这是原作者官方发布。

---

## ⚠️ 免责声明

1. 本软件只提供视频解析，不提供资源上传或服务器存储功能。
2. 本软件仅解析来自 B 站的内容；默认下载流程不重新编码（无损封装）；
   仅在你主动使用「格式转换」时才会转码。
3. 解析内容的版权归原作者所有，内容提供者与上传者应承担相应责任。
4. 所有内容仅供学习交流；未经授权不得用于其他用途，请支持原始发布者与原创内容。
5. 因使用本软件产生的版权问题，软件作者概不负责。

<div align="center">

**如果这个项目对你有帮助，欢迎 Star ⭐**

</div>
