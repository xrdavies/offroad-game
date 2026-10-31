# Off Road Rider

参考 [noio 的《GARBAGE COUNTRY》预告](https://x.com/noio_games/status/1931808116879786225) 制作的原创 3D 越野探索项目。当前是可运行的开发版本，**尚未完成发布验收**。

![实机画面](docs/previews/service.png)

## 运行

引擎：Godot 4.7.2。当前 Mac 安装于 `/Users/m4002/Applications/Godot.app`。在项目目录依次执行：

```sh
/Users/m4002/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Users/m4002/Applications/Godot.app/Contents/MacOS/Godot --path .
```

也可用 Godot 打开 `project.godot`，等待导入完成后按 F6/F5 运行。默认使用 Metal / Forward+；兼容性诊断可传 `--rendering-method gl_compatibility`，该模式没有相同的环境遮蔽效果。

## 操作

| 操作 | 按键 |
| --- | --- |
| 驾驶 | WASD / 方向键 |
| 手刹 | Space |
| 回到修理站 | R |
| 查看探索地图 | M |
| 暂停、音量、退出 | Esc |
| 缩放镜头 | 鼠标滚轮 |

## 当前内容

- 300 × 260 米的可驾驶地形：修理站、废车场、浅水河道、双桥、采石区与中继设施。
- 22 个独立体素模型场景；六种破损废车、四类废料、车身、轮胎、设施和护栏都有可重建的源代码。
- 成片荒草、下垂棕榈叶、层状岩壁、可驾驶垃圾山、磨损路面和曲折浅滩；暖光、偏紫阴影与更近的跟随视角。
- 四轮射线悬挂、前进/倒车、抓地力和手刹、涉水阻力、尘土、水花、限量轮迹。
- 引擎、砂石胎噪、涉水、风声、碰撞、发现提示共 6 个原创声音文件。
- 俯斜正交镜头、地点发现、地图、暂停和总音量控制。探索记录当前只保留在本次运行中。

素材来源与编辑方式见 [素材清单](docs/ASSETS.md)；参考视频拆解、地图推定范围见 [参考说明](docs/REFERENCE.md)；发布差距和实测记录见 [验收记录](docs/ACCEPTANCE.md)。视频中的塔防、升级系统和完整配乐范围仍待用户确认。

本轮画面对照：[修改前后](docs/previews/comparison.png)、[废车场](docs/previews/yard.png)、[车辆近景](docs/previews/scout.png)、[浅滩行驶](docs/previews/river.png)。

## 验证与构建

下面的 `godot` 指对应平台的 Godot 可执行文件。导入完成后再运行测试，不能同时启动两者。

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke.gd
godot --path . --script tests/capture.gd -- /tmp/off-road-rider-service.png
```

冒烟测试验证接地、静止稳定、加速、转向、制动、重置、空中动力限制、涉水、暂停、双桥通行和垃圾山碰撞，并检查场景实例的空间分区。去掉 `--headless` 运行同一测试，还会验证渲染器中的实例变换与颜色（Godot 无界面渲染器不保存这两项）。检查输出中的 `SMOKE: PASS`，也要检查 `SCRIPT ERROR` / `ERROR`，不能只看退出码。

```sh
mkdir -p build
godot --headless --path . --export-pack macOS build/OffRoadRider.pck
godot --main-pack build/OffRoadRider.pck
```

`build/OffRoadRider.pck` 是本机测试用资源包，需 Godot 运行。

### macOS DMG

在 macOS 上安装与引擎版本一致的官方导出模板（Godot 的 **Editor → Manage Export Templates**），然后在项目目录执行：

```sh
mkdir -p build
godot --headless --path . --editor --import --quit
godot --headless --path . --export-release macOS build/OffRoadRider.dmg
hdiutil verify build/OffRoadRider.dmg
```

打开 `build/OffRoadRider.dmg`，把其中的 `Off Road Rider.app` 拖到“应用程序”后启动；玩家无需安装 Godot。默认导出包含 Apple Silicon 和 Intel 两种架构，仍需在各目标机型验证图形兼容性。

当前导出使用临时签名（ad-hoc），没有 Apple Developer ID 签名或公证；通过网络下载后，macOS 可能拦截首次启动。正式分发前需要配置开发者证书并完成公证，详见 [Godot macOS 导出说明](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)。安装包仍属于开发测试版本，不表示已完成游戏发布验收。`build/` 中的产物不提交到 Git。

## 编辑素材

```sh
godot --headless --path . --script tools/build_assets.gd
python3 tools/build_audio.py
godot --headless --path . --editor --import --quit
```

模型源文件是 `tools/build_assets.gd`，声音源文件是 `tools/build_audio.py`。地图地标和主路布局在 `assets/world/route.json`，地形、植被、桥梁和废料分布在 `world.gd`。旧的 `audio/` 是历史原型音频，当前游戏不再引用，导出时排除。
