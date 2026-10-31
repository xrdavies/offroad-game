# Dustline

第一版 3D 越野自由驾驶原型，参考《GARBAGE COUNTRY》的俯斜视角、暖色荒地和低多边形废墟气质。

## 运行

```sh
/Users/m4002/Applications/Godot.app/Contents/MacOS/Godot --path /Users/m4002/Projects/offroad-roam
```

## 操作

- `WASD` 或方向键：驾驶
- `Space`：手刹
- `R`：回到起点

当前版本是一条可玩的风格切片：场景、车辆、废墟、路标、风车、岩石、坡道和尘土都由 Godot 程序化生成，保持统一的低多边形暖色荒地语言。

音频目录包含原创的引擎循环和荒地环境循环；WAV 用于编辑和导出，PCM 数据让无界面运行也能稳定加载。音频只借鉴参考视频的氛围，不复制其音乐。

## 校验

```sh
/Users/m4002/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
/Users/m4002/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 3
```

发布级版本还需要继续打磨车辆模型、材质贴图、关卡节奏、碰撞细节、混音和目标平台导出设置；本仓库当前提交提供可持续迭代的完整玩法基线。
