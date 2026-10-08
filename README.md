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
| 版本 | v2.0.5（versionCode 19） |
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

### v2.0.5 —— 合并回到系统 MediaMuxer（采纳用户判断）

**我把合并默认切回 Android 自带的 MediaMuxer，FFmpeg 只留在工具箱。**

依据是你给的那条最硬的证据：**引入 FFmpeg 合并之前一直是正常的**。
而我这三轮全是在「靠推理改封装」，结果一次比一次糟：

| 版本 | 改动 | 结果 |
|---|---|---|
| v2.0.2 | 合并改用 FFmpeg | 不卡了，但杜比视界掉了、体积翻倍 |
| v2.0.3 | 加 `-map 0:v` + `-strict unofficial` | 杜比标回来了，但**播不了** |
| v2.0.5 | **合并回到 MediaMuxer** | —— |

根子上是：封装是所有功能里**最不该"理论上更好"**的一环。
MediaMuxer 与系统播放器对 MP4 的处理最一致，杜比视界这类带额外元数据的
片源尤其依赖它；FFmpeg 的 `-c copy` 在纸面上更标准，实测却会产出
系统播放器不认的成品。这个代价我付不起。

**新增「合并方式」设置（默认：系统封装）**

- **系统封装（推荐）**：MediaMuxer，默认值，兼容性最好
- **FFmpeg 重封装**：唯一保留 FFmpeg 于合并链路的入口。只在你遇到
  「合并后画面一顿一顿」时切换——那是 MediaMuxer 在部分机型上
  对 B 帧回退 PTS 的处理差异，FFmpeg 能绕开
- 切到 FFmpeg 后若仍失败，会**自动回退** MediaMuxer
- 系统封装模式下**绝不**偷偷调用 FFmpeg：失败就如实报失败

工具箱的「重新合并音视频」同样遵循这个设置。FFmpeg 继续承担它擅长的部分：
格式转换、GIF、压缩、H.264↔H.265、无损截取等。

### v2.0.4 —— 体积预估改为「视频 + 音频」合计

**这是我在 v2.0.0 埋下的误导。**

v2.0.0 起清晰度选项上会标注预估体积，但那个数字**只算了视频轨**。
而合并后的成品必然是「视频 + 音轨」——杜比视界这类片源常配杜比全景声 /
Hi-Res 音轨，一部 30 分钟的视频音轨本身就能到 300 MB 量级。

结果就是：标签显示 387 M，实际文件 700 M，看起来像「合并把文件撑大了」，
但其实是标签少算了一路。现在改为合计，并在数字前加「共」以示区分：

```
1080P 高清 · AVC / H.264 · 共 698 MB
```

顺带说明：v2.0.2 的 `-map 0:v:0 -map 1:a:0` 在数学上**不可能**产出超过两个输入
之和的文件，所以「体积翻倍」不可能来自轨被复制。封装环节现在也会把
「视频 + 音频 -> 成品」三个体积写进运行日志，便于随时核对。

### v2.0.3 —— 修复「杜比视界降级成普通 HDR」与「合并后体积翻倍」

**这两个是同一个根因：v2.0.2 的 `-map` 写窄了。**

v2.0.2 写的是 `-map 0:v:0`（只取第一条视频轨）。而**杜比视界 Profile 7 是
「基础层 BL + 增强层 EL」两条独立的视频轨**——只取第一条，增强层会被丢掉，
表现就是「杜比视界降级成普通 HDR10」。

同时杜比视界的 codec tag（`dvh1` / `dvhe`）在 MP4 里属于**非官方标签**，
FFmpeg 默认会因为 strict 检查拒绝写出，产物被标成普通 `hev1` / `hvc1`，
播放器同样认不出杜比视界。

修复：

```
ffmpeg -y -i video.m4s -i audio.m4s -map 0:v -map 1:a \
       -c copy -strict unofficial -movflags +faststart out.mp4
```

- `-map 0:v` 搬运**全部**视频轨，不再丢增强层；普通视频本来就只有一条轨，无副作用
- `-strict unofficial` 放开非官方标签，`dvh1` / `dvhe` 才能原样写出

**关于体积**：如果你看到的「387.4M → 700多M」是**视频分片 → 合并后成品**的对比，
那需要先分清「视频流本身」和「视频流 + 音轨」。合并后的成品必然是两者之和，
杜比全景声这类音轨在长视频上可以到几百 MB。

为了能一次定位，现在封装完成时会把三个体积写进运行日志：

```
[D][Task] 封装完成：视频 406218342 + 音频 128743920 -> 成品 534962262 字节
```

下次如果还觉得不对，把这一行发出来就能立刻判断是下载环节还是封装环节。

### v2.0.2 —— 修复「合并后画面一顿一顿」

**改用 FFmpeg 做无损重封装，MediaMuxer 退为兜底。**

我先把 v1.6.0 到现在的 `MediaMuxerHelper` 做了逐行 diff 核对：**合并逻辑本身没有回归**
（`lastWritten` 只在 API 24 分支生效，API 25+ 写的就是真实 PTS，两版逐字相同）。
所以问题不在「我改坏了什么」，而在 MediaMuxer 这条路本身：

B 站片源普遍带 B 帧，B 帧在解码顺序里的 PTS 天然回退（I(0) P(3) B(1) B(2)）。
MP4 要表达这种回退必须写 `ctts` 表，而 **MediaMuxer 对非单调时间戳的处理
在各 Android 版本 / 各 OEM 实现上并不一致**，最坏的情况是直接丢掉回退的样本。
表现就是画面一顿一顿的，而**成品的大小、轨道数、时长全都正常**——
极难从产物上判断，这也是它反复出现的原因。

App 里本来就打包了完整 FFmpeg，`-c copy` 会正确生成 `ctts`，不依赖设备实现。
现在自动合并与工具箱的手动合并都优先走 FFmpeg：

```
ffmpeg -y -i video.m4s -i audio.m4s -map 0:v -map 1:a -c copy -movflags +faststart out.mp4
```

- `-c copy` 保证无损，不重新编码
- 显式 `-map` 只取第一条视频轨 + 第一条音频轨，不搬入无关轨道
- `+faststart` 把 moov 前置：起播不用先读完整段，拖进度条也不卡一下
- 精简包（无 FFmpeg）或 FFmpeg 失败时自动回退 MediaMuxer

**已经下好的任务不用重新下载**：原始分片是保留的，直接到
**工具 → 重新合并音视频** 重新跑一次即可，这次走的是 FFmpeg。

### v2.0.1 —— 修复「自动合并与手动合成都失败」

**这是我 v1.8.0 引入的回归，影响所有视频，与你的环境无关。**

v1.8.0 给 MediaMuxer 加了封装后校验（评审第十项），但里面两个检查写成了
「拿不准就判失败」，而失败时调用方会**把刚封装好的成品删掉**：

1. **用 64 KB 缓冲去读第 0 轨（视频轨）的第一个样本。**
   视频轨首帧是 IDR 关键帧，1080p 就轻松超过 100 KB、4K 上 MB，
   `readSampleData` 必然抛 `IllegalArgumentException`，被 catch 吞掉后返回 false。
2. **`durationUs <= 0` 直接判失败。**
   但 `MediaExtractor` 是否给 MP4 轨道填 `KEY_DURATION` 依设备实现而异，
   填不上时恒为 0——把「不知道」当成了「坏了」。

自动合并与工具箱的手动合并走的是同一个 `MediaMuxerHelper.remux`，
所以两条路一起挂。**请升级到 v2.0.1。**

**修复方式：把「拿不准」和「确证坏了」分开。**

保留真正有价值的检查（轨道数、期望的视频/音频轨是否存在——这条能抓到
「只搬第一条视频轨导致音频丢失」），去掉会误判的检查：

- 样本探测改为自适应扩容；并且**「缓冲不够」这个异常本身就算作样本存在的证据**
- 时长只在**确实拿到且为负数**时才怀疑，拿不到不判
- 失败仍然删产物，但因为剩下的都是确证的检查，这个动作重新变得安全

**顺带修掉一个「看不见原因」的问题**

`_merge` 失败时把原因写进了 `task.error`，但后续状态被置为 `completed`，
任务卡片只显示「已完成（未合并）」——你只能看到合并不了，看不到为什么。
现在真实原因会顶到标题行上（例如「封装失败，已保留原始文件，可在工具里重新合并」）。
设置里关掉自动合并、以及只下封面弹幕这两种「未合并」也换成了更明确的文案。

**写校验的教训**：一个「宁可错杀」的校验，配上一个「失败就删文件」的动作，
等于把校验的误判率直接放大了成破坏力。校验只该在能确证时否决。

### v2.0.0 —— 智能下载与媒体工作站

技术评审列出的问题至此**全部处理完毕**。逐项对照见本版末尾的表格。

**智能选档（第 15 项）**

新增「下载偏好」：画质优先 / 兼容性优先 / 体积优先 / 速度优先。
以前用户要自己判断「4K 该配 AVC 还是 AV1」，现在只要说要画质还是要能播：

- **画质优先**：能拿多高拿多高，同档优先 HEVC
- **兼容性优先**：优先 H.264，老电视 / 投影 / 剪辑软件通吃（4K 只有 HEVC/AV1 时自动退到有 AVC 的最高档）
- **体积优先**：不轻易降画质，在同档里挑体积最小的编码
- **速度优先**：允许降画质换速度

选完模式会**立刻**把清晰度 / 编码 / 音轨都选好，而不是只存一个开关。

**预估文件体积（第 16 项）**

清晰度选项直接标上体积：「1080P 高清 · AVC / H.264 · 1.8 GB」。
DASH 是按需取流，播放地址里没有「总长」字段，所以是按码率 × 时长估算，
误差通常在 5% 以内——够用来比较「1.8 GB 还是 850 MB」，别当精确磁盘占用。

**硬件解码能力检测（第 17 项）**

用 `MediaCodecList` 探测本机的 AVC / HEVC / AV1 / 10-bit / HDR / 杜比视界支持，
在选项面板里列出，并给出现选项的兼容性警告：

```
✓ AVC / H.264   ✓ HEVC / H.265   ✗ AV1   ✓ 10-bit   ✗ HDR   ✗ 杜比视界
⚠ 本机未上报 HDR 支持，色彩映射可能不正常
```

**只提醒、不拦截**——部分 ROM 的 profileLevels 上报不全，硬拦会误伤本来能播的设备。

**下载规则模板（第 18 项）**

一次配好、反复复用。新增 `DownloadRule`，可保存清晰度 / 编码 / 音轨 / 下载内容 /
弹幕格式 / 字幕语言 / 命名模板，内置「高画质归档」与「兼容优先」两套。

**订阅追更规则（第 19 项）**

追更是无人值守的，没有筛选的话，UP 主发一条 15 秒转发、一期 5 小时直播回放，
都会在半夜自动占满存储。新增：

- 关键词包含 / 排除
- 时长下限 / 上限
- 单次检查最多自动下载几个（防止第一次订阅停更很久的 UP 时一次建几十个任务）

**多语言字幕（第 21 项）**

以前是写死的「挑第一条含 zh 的」，想要中英双语做不到。现在可按语言多选，
文件按语言命名：`video.zh-Hans.srt`、`video.en-US.srt`。

关键是**先归一化再匹配**：B 站对同一件事有多种写法（简体用过 `zh-CN` 与 `zh-Hans`，
AI 字幕是 `ai-zh`，繁体有 `zh-Hant` / `zh-TW` / `zh-HK`），直接字符串比较会漏掉一大半，
表现成「明明有字幕却说没有」。同一语言下人工字幕优先于 AI 字幕。

**弹幕样式可调 + 工具箱参数（第 22、23 项）**

ASS 样式从写死改为可调：字号、不透明度、滚动时长、占屏比例、滚动/顶部/底部开关。
以前 40 号字在手机偏小、铺满整屏在 4K 片源里又没法看，现在都能调。

新增 `FfmpegOps` 参数构造（全部纯函数、可单测）：无损截取、调整音量 / 帧率 / 分辨率、
提取音频 / 字幕 / 封面。其中**无损截取**全程 `-c copy`，几乎不花时间——
把一段直播回放裁成片段是几秒的事。

**任务来源标签（第 20 项）**

接上 NAS / 电脑的 aria2 后，列表里会同时有「本机在下」和「远程在下」，
速度与进度的含义完全不同。现在非本机任务会带一个来源标签。

> 这里刻意**不新增数据库列**：aria2 任务一定有 `aria2Gid`，is-local 由 RPC 地址判断即可。
> 加一列要同步维护 `task_dao` 版本迁移与 `toMap/fromMap` 三处，收益不成比例。

**精简包（第 27 项）**

APK 体积几乎全被 FFmpeg 吃掉（arm64-v8a 下约 42 MB / 总体 64 MB）。
新增可选开关（`tools/build_lite.ps1`），排除 FFmpeg 原生库，下载与直接播放不受影响。

> **为什么不做成 productFlavors**：一旦声明 flavor，`flutter build apk` 就必须带 `--flavor`，
> 现有 CI、`tools/build_apk.ps1`、`tools/publish_release.ps1` 以及所有用户的构建命令
> 会立刻失效。这个代价不该由一个 P3 优化来付。因此做成显式开关，
> **不传该属性时构建行为与以前完全一致**。

**新增测试：121 → 183**

`test/download_rules_test.dart` 覆盖智能选档的四个模式、体积换算、订阅筛选
（关键词/时长/截断）、规则 JSON 往返、字幕语言归一化与选择、弹幕样式换算、
FFmpeg 参数顺序、任务来源判定。

其中几条是「错了也不会报错、只会静默出错」的：`-ss` 放在 `-i` 之后就退化成
重新编码（本来几秒变几十分钟）、`scale` 高度用 `-1` 会因奇数高度直接编码失败、
弹幕 alpha 算反会让弹幕全透明。

---

#### 技术评审 26 项对照

| # | 项 | 落地版本 |
|---|---|---|
| 2.1 | HTTP Range 严格验证 | v1.8.0 |
| 三 | Concat 完整性检查 | v1.8.0 |
| 四 | 下载 URL 失效自动刷新 | v1.8.0（v1.8.1 补充探测阶段也刷新） |
| 五 | Task Key 唯一性 | v1.8.0 |
| 六 | 文件名冲突处理 | v1.8.0 |
| 七 | 读空闲超时 / Stall Detection | v1.8.0 |
| 八 | HTTP 重试策略与错误分类 | v1.8.0 |
| 九 | 附加资源独立状态 | v1.8.0 |
| 十 | MediaMuxer 输出验证 | v1.8.0 |
| 十一 | MediaMuxer Buffer 动态扩展 | v1.8.0 |
| 十二 | Android 15/16 后台下载 | v1.8.2（优雅降级，见下） |
| 十三 | Cookie / Secret 安全存储 | v1.8.2 |
| 十四 | Bilibili API 解耦 | v1.8.2（部分，见下） |
| 十五 | 智能下载模式 | **v2.0.0** |
| 十六 | 预计文件大小 | **v2.0.0** |
| 十七 | 硬件兼容性检测 | **v2.0.0** |
| 十八 | 下载规则模板 | **v2.0.0** |
| 十九 | 订阅追更规则 | **v2.0.0** |
| 二十 | Aria2/NAS 模式升级 | **v2.0.0**（任务来源标签） |
| 二十一 | 字幕系统升级 | **v2.0.0** |
| 二十二 | 弹幕系统升级 | **v2.0.0**（样式可调；烧录未做） |
| 二十三 | FFmpeg 视频工具箱 | **v2.0.0**（参数层；UI 只接了现有入口） |
| 二十四 | 完整测试体系 | v1.8.1 起，v2.0.0 补齐 |
| 二十五 | GitHub Actions CI | v1.8.1 |
| 二十六 | TDesign patch 问题 | v1.8.1 |
| 二十七 | APK 体积优化 | **v2.0.0**（可选精简包） |

#### 三处需要如实说明的地方

**1. 第 12 项（Android 15/16 后台）没有「解决」，只是「降级得体面」。**
Android 15 起 `dataSync` 前台服务有 24 小时滚动窗口内累计约 6 小时的运行时上限，
这是**平台约束**，靠 manifest 绕不开。Google 给出的方向是改用
User-Initiated Data Transfer（把下载执行搬进 JobService），那是独立的一次重构。
本版做到的是：在额度内累计、接近上限主动暂停并写明原因，
而不是等系统在随机时刻杀进程。任务断点续传，不丢已下载分片。

**2. 第 14 项（API 解耦）只完成了一半。**
`lib/bili/` 已经独立出来，媒体层与分片下载器完全不依赖 B 站返回结构。
但 `DownloadManager` 仍会自己调 `playUrl` 拿地址，而不是由上层注入——
拆开需要改动 `_execute()` 主流程（含 aria2 分支），没有真机可验证的情况下风险不小。

**3. 第 22 项的「弹幕烧录」、第 23 项的工具箱 UI 没有全部接上。**
弹幕烧录（把 ASS 压进视频画面）与截取/音量的界面入口仍是待办；
`FfmpegOps` 的参数层已经写好并测过，接 UI 是纯体力活。

### v1.8.2 —— Android 现代化 · 安全存储 · 分层（技术评审第二阶段·二）

**安全：Cookie / 密钥改为系统密钥库加密（评审第 13 项）**

这一项修的不是稳定性，是**泄露面**。此前 `SESSDATA` / `bili_jct` / `DedeUserID` /
aria2 RPC 密钥和普通设置一起明文躺在 SharedPreferences 里。这两类东西性质完全不同：
设置被看到只是隐私问题，而 **`SESSDATA` 被拿到等于账号被拿走**——它可以直接调用
任意已登录接口，不需要密码、不需要二次验证。

现在改由 **AndroidKeyStore** 保管密钥、AES/GCM 加密后落盘（`SecureStore.kt`）：

- 密钥永不出 keystore，即使 root 也导不出，应用只能请求它做加解密
- 每次加密生成新 IV（GCM 的硬要求，复用 IV 会直接毁掉安全性）
- **旧版明文自动迁移**：升级后首次读取时把明文加密回写，再删掉残留——
  否则所有已登录用户会莫名其妙掉登录
- **失败降级**：加密存储不可用时退回明文并记日志。安全性与可用性之间明确选可用性，
  让用户因为 keystore 异常而掉登录比明文存着更糟

顺带做了**日志脱敏**（`AppLog.redact`）：「设置 - 运行日志」是给用户排查问题用的，
而用户遇到问题的第一反应就是把日志贴进 issue。现在 `SESSDATA` / `bili_jct` /
`aria2Secret` / `access_token` 等字段的值只保留前 4 位。

**Android 15/16 后台限制：从「被系统杀」改为「优雅降级」（评审第 12 项）**

Android 15 起 `dataSync` 前台服务有 **24 小时滚动窗口内累计约 6 小时**的运行时上限，
超额后系统直接停服务并杀进程。对「晚上挂机下 4K」这种场景是致命的：早上起来只下了一半，
而且没有任何解释。

Google 给出的长期方向是改用 User-Initiated Data Transfer（把下载执行搬进 JobService），
那是独立的一次重构。**这一版先把「被随机杀」变成「主动收手」**：

- 新增 `ForegroundBudget`：在额度内累计前台服务运行时长，按 24 小时滚动窗口计算，
  空闲一段时间自动重置
- 接近上限（80%）记日志，达到上限**主动暂停全部任务并写明原因**，
  而不是等系统在随机时刻杀进程
- 任务本身断点续传，暂停后重新开始即可，不丢已下载的分片

**进程被杀后的任务恢复**

数据库里会残留 `status = running / merging` 的任务，但其实没有任何下载在跑——
UI 会一直显示「下载中」却永远不动，用户只能删掉重建。
现在启动时统一重新入队（`DownloadSession.recoverInterrupted`），分片文件还在，
会接着断点续传。

**分层：B 站相关内容收进 `lib/bili/`（评审第 14 项）**

```
lib/bili/       B 站专有的一切——接口、WBI 签名、链接识别、数据模型、弹幕 protobuf
                （B 站改接口只需动这里）
lib/data/       通用持久化与传输——HTTP 客户端、任务/订阅数据库、设置
lib/download/   可靠下载与媒体处理，只接受 URL 与文件路径
lib/ui/         界面
```

`models.dart` / `bili_api.dart` / `wbi.dart` / `link_parser.dart` / `danmaku_parser.dart`
已归入 `lib/bili/`。

> 需要说明的是：分层只完成了一半。`DownloadManager` 目前仍会自己调 `playUrl` 拿地址，
> 而不是由上层注入——把这一步拆开需要改动 `_execute()` 的主流程（含 aria2 分支），
> 风险不小且没有真机可验证，留到下一版做。媒体层与分片下载器已经完全不依赖
> B 站返回结构了。

**新增测试**

`test/security_test.dart`（日志脱敏 + 加密存储迁移/降级，含平台通道 mock）、
`test/session_budget_test.dart`（时长预算的窗口滚动、阈值、空闲重置）。
用例总数 91 → **121**。

### v1.8.1 —— 工程质量与可重复构建（技术评审第二阶段·一）

这一版对用户不可见，全部是工程地基。之所以先做它，是因为评审列的其余问题
（Android 15/16 后台、Keystore、智能下载、远程下载）都需要一个**能自动验证**的底座——
否则每次改动都只能靠装上真机去撞，而前几版已经反复证明这条路代价很高
（状态栏图标连续两版都没修对，根因就是没有可验证的反馈回路）。

**新增：单元测试体系（评审第 24 项）**

工程此前**一个测试都没有**。现在 `test/` 下有 5 个文件、**91 个用例**，
全部不依赖设备与登录态，`flutter test` 秒级跑完：

| 文件 | 覆盖 |
|---|---|
| `wbi_test.dart` | mixinKey 重排表、参数排序、非法字符剔除、UTF-8 编码、密钥未就绪 |
| `link_parser_test.dart` | BV / av / b23 / ep / ss / 课程 / 收藏夹 / UP 主 / 合集 / 纯数字 / 未识别 |
| `filename_test.dart` | 非法字符、结尾点号、超长截断、Emoji、路径穿越防护、同名去重 |
| `task_key_test.dart` | 4K AVC/HEVC/AV1 可并存，不同音轨 / 字幕 / 弹幕配置互不冲突 |
| `segment_downloader_test.dart` | 真实本地 HTTP 服务器覆盖 206 / 忽略 Range 的 200 / Content-Range 不符 / 416 / 读空闲超时 / 断点续传 / 分片失败 / URL 过期刷新 |

两个刻意的设计：

- **WBI 用外部锚点**：mixinKey 的期望值取自官方测试向量
  （`img_key` / `sub_key` → `ea1db124af3c7062474693fa704f4ff8`），
  而不是拿本实现的输出自证。那张 64 项重排表错一个数字，所有 wbi 接口都会静默返回 -403。
- **分片下载器起真实本地 HTTP 服务器**，不用 mock Response。文档的验收标准全都和
  HTTP 语义本身有关（206 的 Content-Range、服务器忽略 Range 却返回 200、416、连接半途静默停滞），
  用假对象测的其实是「我以为的 HTTP」。

**写测试时查出来的三个真问题**

1. **读空闲超时抛出的是裸 `TimeoutException`**：`Stream.timeout` 的异常直接冒泡到任务层，
   用户会看到 `TimeoutException after 0:00:00.4: No stream event`，
   而文档要求的提示是「下载停滞，正在重新连接」。现在统一归一化为可读的 `ApiException`。
2. **探测阶段不刷新 URL**：刷新逻辑只写在分片下载里。若播放地址在
   「解析出地址 → 真正开始下载」之间就失效（订阅的后台任务、用户点了下载又等很久），
   `_probe` 会直接抛错，刷新逻辑永远走不到。现在探测阶段同样会刷新。
3. **tdesign 补丁只替换构造函数、不替换类型标注**：不同小版本的声明写法不一致
   （`static const IconData x = _TDIconsData(...)` 与 `static const _TDIconsData x = ...`），
   后者会残留并导致编译失败。现在有兜底替换 + 残留断言。

**改进：构建可重复（评审第 26 项）**

旧脚本直接改写 `%LOCALAPPDATA%\Pub\Cache\...\td_icons.dart`，三个问题：
CI / 换机器 / 缓存被清都要重来；改的是所有工程共享的缓存，会污染别的项目；
`flutter pub get` 一旦重下该包，补丁就静默失效。

现在 `tools/prepare_tdesign.ps1` 从 pub 缓存复制出运行所需的最小集合
（1.85 MB / 163 文件，不含 `example` 与 `demo_tool`），在副本上打补丁，落到 `third_party/`，
再写入 `pubspec_overrides.yaml` 让 pub 指过去。两者都在 `.gitignore` 里，**仓库零膨胀**，
pub 缓存也不再被触碰。脚本已做跨平台处理（Linux 的 `~/.pub-cache`、`PUB_CACHE` 覆盖、
正斜杠路径），并自带两次 `pub get` 的顺序编排。

**新增：GitHub Actions CI（评审第 25 项）**

- `ci.yml`：push / PR 执行 `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test`，
  PR 上额外跑依赖审查
- `release.yml`：打 `v*` tag（或手动指定 tag）自动构建 APK、计算 SHA256、发 Release，
  说明章节直接从 README 的更新日志里抽取
- `dependabot.yml`：每周检查 pub 依赖、每月检查 Actions 版本

为了让格式检查能落地，本版对 `lib/` 与 `test/` 做了一次**全量 `dart format`**（45 文件变更，
纯机械调整；已确认格式化后分析与测试全部通过）。

**本批未做（第三、四批）**

- 评审第 12 项 Android 15/16 后台下载重构（User-Initiated Data Transfer / Native Scheduler）
- 评审第 13 项 Cookie / Secret 迁移 Android Keystore
- 评审第 14 项 Bilibili API 分层解耦
- 评审第 15~23、27 项（智能下载、预计大小、硬件兼容、下载规则、订阅追更、
  Aria2/NAS、字幕与弹幕升级、FFmpeg 工具箱、Lite/Full 分包）

### v1.8.0 —— 稳定性专项（技术评审第一阶段）

这一版不加新功能，只解决「文件损坏但 UI 显示成功」这一类问题。

**P0 · HTTP Range 严格校验**（`segment_downloader.dart`）

过去 `206` 与 `200` 都被无条件接受。问题在于：**服务端忽略 Range 返回的 200 是完整文件**，
把它追加进 `.partN` 会直接产出损坏文件。现在：

- `206`：必须带 `Content-Range`，且起点等于请求起点、终点不越界、总长与探测一致，否则报错；
- `200`：只有「单分片、从 0 开始、分片长度等于总长」才接受，其余判为 Range 无效；
- `416`：核对本地分片是否其实已完整，完整则跳过，否则删除重下。

**P0 · 拼接完整性校验**

过去 `_concat` 对缺失分片是 `if (!await file.exists()) continue;`——
`part0 + part1 + part3` 也会被当成成功文件交付。现在拼接前逐片核对存在性与长度，
任何一片不符立即中止；拼接后再核对输出总长，不一致就删掉损坏产物并抛错。

**P0 · URL 过期自动刷新**

B 站播放地址有有效期，过去 403 后只会拿同一个失效地址重试 6 次然后失败。现在：

- 状态码分类：`403/404/410` → 刷新 URL，`408/429/5xx` → 退避重试，其余 → 立即失败；
- 刷新时**保留已完成的 part** 从断点继续——「下到 18 GB 地址过期」不会退回去重下；
- 刷新有并发保护与次数上限（3 次），避免多分片同时打爆接口。

**P0 · 任务唯一标识修复**

旧 key 只有 `bvid_cid_quality_flags`，于是**同清晰度不同编码会被判成同一个任务互相顶掉**
（4K AVC 与 4K HEVC 无法共存）。现在把决定文件内容的参数全部纳入，
用 SHA-256 压成 32 位定长串：`bvid | cid | quality | codec | audioId | flags | 弹幕格式 | 字幕语言`。

> ⚠️ 一次性影响：旧版本创建的同内容任务 key 与新格式不同，会被视为两条任务。

**P1 · Read Idle Timeout 与退避策略**

原来只有连接超时（20s），「连接成功 → 服务端停止发送数据 → TCP 不断开」会无限挂住。
现在加了等待响应头 30 秒超时、**连续 30 秒无数据即断开重连**。
固定 `400ms × attempts` 的退避改成指数退避（0.5s→…→30s 封顶）+ 0~500ms 抖动，
并给单分片收到的数据加了「不得超过请求范围」的校验。

**P1 · 附加资源独立状态**

封面 / 弹幕 / 字幕失败过去只写日志，任务照样显示「已完成」。现在失败项记入
`task.extras_error`（数据库 v3 迁移），任务卡片显示为
**「已完成，但 弹幕 未成功 · 128 MB」**。

> 评审建议新增 `COMPLETED_WITH_WARNINGS` 状态。我没有新增枚举值，而是用
> `completedWithWarnings` 派生态——`TaskStatus` 在 12 处被引用（已完成列表、
> 完成计数、缓存保护规则等），新增枚举需同步改动全部调用点，
> 漏一处就会出现任务不显示「已完成」或缓存误删。语义相同，风险低得多。

**P1 · MediaMuxer 输出校验与缓冲扩容**（Kotlin）

- 封装后做轻量校验：轨道存在、期望的视频/音频轨存在、`Duration > 0`、
  能读出至少一个样本、文件长度 > 1KB。失败则删掉产物返回 false，
  上层保留原始分片并提示「重新合并」——`MediaMuxer` 返回成功 ≠ 文件能播。
- 单帧缓冲从固定 4MB 改为**动态扩容**：捕获 `readSampleData` 的
  `IllegalArgumentException` 后按倍扩容重试同一帧（4MB → 64MB 封顶），
  兼顾普通视频的内存占用与 8K 关键帧的兼容性。

**P1 · 文件名冲突处理**

默认模板只有 `{title}`，批量下载时同名视频会写进同一个文件互相覆盖。
现在在已有任务里查重并追加 `(1)`、`(2)`；模板新增 `{bvid}` / `{cid}` / `{codec}` / `{date}`。

> 评审建议的 `{owner}/{title} [{bvid}]` 归档格式需要子目录支持，
> 而 `sanitizeFileName` 会把 `/` 替换掉，属于单独一项改动，留到下一阶段。

**本次未做（第一阶段剩余部分 / 第二阶段）**

- Android 15/16 后台下载重构（User-Initiated Data Transfer / Native Scheduler）
- Cookie / Secret 迁移到 Android Keystore
- 自动化测试体系与 GitHub Actions CI

这几项涉及原生调度器与密钥库，改动面比上面大一个量级，
不适合和稳定性修复混在同一次提交里。

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
adb install -r DownKyi-v2.0.5-arm64-v8a.apk
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
