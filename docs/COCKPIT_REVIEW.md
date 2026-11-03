# 驾驶舱逐车复核 · 2026-11-03

本轮只修改驾驶舱并交付图片。以 `a771d51` 为修改前基线，十车各捕获正前方、中控、副驾和驾驶侧门四个视角。相机始终位于游戏驾驶位，FOV 78°，相同停车点、朝向和游戏光照；查看车内时只改变鼠标视线方向。修改前为 1280×720，修改后为 1600×900，比较图等比例缩放，不替换光照或用概念图代替游戏画面。

## 发现与修复

| 车型 | 发现的问题 | 修改 |
| --- | --- | --- |
| Scout | 方向盘中心缺少与轮圈相连的横辐，脚舱和仪表通用结构颜色不一致 | 接通三辐，缩小/后倾轮圈，调整仪表相对方向盘的可读位置，灰色脚舱与独立罗盘 |
| Ridge | 同样的悬空轮毂，越野开放车内仍是通用收音机面板 | 三辐、圆形通风口、简洁开关排，保留原车开放空间 |
| Ranger Pickup | 仪表与轮圈遮挡，收音机位于偏右位置 | 中央收音机/空调，棕灰面板，整理门内板、座椅宽度和踏板 |
| Atlas 6×6 | 驾驶舱沿用小车仪表和缺少辐条的方向盘 | 较大的工业轮盘、独立气压/油量/水温辅助表，脚舱与座椅净空 |
| Wrangler Trail | 矩形通用出风口盖住新增圆口，黄色喇叭盖和上方交叉辐条不符参考，中控悬在副驾前 | 红色横向饰板、四圆口、中央屏与下方旋钮/窗控、黑色三辐、多功能按键、带连接支座的扶手 |
| Unimog Expedition | 横条覆盖主仪表，错误分体前窗，两根地板杆，新增拨杆与轮圈相交 | 灰黑控制台、中央开关与下方双风口、四辐和柱式选择杆、撤去错误中央前窗立柱；拨杆移到轮圈后方并复测 |
| F-150 Desert | 主仪表被覆层盖住，中控偏副驾；同一位置叠两屏，两根地板杆，座椅与偏置控制台挤占空间 | 中央横屏与竖风口、数字式仪表面板、橙色轮圈定位标记和拨片、单短选择杆、中线控制台/杯架/扶手、灰黑材质 |
| Hilux Trail | 双层中控遮挡，巨大圆柱覆盖换挡杆，前台与车身浅色混用 | 紧凑中央屏、顶部横向风口、两层手套箱、三旋钮、单手动杆、深灰面板 |
| EQ246 Transport | 宽板穿过下半方向盘；主仪表被遮住，三个辅助表均为罗盘 | 撤去覆盖板、两辐方向盘、分组主仪表和抬高的 OIL/TEMP/FUEL/AIR 四联表、独立开关排，保留平头军车简洁布局 |
| WC-62 Classic | 现代头枕/门饰/厚仪表台，重复罗盘和速度表，过小的现代轮盘 | 薄金属台、中心大速度表与四只小表、细三辐大轮圈、低靠背帆布垫、金属侧壁和帆布带、60 MPH 刻度及对应单位转换 |

整理了仪表、门饰、地板和方向盘的材质配色，减少车漆色与车内灰黑材质的混用；几何体继续采用项目已有的线性顶点颜色转换。外部几何保留原有配色。脚舱使用车内灰色或军绿色，而非直接铺满外部车漆。游戏光照仍有原场景的紫色环境光和暖色太阳，不在截图阶段进行调色。

## 参考与边界

- Wrangler：以 [Jeep 官方 2023 JL 内饰图](https://www.jeep.com/am/en/wrangler/interior.html) 为基准，红色面板/四圆口属于该参考配置，并非所有 Wrangler 年款。
- Unimog：[Mercedes U5023](https://www.mercedes-benz-trucks.com/gh/en/trucks/unimog-offroad.html)；查看了 [Unidan U5023 实车驾驶舱](https://www.unidan.com.au/For-Sale/2024-u5023-doka-green/) 的中控/风口/方向盘/柱式控制，参考照片为右舵，游戏维持左舵。已去掉前一轮误加的中央风挡立柱。
- F-150：以 2021–2023 Raptor 为视觉基准；[Ford 2021 手册](https://www.fordservicecontent.com/Ford_Content/Catalog/owner_information/2021-Ford-F-150-Owners-Manual-version-2_om_EN-US_10_2021.pdf)、[Ford 方向盘套件](https://www.ford.com/product/2021-f150-raptor-steering-wheel-kit-black-p2869926803)、[Ford 提供的内饰发布照片](https://www.motortrend.com/news/2021-ford-f-150-raptor-interior-first-look)。
- Hilux：以第八代早期驾驶舱为基准；[Toyota 官方 2016 资料](https://newsroom.toyota.eu/download/260758/2016-toyota-hilux-dpl-en.pdf)、[实车内饰照片](https://www.km77.com/coches/toyota/hilux/2016/doble-cabina/informacion)。游戏选择手动挡配置，不声称与照片中的自动挡配置逐项相同。
- EQ246：未取得可核实的指定批次完整驾驶舱资料；使用 [EQ246 平头车型资料](https://chejiahao.autohome.com.cn/info/2055064)、同系列 [EQ2102 实车图文](https://www.360che.com/tech/200407/145402.html) 和[零部件目录](https://www.truck6688.com/changjianwenti/1091.html)作近似。两辐、四联辅助仪表是系列参考，不能标为 EQ246 原厂一比一还原。
- WC-62：[Artcurial 实车拍卖图集](https://www.artcurial.com/ventes/2231/lots/20-a)，查看了该车五表和英里刻度近照，保持低座椅和简单金属布局。

屏幕界面、转速/油量/水温/气压小表目前是装饰，并非新实现的车辆系统模拟。速度表/数字读数、方向盘转动及罗盘继续实时工作。罗盘是游戏附加导航仪，不属于原厂仪表复刻。WC-62 仪表使用 MPH，游戏 HUD 仍为 KM/H。没有改变车型动力学、车身简化碰撞体或地图。

## 验证

- `tests/cockpit_clearance.gd` 对烘焙三角网格检测驾驶眼位到速度读数的视线、方向盘中立位置遮挡、左右转动时轮圈与固定驾驶舱的交叉，以及重复实时仪表节点。曾检出 Unimog 拨杆相交及六车轮圈遮挡读数，调整后复测。
- `tests/cockpit.gd` 检查十车速度表标定/超量程、WC-62 英里换算、方向盘响应、罗盘和驾驶相机。
- `tests/smoke.gd` 检查原有驾驶与基础世界回归。
- `tests/capture_cockpits.gd` 捕获十车四个实际视角，逐车对比前后画面。几何检测是采样检测，不能替代任意视角、全转向过程的完整碰撞/人体工效验证。

最终结果：资源导入、`COCKPIT_CLEARANCE`、`COCKPIT`、`SMOKE` 和实际渲染 `COCKPIT_REVIEW` 均通过。十车四视角共 40 张修改后截图已逐车查看。

交付 12 张 JPG：两张六车型横向对照、十张逐车前后对比（左旧右新；上前方、中中控、下副驾）。同步路径：`/Users/m4002/mob-files/OffRoadRider-Demos/Cockpit-Review-2026-11-03/`。文件复制后逐一 SHA-256 比对一致。

仓库图像证据：[驾驶位对照](previews/cockpit-refined-forward.jpg)、[中控对照](previews/cockpit-refined-console.jpg)、[EQ246 前后对比](previews/cockpit-eq246-comparison.jpg)。本轮未生成视频或安装包。
