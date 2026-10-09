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
| 版本 | v2.3.0（versionCode 27） |
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

### v2.3.0 —— 界面控件统一到 TDesign

把项目里还在「自己画」的控件全部换成官方组件，风格统一、以后只维护一套。

| 原来是 | 现在 |
|---|---|
| 自绘选择芯片（清晰度 / 编码 / 音轨 / 偏好模式） | `TDSelectTag` |
| 自绘小标签（时长角标、画质标签） | `TDTag` |
| 自绘容器 + `TextField`（搜索 / 链接 / Cookie） | `TDSearchBar`、`TDTextarea` |
| `AlertDialog` + `TextField` 弹窗 | `TDAlertDialog`、`TDConfirmDialog` |
| 转圈 / 进度条 | `TDLoading`、`TDProgress` |
| 自绘点击行（工具条目、缓存分组、主题外观、勾选行） | `TDCell` |
| 自绘主题按钮 | `TDButton` |

能看出来的变化：**勾选框统一成圆形**（此前自绘的是圆角方块，两种样式并存）；
加载动画换成 TDesign 的转圈；弹窗的圆角、按钮、遮罩都跟着组件库走。

**仍然自绘的两处**（包内确实没有对应组件，已确认）：

- 分段控件（「进行中 / 已完成」）——0.2.7 的分段器实现在包里不存在；
- 少数弹层的骨架，下一步再迁到 `TDPopupBottom*Panel`。

### v2.2.1 —— 修复勾选框在暗色模式下多出一块方框

勾选框（搜索、收藏夹、订阅、视频分 P、清理缓存这些地方）在暗色模式下，
圆圈外面会多出一块方形色块，而圆圈本身反而几乎看不见。

两个原因：

- 组件会给勾选框自己垫一块**卡片底色**，一旦它不在卡片上，这块底色就露出来；
- 它的「未选中描边色」被我们映射成了分隔线那种很浅的颜色，
  在深色背景上几乎看不到圆圈，于是只剩下那块方框。

修复：勾选框底色改为透明、未选中描边改用正常的对比度。

顺便把之前**自绘**的勾选框换回了 TDesign 官方组件——那次自绘是过度反应：
官方组件本来就支持传底色，当时没发现，结果页面上同时存在两种样式的勾选框
（自绘的圆角方块和官方的圆圈）。现在全app统一用官方组件。

### v2.2.0 —— 下载与恢复更稳

**App 被杀 / 重启后，任务能正确接上**

之前 App 重启会把所有「下载中」的任务一律标成暂停，而且恢复逻辑实际上从没生效；
更糟的是它会把分片进度清空，导致大文件从头重下。现在：

- 内置下载器**保留已下载的分片**，从断点继续；
- Aria2 任务先问远端真实状态再决定接管，不会盲目重新下发；
- Aria2 连不上时任务保持原样，恢复连接后点「继续」即可自动接管。

**Aria2 任务记录更准**

一个任务以前只记一条 gid，而且记的是最后那条流的（视频和音频都下时，视频那条丢了），
重启后分不清状态。现在视频 / 音频 / 直链分别记录，暂停、继续、删除都会同步到远端。
另外用 Aria2 下载时也会一并带上封面、弹幕、字幕——之前只有内置下载器会。

**下载设置不再「串味」**

之前任务排队之后你再改设置（字幕语言、弹幕样式、合并方式、保存位置、下载引擎），
已经在跑的任务也会跟着变——同一个视频里 P1 和 P2 可能下出不一样的字幕。
现在这些选项在任务入队时就固定下来，中途改设置只影响新任务。

**合并失败不再挡住重下**

v2.1.0 的「已下载过」记录有个 bug：即使合并失败（文件其实没生成）也会被记进去，
导致同一个视频再也下载不了。现在只有真正成功的任务才会记入。

**写入标题与封面时更安全**

开启「写入标题与封面」后，处理过程改成先备份再替换，中途出错自动回滚，
不会再出现成品丢失的情况。

**文件名冲突会看磁盘**

以前「清空下载记录但保留文件」之后再下同一个视频，同名文件会被静默覆盖；
现在会自动编号。

**加密存储不可用时会明确提示**

系统密钥库异常时凭据会退回明文存储，现在设置页顶部会显示警告条告诉你这件事。

测试 217 → **232**。

### v2.1.0 —— 参考 BBDownT / BBDownAndroid 的四项补强

对照 [BBDownT](https://github.com/LOVAHE/BBDownT) 与
[BBDownAndroid](https://github.com/xialiag/BBDownAndroid) 做了差距分析，
挑出四个我们有缺口、且低风险可验证的功能。其余如 serve API、TV 登录、
BiliPlus 代理要么体量太大、要么不适合移动端，没有采纳。

**任务启动间隔（防风控，对应 BBDownT `--delay-per-video`）**

批量加入任务时，队列泵以前会在同一瞬间把「解析地址 → 探测 → 建分片」
全部打出去，容易触发 B 站风控（-412），表现是「批量下载总有几个失败」。
现在可以在「设置 - 并发」里把任务启动间隔调成 2 / 5 / 10 秒，
任务会错开启动。默认「不限」，保持旧行为。

**下载归档（对应 BBDownT `--save-archives-to-file`）**

以前「清理已完成任务」之后，同一个视频还能再下一遍——追更场景下
每周订阅检查都会把旧视频重复下载。现在按媒体身份
（BV / 分P / 清晰度 / 编码 / 音轨）记录归档，命中就直接跳过。
归档上限 5000 条、FIFO 淘汰；「设置 - 下载归档」里可以关闭或清除。

**AI 字幕策略（对应 BBDownT 的 AI 字幕选项）**

以前只会「人工优先、AI 兜底」。现在可选：人工优先（默认）/ 不用 AI / 只要 AI。
「不用 AI」适合不想要机翻字幕的人：某语言只有 AI 字幕时视为没有。

**写入标题与封面（对应 BBDownAndroid 的元数据注入）**

合并产物以前只有流没有标签，播放器里显示的是文件名。开启后会在合并完成时
把标题 / UP 主写进容器元数据、封面嵌为 attached_pic（FFmpeg，不重编码）。

> 默认**关闭**：这属于 FFmpeg 重封装，与「合并方式」里的 FFmpeg 选项同属一类
> 兼容性风险（部分机型对杜比视界片源可能不兼容）。任何一步失败都只记日志、
> 保留原成品，绝不会反过来弄坏文件。

**顺带修掉的一个环境问题**

本次开发中发现 `third_party/tdesign_flutter` 的内容与 pub 缓存不一致
（混入了一个只有更新版 Flutter 才有的 `ScrollCacheExtent` API，
导致所有涉及 UI 的测试编译失败）。重新执行 `tools/prepare_tdesign.ps1` 后恢复。
测试 191 → 217。

### v2.0.9 —— 时长单位修复、夜间模式勾选框、更新日志重写

**新增功能**

- **智能选档**：画质优先 / 兼容性优先 / 体积优先 / 速度优先，选完自动配好清晰度、编码与音轨
- **预估体积**：清晰度选项上直接标注「视频 + 音频」的合计大小，方便比较
- **设备解码能力检测**：列出本机支持的编码与画质（AVC / HEVC / AV1 / 10-bit / HDR / 杜比视界），选档时给出兼容性提醒
- **多语言字幕**：可同时下载多种语言，文件名带语言后缀
- **弹幕样式可调**：字号、不透明度、滚动速度、占屏比例、滚动 / 顶部 / 底部开关
- **订阅追更规则**：按关键词、时长筛选要自动下载的内容，并可限制单次数量
- **下载规则模板**：一整套下载参数保存下来反复复用
- **合并方式可选**：系统封装（默认）或 FFmpeg 重封装
- **任务来源标签**：接 NAS / 电脑上的 Aria2 后，能一眼看出任务跑在哪
- **精简包**：可选构建，去掉 FFmpeg 原生库，安装包从 64 MB 降到约 22 MB

**修复**

- 合并后的视频**体积翻倍、播放器打不开**（杜比视界这类单文件多轨片源）
- 合并后**画面卡顿**
- 合并偶尔**误报失败并删掉正常文件**
- 清晰度选项上的**预估体积小了 1000 倍**（显示成 KB）
- 夜间模式下勾选框有**白色方底**
- 观看历史无法获取
- 批量下载的清晰度选项不准确（会列出视频并不支持的档位）、缺少音频选项
- 常用入口排版在宽屏下留出参差空隙
- 状态栏图标不生效
- 进程被系统回收后，任务卡在「下载中」不动
- 封面 / 弹幕 / 字幕失败时仍显示「已完成」
- 同名视频互相覆盖
- 下载地址过期后陷入无意义重试

**改进**

- Cookie 与密钥改用系统密钥库加密存储，运行日志自动脱敏
- 长时间后台下载遇到系统时长限制时主动暂停并说明原因，而不是被系统直接杀掉
- 新增「合并方式」「下载偏好」「字幕语言」「弹幕样式」等设置项
- 首次订阅不再把整页存量内容当成新内容提醒一遍
- 构建流程与持续集成（自动检查格式、静态分析与单元测试）

### v1.7.0

**修复：状态栏图标「改了不变」的真正原因**

上一版把图标资源改名成 `ic_stat_downkyi` 但**依然不生效**。对比两个 APK 的资源表后定位到原因：

```
v1.6.0 :  resource 0x7f070065  drawable/ic_stat_downkyi
v1.5.0 :  resource 0x7f070065  drawable/ic_stat_download    ← 资源 ID 完全相同
```

Android 的 `NotificationManagerService.IconManager` **按「包名 + 资源 ID」缓存通知图标位图**，
而它收到 `ACTION_PACKAGE_REMOVED` 时**会跳过 `EXTRA_REPLACING = true` 的情况**——
也就是**覆盖安装不会清掉这个缓存**。资源改名并不改变 aapt2 分配的 ID
（两者在资源表里处于同一排序位置），所以系统一直拿缓存里的旧箭头位图。

**这条缓存位于 system_server 内存中，重启手机即清**；彻底卸载（而非覆盖安装）同样有效。

图标本身也做了修正：把 logo 渲染到 192px 后做**腐蚀**，把 K 的缝隙从约 0.6px 加宽到约 1.6px。
之前 24px 下缝隙被缩放糊掉，剪影读起来只是一个白三角。

**改进：缓存清理改为「缓存分析」**

原来的确认弹窗只有一句「可释放约 X」，太草率。现在会**扫描工作目录并按文件类型分组**：

| 分组 | 内容 |
|---|---|
| 分段临时文件 | `.partN` —— 多线程分片下载的中间产物 |
| 媒体分片 | `video / audio` 的 `.m4s`，尚未合并 |
| 视频 / 音频成品 | 已合并的 `mp4 / mkv / m4a / mp3` |
| 封面图片 | `jpg / png` 等 |
| 弹幕 / 字幕 | `ass / xml / srt / txt` |
| 其它文件 | 不属于以上分类 |

- 每组显示**文件数量与占用体积**，由用户自己勾选要清理哪些。
- **区分「可清理」与「占用中」**：仍被任务引用的文件（未完成任务的临时分片、
  未导出成品的路径）单独列出并标注原因，**不会被删除**，避免破坏断点续传或丢文件。
- 底部实时显示「已选 N 个文件，将释放 X」。

### v1.6.0

**修复**

- **合并出来的视频卡顿（重要）**：`MediaMuxerHelper` 过去为了保证「时间戳单调递增」，
  把回退的 PTS 强行改写成 `lastWritten + 1`。但 **B 站视频普遍带 B 帧**，
  而 B 帧在解码顺序里的 PTS 本来就是回退的（例如 `I(0) P(3) B(1) B(2)`），
  改写后帧的显示时刻被压平、显示顺序错乱，表现就是「合并出来的视频卡卡的」。
  实际上 **MediaMuxer 从 Android 7.1（API 25 / Nougat MR1）起就支持把 B 帧封装进 MP4**，
  所以 API 25+ 现在原样写入真实 PTS；只有 API 24 才退回单调处理（那里本来也不支持 B 帧）。
  交错顺序也从「比较当前 PTS」改成「比较各轨已读到的最大时间戳」，
  否则 B 帧的 PTS 回退会让交错顺序来回抖动。单帧缓冲从 1MB 提到 4MB
  （1MB 装不下 4K 关键帧，`readSampleData` 会直接抛异常）。
- **状态栏图标改了不生效**：资源名不变时，SystemUI 会**按资源名复用缓存下来的旧图标位图**，
  于是出现「换了图标但通知栏没变」。现在把资源改名为 `ic_stat_downkyi`
  （mdpi ~ xxxhdpi 五套密度），`DownloadService` 与通知插件同步更新。
  另外 v1.4.0 的 Release APK 因为构建脚本没做镜像同步，
  实际打进去的仍是旧的 `ic_stat_download.xml`，也需要一并升级。

**新增**

- **解析 / 下载处可直接选保存位置**：在清晰度、编码、音频、下载内容之外新增「保存位置」，
  可选系统相册 / 应用目录 / 自定义目录，自定义目录支持就地编辑，不用再跳回设置页。
- **可以只下载封面 / 弹幕 / 字幕**：过去会被「请至少选择视频或音频」拦住，
  现在没有媒体流时跳过合并直接收尾，并把附加文件导出到公共目录。
- **清理缓存**：工具箱新增入口，先显示可释放空间，再删除临时分片与残留文件。
  正在下载 / 已暂停的任务分片会保留，**不影响断点续传**，已下载的成品也不会被删。

**改进：附加文件不再「不知道去哪了」**

- 过去导出目录靠 MIME 推断：封面是 `image/jpeg`，被送进 `Pictures/<album>`；
  而弹幕 / 字幕落到 `Downloads/<album>`，用户根本找不到文件。
- 现在目标目录由调用方显式指定：**视频 → `Movies/<album>`，
  封面 / 弹幕 / 字幕 / 单独下载的音轨 → `Download/<album>`**，位置固定可预期。

### v1.5.0

**新增：站内搜索**

- 解析页右上角新增搜索按钮，输入关键词即可在 App 内搜视频，**不用再切到 B 站复制链接**。
- 结果有两种用法：**点整行**直接解析该视频并进入解析结果页（单下载）；
  **勾选后点「下载选中」**走批量链路（含真实清晰度的选项弹窗）。
- 结果复用 `MediaItem` / `BatchResult`，所以「批量下载 + 清晰度弹窗 + cid 补查」
  全是现成链路，没有另写一套下载逻辑。
- 粘贴内容不是链接时（比如只有标题），点「开始解析」会弹窗询问是否用这段文字去搜索。

**接口要点**

- 用 `/x/web-interface/wbi/search/type`（带 `wbi` 前缀的新接口，旧接口已废弃），
  需要 WBI 签名 + `buvid3` Cookie + `.bilibili.com` 下的 Referer。
- 该接口**没有 `page_size` 参数**，每页固定 20 条，翻页只能靠 `page`。
- `-412` 是搜索特有的风控返回（Cookies 校验不足），提示里会引导先登录。
- 标题里的 `<em class="keyword">` 高亮标签会剥掉，`"4:18"` 形式的时长会转成毫秒。

**修复：状态栏图标**

- 状态栏 / 通知栏的小图标过去是**手画的通用下载箭头**，与 App logo 不一致。
  现在直接从 `docs/logo.png` 抽取白色标记生成单色剪影（mdpi ~ xxxhdpi 五套密度），
  内容落在 24dp 画布内的 22dp 安全区。
- 抽取用连通域过滤：logo 里有两个 1 像素的杂点会把包围盒从 277px 撑到 345px，
  按面积阈值过滤后标记才是居中且最大化的（否则会整体偏移并缩小）。

### v1.4.0

**新增：订阅（把「一次性快照」升级为「持久跟踪」）**

- **订阅持久化**：新增独立的订阅库（`downkyi_subscription.db`，与下载任务库分开，
  避免两者的版本号互相牵制）。支持四类：**UP 主投稿 / UP 主合集 / 收藏夹 / 番剧整季**。
  添加入口在解析页「常用入口」最下方，复用现有 `parseLink` 的链接识别，没有另写一套。
- **增量检查**：每次只拉第 1 页，与已发现集合做差，不做全量翻页。
  合集比较特殊——接口默认按发布时间**升序**（第 1 页是最旧的），
  因此给 `seasonArchives` 加了 `newestFirst` 参数，检查时倒序拉才能看到最新内容。
- **主动通知**：发现新内容后发通知，点击直达该订阅的新内容页。
- **周期调度**：WorkManager 周期任务，默认 6 小时，可在设置里调整或关闭。
- **发现即判重**：已发现内容记在 `subscription_seen`，键是 **`bvid + epId`**。
  番剧条目没有 `bvid`（见 `BiliApi.history()` 里 pgc 分支只能写 `bvid: ''`），
  只存 bvid 会让所有番剧记录互相覆盖。
- **自动下载默认关闭**：`auto_download` 默认 0，即「只通知不下载」。
  8K 视频单个动辄数 GB，默认自动下载会迅速吃满存储；开启后走现有 `DownloadManager`，
  依旧受并发数与重试策略约束。
- **首次检查只播种**：第一次检查把当前内容全部记为「已知」但不通知、不下载，
  否则新加订阅会立刻被推送一屏存量内容。

**设计取舍**

- 后台检查跑在 WorkManager 的后台 isolate 里，那是一个**全新的 Dart 环境**：
  `main()` 里建好的对象图都不存在，必须自己重新装配一遍
  （`SettingsStore.load()` 会从 SharedPreferences 恢复 Cookie，登录态可用）。
- 通知改用 `flutter_local_notifications`，而不是复用 App 自建的 MethodChannel：
  后台 isolate 的 `FlutterEngine` 由 workmanager 自己创建，
  **里面没有 MainActivity**——而自建通道正是在 `MainActivity.configureFlutterEngine`
  里注册的，从后台调用会抛 `MissingPluginException`，通知会静默丢失；
  workmanager 也没提供 engine 创建回调来补注册。该插件是随包发布的插件，
  后台 engine 会自动注册它，于是前台与后台能共用一套代码。
- 通知渠道用独立的 `downkyi_subscription`（IMPORTANCE_DEFAULT），
  不复用下载进度那条：那条是 `IMPORTANCE_LOW` 的前台服务渠道，
  **渠道重要性创建后 App 无法修改**，放进去等于没有声音、没有横幅，
  还会和常驻的下载进度条混在一起被误读。
- 因为 `flutter_local_notifications` 的要求，`android/app/build.gradle.kts`
  开启了 **core library desugaring**（`desugar_jdk_libs`）。

**已知限制**

- 周期任务由系统调度，**不保证准时**（可能被推迟甚至跳过），
  因此每次打开 App 还会补做一次检查。
- 追番订阅用 `seasonInfo` 取整季剧集列表比对，暂不支持课程（`cheese`）。
- 单集链接（`ep`）不构成订阅，需要改用整季（`ss`）链接。

### v1.3.1

**修复**

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

**改进**

- 把「解析结果页」的清晰度 / 编码 / 音频 / 下载内容四个分区抽成共享组件
  `DownloadOptionsPanel`，解析结果页与批量下载弹窗共用同一份实现
  （`card` 参数区分卡片样式），两个入口的选项逻辑不会再各自漂移。

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
adb install -r DownKyi-v2.3.0-arm64-v8a.apk
```

> 仓库**不提交 APK 二进制**（`.gitignore` 已排除 `*.apk`），发版请走 GitHub Releases。
> 当前 APK 使用的是 **debug 签名**，可直接安装体验；正式分发请自行生成 release keystore 并配置 `signingConfigs`。

---

## 🚀 从源码构建

### 环境要求

| 组件 | 版本 / 说明 |
|---|---|
| Flutter SDK | **3.47+**（stable）。开发与验证使用 3.49；CI 跟随 stable |
| JDK | 17 或以上（实测 Temurin 21） |
| Android SDK | `platforms;android-36`、`build-tools;36.0.0`、`platform-tools` |
| Gradle / AGP / Kotlin | `9.3.1` / `9.1.0` / `2.4.0`（与 Flutter 模板一致，已写入工程） |

```bash
git clone https://github.com/MokoKing666/DownKyi-Android.git
cd DownKyi-Android

flutter pub get

# ⚠️ 必需：生成修补过的 tdesign_flutter 并写入 pubspec_overrides.yaml
#   （原因见下方「构建注意事项」；脚本内部会再跑一次 pub get 让 override 生效）
pwsh -File tools/prepare_tdesign.ps1

# 只出 arm64-v8a 的 release 包
flutter build apk --release --target-platform android-arm64
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

Windows 用户也可直接使用一键脚本（自动探测 Flutter / JDK / Android SDK，
按需设置环境变量即可覆盖；内含依赖安装、tdesign 准备、构建与产物命名）：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_apk.ps1
```

### 测试与持续集成

工程从 v1.8.1 起带一套不依赖设备与账号的单元测试，CI 会执行与本地完全相同的三条命令：

```bash
dart format --output=none --set-exit-if-changed lib test   # 格式
flutter analyze                                            # 静态分析
flutter test                                               # 单元测试
```

覆盖范围（`test/`）：

| 文件 | 覆盖内容 |
|---|---|
| `wbi_test.dart` | WBI 签名的 mixinKey 重排表（**用官方测试向量做锚点**）、参数排序、非法字符剔除、UTF-8 编码、密钥未就绪 |
| `link_parser_test.dart` | BV / av / b23 短链 / ep / ss / 课程 / 收藏夹 / UP 主 / 合集 / 纯数字 / 未识别 |
| `filename_test.dart` | 非法字符、结尾点号、超长截断、Emoji 与全角、路径穿越防护、同名去重 |
| `task_key_test.dart` | 4K AVC/HEVC/AV1 可并存、不同音轨/字幕/弹幕配置互不冲突 |
| `segment_downloader_test.dart` | 起真实本地 HTTP 服务器，覆盖 206 / 忽略 Range 的 200 / Content-Range 不符 / 416 / 读空闲超时 / 断点续传 / 分片失败 / URL 过期刷新 |

这些测试的价值不在于覆盖率数字，而是它们**能在几分钟内免费复现**「下载损坏但 UI 显示成功」
这类最难复现的问题——之前只能靠用户装上包去撞。

`.github/workflows/`：

- `ci.yml`：push / PR 跑格式 + 分析 + 测试，PR 上额外做一次依赖审查
- `release.yml`：打 `v*` tag（或手动指定 tag）时自动构建 APK、算 SHA256、发 Release，
  说明章节直接从 README 的更新日志里抽取
- `dependabot.yml`：每周检查 pub 依赖、每月检查 Actions 版本

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
   而 Flutter 3.47+ 已把 `IconData` 改为 `final class`（实测 3.49 确认；上游 0.2.7 与
   0.2.8-fix.1 均未修复，修复只出现在预发布的 1.0.0-alpha.1）。
   `tools/prepare_tdesign.ps1` 会从 pub 缓存复制出运行所需的最小集合、改写为直接构造
   `IconData`（保留 `fontFamily/fontPackage`，图标字体照常渲染），落到 `third_party/`，
   并写入 `pubspec_overrides.yaml` 让 pub 指过去。

   > **为什么不再改 pub 缓存**：旧脚本直接改写 `%LOCALAPPDATA%\Pub\Cache\...`，
   > 有三个问题——CI / 换机器 / 缓存被清都要重来；改的是所有工程共享的缓存，会污染别的项目；
   > `flutter pub get` 一旦重下该包，补丁就静默失效。
   > 现在 `third_party/` 与 `pubspec_overrides.yaml` 都在 `.gitignore` 里（仓库不因此膨胀），
   > 同一 pub 版本必然产出同一份代码，pub 缓存也不再被触碰。
   > 代价是 clone 之后需要执行一次本脚本。
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
├── bili/                         B 站专有层：改接口只需动这里
│   ├── bili_api.dart             全部接口：view / playurl / pgc / pugv / nav / 二维码 / 收藏夹 / 合集 / 历史 / 字幕 / 弹幕
│   ├── models.dart               手写 fromJson 的数据模型（不使用代码生成）
│   ├── wbi.dart                  WBI 签名（mixinKey 重排 + md5）
│   ├── link_parser.dart          链接识别（BV/av/ep/ss/收藏夹/合集/短链）
│   └── danmaku_parser.dart       弹幕 protobuf 分片解析
├── core/
│   ├── constants.dart            接口地址、UA、清晰度/编码/引擎/保存位置/转换目标枚举
│   ├── secret_store.dart         敏感数据加密存储门面（KeyStore + 明文迁移 + 失败降级）
│   ├── protobuf_lite.dart        极简 protobuf 读取器（用于弹幕接口）
│   ├── formatter.dart            时长 / 体积 / 速度 / 文件名格式化
│   └── logger.dart               环形日志（写入前自动脱敏，设置页可查看）
├── data/
│   ├── http_client.dart          dart:io HttpClient 封装：Cookie、Referer、WBI 参数
│   ├── download_task.dart        任务模型（分片进度、状态机、aria2 gid、相册导出状态）
│   ├── task_dao.dart             sqflite 任务持久化（version 2，含 aria2 / 导出字段迁移）
│   └── settings_store.dart       SharedPreferences 设置（含主题、引擎、Aria2、保存位置）
├── download/
│   ├── segment_downloader.dart   多线程分片 + 断点续传核心
│   ├── download_manager.dart     双引擎调度 / 合并 / 相册落盘 / 附加资源 / 通知
│   ├── download_session.dart     中断任务恢复 + 前台服务时长预算（Android 15+ 降级）
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

test/
├── wbi_test.dart                      WBI 签名（官方测试向量锚定）
├── link_parser_test.dart              链接识别
├── filename_test.dart                 文件名清洗与去重
├── task_key_test.dart                 任务唯一标识
└── segment_downloader_test.dart       分片下载器（真实本地 HTTP 服务器）

.github/
├── workflows/ci.yml                   格式 + 分析 + 测试 + 依赖审查
├── workflows/release.yml              tag → 构建 APK → SHA256 → Release
└── dependabot.yml                     依赖与 Actions 版本更新

tools/
├── build_apk.ps1                 一键打包（环境变量 + tdesign 准备 + 构建 + 校验）
├── prepare_tdesign.ps1           生成修补过的 tdesign_flutter + pubspec_overrides.yaml
└── publish_release.ps1           本地发布（与 release.yml 二选一）
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
