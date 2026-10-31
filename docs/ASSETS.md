# 素材清单与来源

本版的模型、几何体、着色器、音效和地图数据均在项目内原创编写，没有从参考视频提取贴图、模型或音乐。参考视频只用于观察视觉风格、物体类型和玩法。UI 使用 Godot 自带字体。

## 模型

所有模型位于 `assets/models/`，源文件为 `tools/build_assets.gd`。每个模型将彩色几何体合并到一个网格，便于复用并控制绘制调用；需要阻挡车辆的场景包含静态碰撞形状。

| 资源 | 用途 |
| --- | --- |
| `scout_body.tscn` | 越野车，车窗、行李架、货箱、保险杠、灯、备胎、涉水管 |
| `scout_wheel.tscn` | 带胎纹、轮毂的独立轮胎，悬挂与转向驱动 |
| `wreck_0/1/2.tscn` | 三种配色的废车 |
| `garage.tscn` | 可驶入的修理站、雨棚、门窗、波纹屋顶 |
| `fuel_pump.tscn` | 油泵与油管 |
| `container.tscn` | 带波纹与门杆的集装箱 |
| `palm.tscn` | 分段树干与体素叶片 |
| `utility_pole.tscn` | 电线杆与绝缘子，线路由地图连接 |
| `barrel.tscn` | 锈蚀色金属桶 |
| `barrier.tscn` | 混凝土路障 |
| `fence.tscn` | 围栏模块 |
| `water_tank.tscn` | 高架水塔 |
| `relay.tscn` | 中继设施与天线 |

`world.gd` 还生成层状岩壁、桥梁、地形、路面、植被簇、碎石、彩色废料堆与标牌。草、碎石和废料使用 MultiMesh 合批。水面、道路和地面材质分别位于 `assets/water.gdshader`、`assets/road.gdshader`、`assets/ground.gdshader`。这些是原生几何体和着色器资产，不是位图占位图。

## 音效

| 文件（`assets/audio/`） | 长度 | 行为 |
| --- | --- | --- |
| `engine.wav` | 3 秒 | 随油门和速度调整音高、音量 |
| `gravel.wav` | 4 秒 | 砂石地面行驶时混入 |
| `water.wav` | 4 秒 | 浅水行驶时混入 |
| `wind.wav` | 8 秒 | 低音量环境风声 |
| `impact.wav` | 0.48 秒 | 有实际碰撞和速度突变时触发 |
| `discovery.wav` | 1 秒 | 第一次发现地点时触发 |

均为 44.1 kHz / 16-bit / 单声道 WAV；使用项目内确定性合成程序生成，循环带交叉衔接、去直流偏移与峰值校验。Godot 通过标准导入资源加载。这里没有完整配乐，也没有声称已完成专业听音和混音验收。

`.uid` 与 `.import` 是需要提交的资源标识和导入设置；`.godot/` 是可重建的导入缓存。所有当前游戏引用的资源都在仓库内，构建不依赖 `/tmp` 或在线生成服务。
