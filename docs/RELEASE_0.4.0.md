# Off Road Rider 0.4.0

macOS 开发测试版，包含最近完成的车型、驾驶舱、地图与声音更新。

## 内容

- 十台车：保留 Scout、Ridge、Ranger Pickup、Atlas；加入并细化 Wrangler、Unimog U5023、F-150 Raptor、Hilux、EQ246、WC-62 参考车型。驾驶舱布局与方向盘修复见 [逐车记录](COCKPIT_REVIEW.md)。
- 三张 1,440 × 1,200 米地图：Old Frontier、Salt Coast、Alpine Reach，包含岩石攀爬、森林、草原、山地、沙漠、戈壁、泥地、沼泽、浅水、海岸、废墟、雪山与冰湖。
- 十车型各两层引擎声和十二类地面行驶声，按油门、声效转速与实际轮胎接触材质响应，详情见 [驾驶声音](DRIVING_AUDIO.md)。
- 新增原创背景曲 **Open Tracks**：80 BPM、4/4、32 小节、96 秒立体声循环；拨弦、柔和电钢琴式音色、铺底和弦、低音与轻打击乐，四个段落逐步变化。独立音乐音量位于 Esc 菜单，设为 0 可静音；切车、换地图和菜单保持连续播放。
- 第一人称、跟拍/航拍录像及包内 macOS 编码器继续可用。主输出保留 -1 dB 限幅，音乐与车辆音效一起进入录像。

## 音乐来源与重建

`tools/build_music.py` 包含原创旋律、和弦编配和所有合成音色的源代码；没有使用网络歌曲、参考视频音轨、第三方采样或音源。参考视频在当前访问中返回 403，且工具不能直接听辨音频，因此不声称配乐复刻了原视频。

`python3 tools/build_music.py` 使用 Python 标准库生成 PCM，再用已安装的 FFmpeg 编成 `assets/audio/open_tracks.ogg`。运行与打包只需要已提交的 OGG 及 `.import`，无需 Python 或 FFmpeg。生成检查覆盖非静音、峰值和两个声道环回接缝；主观音乐和混音仍待试听验收。

## 安装与范围

打开 `OffRoadRider-0.4.0.dmg`，将 `Off Road Rider.app` 拖到“应用程序”。包包含 arm64 与 x86_64；本机运行验证为 Apple M4，未实测 Intel Mac。

本版仍为 ad-hoc 临时签名，没有 Apple Developer ID 签名或公证。首次从网络下载后可能被 macOS 拦截；需在系统设置的隐私与安全中按系统提示允许此应用。不要全局关闭 Gatekeeper。

本版没有新增完整机械变速箱、存档、轮胎变形或发布级美术/音频验收。最终安装包校验与运行结果记录在 [验收记录](ACCEPTANCE.md) 中。
