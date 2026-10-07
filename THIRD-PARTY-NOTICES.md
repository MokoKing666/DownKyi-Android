# 第三方组件声明 / Third-Party Notices

本项目为「哔哩哔哩下载姬 Android 版」，代码以 **GPL-3.0** 开源。
下列组件/资源由第三方提供，版权归各自作者所有。

## 一、参考项目与资源

| 名称 | 作者 | 许可证 | 使用方式 |
|---|---|---|---|
| [downkyicore](https://github.com/crazysmile-PhD/downkyicore)（哔哩下载姬跨平台版） | crazysmile-PhD | GPL-3.0 | **功能实现参考**；应用图标取自其 `script/pupnet/icons/logo.*.png` |
| 哔哩下载姬（Windows 版） | 原项目作者 | GPL-3.0 | 项目概念与交互来源（downkyicore 即基于其重写的跨平台版本） |
| [tdesign-flutter](https://github.com/Tencent/tdesign-flutter) | Tencent TDesign | MIT | UI 组件库与 TDesign 设计令牌 |

## 二、Dart / Flutter 依赖

| 包名 | 用途 | 许可证 |
|---|---|---|
| `provider` | 状态管理 | MIT |
| `sqflite` | 本地 SQLite（下载任务持久化） | BSD-2-Clause |
| `shared_preferences` | 设置存储 | BSD-3-Clause |
| `path_provider` | 应用目录获取 | BSD-3-Clause |
| `crypto` | WBI 签名所需的 MD5 | BSD-3-Clause |
| `qr_flutter` | 登录二维码渲染 | BSD-3-Clause |
| `tdesign_flutter` | TDesign 组件库 | MIT |
| `tdesign_flutter_adaptation` | 组件库版本适配层 | MIT |
| `ffmpeg_kit_flutter_new` | 格式转换 / 转码 / 提取音频 / 生成 GIF | LGPL-3.0（插件本体）+ **GPL-3.0**（内置 x264 / x265 / xvidcore / vid.stab 等 GPL 编解码器） |
| `ffmpeg_kit_flutter_platform_interface` | 上述插件的平台接口层 | LGPL-3.0 |
| `easy_refresh` / `flutter_slidable` / `flutter_swiper_null_safety` / `image_picker` 等 | 由 `tdesign_flutter` 传递引入 | 各自开源许可证 |

## 三、Android / 系统组件

| 组件 | 用途 | 许可证 |
|---|---|---|
| `androidx.core` (FileProvider) | 打开 / 分享已下载文件 | Apache-2.0 |
| `androidx.datastore`（经 `shared_preferences` 传递引入） | 设置存储底层实现 | Apache-2.0 |
| Flutter Engine | 跨平台运行时 | BSD-3-Clause |
| Android MediaMuxer / MediaExtractor | m4s 音视频无损重新封装 | Android SDK（Apache-2.0） |
| Android MediaStore | 保存到系统相册（视频 / 图片 / 下载） | Android SDK（Apache-2.0） |
| [FFmpeg](https://ffmpeg.org) | 格式转换内核（经 `ffmpeg_kit_flutter_new` 集成） | LGPL-2.1+，启用 GPL 组件时整体为 **GPL-3.0** |

## 四、外部工具

| 名称 | 用途 | 许可证 |
|---|---|---|
| [aria2](https://github.com/aria2/aria2) | 可选下载引擎（本 App 仅通过 JSON-RPC 客户端调用，**不打包 aria2 二进制**） | GPL-2.0-or-later |

> 本 App **不包含** aria2 的任何代码或二进制：用户需自行在 NAS / 电脑 / Termux 上运行 aria2c，
> App 只作为 JSON-RPC 客户端下发任务并轮询进度。

## 五、说明

- 音视频**合并**（下载后的 `video.m4s` + `audio.m4s` → `mp4`）由系统 `MediaMuxer` 完成，**不转码**；
  集成 FFmpeg 是为了**格式转换**（转封装、提取音频、GIF、压缩、H.264 ↔ H.265 互转）。
- 由于 `ffmpeg_kit_flutter_new` 为 full-gpl 变体（含 GPL 编解码器），
  本项目整体以 **GPL-3.0** 发布，与上游参考项目一致。
- 打包前的构建脚本会修补 `tdesign_flutter` 的 `td_icons.dart`
  （使其兼容 Flutter 3.47+ 的 `final class IconData`），该修补不改动其对外 API 与许可证。
- 若需转载、二次分发，请同时遵守上述各组件的许可证要求。
