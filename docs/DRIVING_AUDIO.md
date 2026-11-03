# 车型与地形声音 · 2026-11-03

本轮用 20 条车型引擎循环和 12 条地形循环替换游戏原有的通用引擎/砂石/水声。全部是项目内原创合成 WAV，不包含网络录音、视频提取音轨、音乐或厂商授权素材；是供试听迭代的第一版，不能称为实车录音复刻或发布级混音。

## 调研结论与选型

轮胎行驶声会受胎纹、路面、速度和车辆传声条件影响。[米其林胎路噪声机制](https://thetiredigest.michelin.com/performance-noise-and-comfort)与[轮胎声影响因素](https://www.michelin.com.au/auto/advice/tyre-care/understanding-tyre-noise-and-why-it-matters)说明了胎块冲击、空气排挤和粗糙路面的作用。因游戏尚未定义每台车实际安装的品牌轮胎，本轮共享地形素材，按轮径调整节奏、车重调整有限音量、实际接地轮数混合，不虚构品牌专属胎噪。

| 车型 | 声音参考版本 / 设计 |
| --- | --- |
| Scout | 原创六缸汽油旅行车，较柔和的中低频 |
| Ridge | 原创高转四缸汽油短轴车，较明亮的声音 |
| Ranger Pickup | 原创 V8 皮卡，较低的排气共鸣和不均匀脉冲强度 |
| Atlas 6×6 | 原创六缸重柴油车，低转机械敲击 |
| Wrangler | [2023 JL 的 3.6 Pentastar V6 版本](https://www.jeep.com/am/en/2023/wrangler/capability.html)，汽油声线；不代表 2.0T、392 或 4xe |
| Unimog | [U5023 / OM934，5.1 升直列四缸柴油](https://special.mercedes-benz-trucks.com/en/the-extreme-off-road-unimog/technical-data/start.html)，稀疏厚重脉冲与机械敲击 |
| F-150 | [2021 Raptor 3.5 EcoBoost V6](https://www.ford.com.co/content/dam/Ford/website-assets/latam/co/nameplate/raptor/2021/pdf/fco-raptor-ficha-tecnica.pdf)，明亮排气加轻涡轮层；并非 V8 Raptor R；[Ford 排气结构资料](https://media.ford.com/content/dam/fordmedia/North%20America/US/product/2021/f150/raptor/pdf/2021-Ford-F-150-Raptor-Exhaust-Graphic.pdf) |
| Hilux | [第八代 2.8 涡轮柴油版本](https://media.toyota.co.uk/more-powerful-engine-adds-muscle-to-the-mighty-toyota-hilux/)，比 Unimog 更轻快的四缸节奏 |
| EQ246 | 按同系列 [EQ2102 / 6BT5.9 六缸柴油供应商资料](https://www.dfwarrior.com/news/Dongfeng-2102G-Six-wheel-drive-semi-truck.html)近似设计；没有核实指定 EQ246 批次的发动机和真实声谱 |
| WC-62 | [博物馆 T-223 六缸资料](https://www.tucsonmilitaryvehicle.org/exhibit/dodge-wc-62-personnel-cargo-carrier-1%C2%BD-ton-6x6/)，老式低转直六；[车型零件商资料](https://www.vintagepowerwagons.com/pages/vehicle-type-c)确认 230 flathead 配置 |

发动机类型是资料参考；音色、怠速、红线、排气共鸣和声效挡位是游戏音效设计参数，未做真实发动机声学测量。原有四台车没有指定实车原型，因此使用原创动力声线。

## 地形设计

| 地面 | 声音设计 |
| --- | --- |
| road 道路 | 连续低频滚动、轻胎纹嗡声 |
| dirt 土路 | 细碎颗粒与不规则颠簸 |
| grass 草原 | 低强度刷草声 |
| forest 森林 | 较脆的落叶、枝屑摩擦 |
| rock 岩石 | 低频轮胎冲击与间歇硬质敲击 |
| sand 沙漠/沙滩 | 连续细沙摩擦 |
| mud 泥地 | 较稠、短促的挤压与吸附 |
| swamp 沼泽 | 更慢的湿黏翻动和气泡 |
| water 浅水 | 宽频水花与起伏冲水 |
| gobi 戈壁 | 较锐利的碎石颗粒 |
| snow 雪地 | 密集细碎压雪声 |
| ice 冰面 | 较轻的滑擦与窄带摩擦 |

轮胎声音按每个悬挂射线实际接地点的 `world.surface_at()` 结果混合，地形交界可以同时出现两种声音，约 0.14 秒的平滑响应避免硬切。速度与横向滑动影响音量，轮径影响音高/节奏，车重变化限幅；停止及腾空后淡出到零并停止播放器。水、泥、沼泽不再共用同一声源。地面材质仍沿用现有世界分类；尚未独立给桥板、金属废墟等物体标注接触材质。

引擎分怠速/负载两层，依照油门、行驶速度、倒车与高低速挡改变声效转速和混合比例；松油门减弱负载层，换挡产生短时负载回落。声效挡位不改变实际驱动力，不是新增机械变速箱。车辆腾空可以空转，胎噪必须消失。暂停、恢复、换车、切地图和退出均清理/恢复所有播放层。

主总线使用 Godot 内置 `AudioEffectHardLimiter`，峰值上限 -1 dB，避免高速侧滑、碰撞和引擎叠加时过载；录像捕获位于限幅之后，原有主音量滑条仍有效。

## 源文件与重建

- `assets/audio/profiles.json`：十车声学参数与声效挡位。
- `tools/build_driving_audio.py`：燃烧脉冲、排气共鸣、柴油敲击、涡轮与地形声音的确定性生成器，仅用 Python 标准库。
- `car.gd`：接地点混合、声音转速与播放生命周期；`main.gd` 的切地图/退出统一停止车辆全部播放器。
- `export_presets.cfg` 明确包含 JSON；WAV 及 `.import` 随仓库提交，运行不依赖生成器或网络。

执行 `python3 tools/build_audio.py` 会重建全部音效；仅重建驾驶声音可执行 `python3 tools/build_driving_audio.py`。每条引擎循环 6 秒、地形循环 8 秒，44.1 kHz / 16-bit / mono；保留 150 ms 重叠，去直流，限制峰值并校验环回接缝相对邻样本变化。旧 `engine.wav/gravel.wav/water.wav` 保留供历史版本追溯，当前 `car.gd` 不再引用。

## 验证与限制

`tests/audio.gd` 检查十车双层资源及唯一性、怠速、负载/松油门、低速挡、倒车、全部地面选择、混合接地、停车/空中轮胎静音、恢复、停止、真实区域接地、切地图和暂停恢复。生成器自检覆盖峰值、非静音和接缝；源 WAV 额外验证无直流偏移、互不重复。

`tests/capture_driving_audio.gd` 使用真实游戏的 Master 总线录音：十台车同一路线、1.5 秒怠速→5 秒加速→1.5 秒收油→1.5 秒手刹。不会开启麦克风，不会制作视频。

当前工具不能直接听辨音频；技术校验与游戏录音不替代人耳音色评价。尚未做真车录音比对、车内外声学隔绝、胎压/轮胎形变声学或专业混音验收。没有新增配乐、启动/熄火系统、喇叭或安装包。
