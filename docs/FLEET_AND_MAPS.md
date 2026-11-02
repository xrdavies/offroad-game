# 车队与地图设计

本轮保留原有四台车，增加六种实车外观参考。模型由 `tools/build_assets.gd` 原创生成，不包含厂商提供的模型、照片纹理或车标。真实名称用于说明参考对象；悬挂、质量、动力和速度是游戏调校参数，不是实车模拟标定。

| 车辆 | 外观特征与区别 | 参考资料 |
| --- | --- | --- |
| Scout | 封闭旅行车、矩形前灯、车顶行李架和储物箱、尾部备胎 | 保留原设计 |
| Ridge | 短轴距、开放座舱、防滚架、局部篷布、辅助灯 | 保留原设计 |
| Ranger | 单排驾驶室、长开放货斗、宽保险杠 | 保留原设计 |
| Atlas | 高驾驶室、三轴六轮、开放货厢和篷架 | 保留原设计 |
| Wrangler Trail | 直立前脸、圆灯、七孔格栅、外露铰链、独立轮拱、黑色硬顶和尾部备胎 | [Jeep / Stellantis 官方介绍](https://www.media.stellantis.com/uk-en/jeep/press/all-new-jeep-wrangler) |
| Unimog Expedition | 高置短驾驶室、大轮胎、两级踏板、四轮、后部旅居箱体与梯子 | [Mercedes-Benz U5023 官方资料](https://special.mercedes-benz-trucks.com/en/the-extreme-off-road-unimog/technical-data/start.html) |
| F-150 Desert | 宽体双排驾驶室、倾斜风挡、C 形灯组、宽格栅、开放货斗及货斗防滚架 | [Ford F-150 Raptor](https://www.ford.com/trucks/f150/models/raptor/) |
| Hilux Trail | 更窄的双排车身、细长灯组、收窄格栅和紧凑货斗 | [Toyota Hilux 官方改款介绍](https://www.toyota.com.au/discover/news/upgraded-hilux-revealed-with-new-looks-improved-technology-and-48-volt-powertrain) |
| EQ246 Transport | 平头驾驶室、分体前窗、三轴六轮、帆布货厢、绑带和踏板 | [EQ246 / EQ2102 车型资料](https://chejiahao.autohome.com.cn/info/2055064)、[底盘供应商资料](https://www.fydftruck.com/dongfeng-eq245eq246-class-iii-chassis-7-2m-convertible-all-wheel-drive-chassis-dongfeng-66-off-road-special-class-iii-chassis-product/) |
| WC-62 Classic | 窄长发动机盖、外置圆灯、开放驾驶室、分体前窗、木条货厢和篷架、三轴六轮 | [Tucson 军用车辆博物馆](https://www.tucsonmilitaryvehicle.org/exhibit/dodge-wc-62-personnel-cargo-carrier-1%C2%BD-ton-6x6/) |

六台新增车按用户指定的车型分组设计；Unimog 在实车分类中属于特种卡车，这里作为四轮越野远征车型提供。EQ246 采用平头造型，避免与长头 EQ245 混淆。

十车均增加弧形轮拱、车架、车轴与差速器外观、轮毂螺栓、轮胎花纹、车门分缝、把手、踏板和后视镜。驾驶舱沿用圆角仪表台、带刻度的实时仪表、座椅和动态方向盘；目前不是各实车内饰的一比一复刻。

本次外观复核进一步强化了参考车型的轮廓识别：Wrangler 增加七孔直立前脸、外露铰链、黑色硬顶和红色拖钩；Unimog 增加高置平头驾驶室、分体前窗、门户轮毂、外置后视镜和高踏板；F-150 使用宽体轮拱、隆起发动机盖和双排驾驶室肩线；Hilux 使用窄体车身、涉水进气管、前防撞杆和货斗防滚架；EQ246 使用平头分体窗、角灯、外置后视镜和三轴恢复杆；WC-62 使用长机盖、开放驾驶室、圆灯、木质货厢侧板和帆布架。细节均由项目几何素材生成，不使用厂商标志。

侧窗与内饰复核参考了车型资料和实车图像：Wrangler JL 的可拆车门分段玻璃、开放车顶和圆形出风口参考 [Jeep Wrangler 内饰资料](https://www.jeep.sk/novy-wrangler/interieri)；Unimog 的高位大侧窗、分体前窗、黑灰开关台和多功能驾驶位参考 [Mercedes-Benz Unimog 越野驾驶室资料](https://www.mercedes-benz-trucks.com/gh/en/trucks/unimog-offroad.html)；F-150 的双排分窗、宽体驾驶室和现代化中控参考 [Ford F-150 Raptor 资料](https://www.ford.com/trucks/f150/models/raptor/)；Hilux 的双排侧窗、后滑窗和耐用型黑色内饰参考 [Toyota Hilux 资料](https://www.toyota-gib.com/en/models/hilux.html)。EQ246 的平头分体风挡、可开启侧窗和帆布货箱参考 [EQ246 车型图说](https://chejiahao.autohome.com.cn/info/2055064)；WC-62 的开放式驾驶室、简洁钢制仪表台和三轴军用车厢参考 [Tucson Military Vehicle Museum](https://www.tucsonmilitaryvehicle.org/exhibit/dodge-wc-62-personnel-cargo-carrier-1%C2%BD-ton-6x6/) 与 [Dodge WC-62 图像资料](https://commons.wikimedia.org/wiki/Category%3ADodge_WC-62)。

六台参考车型的第一视角现在共享基础仪表功能，但使用独立的方向盘前围、仪表台颜色、座椅材质、开关布局和外挂结构；这保留了统一卡通美术语言，同时让切换车辆时能从驾驶位识别车型。

本轮驾驶舱复核又把差异推进到驾驶操作层：Wrangler 使用三辐圆环、车身色喇叭盖和红色抓手；Unimog 使用更大的四辐工业方向盘、抬高的开关台和横向扶手；F-150 使用带橙色控制件的粗三辐性能方向盘和宽屏中控；Hilux 使用较窄的三辐工具型方向盘与紧凑手动挡台；EQ246 使用大尺寸四辐军用方向盘、三只辅助表和橄榄色冲压面板；WC-62 使用细三辐老式方向盘、三只简洁圆表和开放式帆布立柱。车内镜头截图逐车检查了方向盘、仪表和前围的遮挡关系。

轮胎检查将六轮车型的后两桥间距增大，并让车体轮拱、视觉轮胎和射线悬挂使用同一组轴距/侧向偏移。三轴车型的相邻轮胎外缘保留大于一个轮胎直径的纵向间隔；车内则检查了方向盘、仪表台、座椅、换挡杆和窗框的实际视口，没有发现互相穿透的主要几何体。

Old Frontier 的 GRANITE GATE 攀岩区由中央连续阶梯、两侧错位巨石、倾斜侧坡、路线护栏和旗杆组成，巨石与台阶均有物理碰撞。入口从 `(-520,-345)` 附近进入，低速挡可沿中央路线或两侧巨石线通过；地图截图回归使用近景机位检查车辆与障碍物的相对尺度。

## 三张地图

三张地图分别生成、切换时释放旧地图，不是给同一场景改名。每张地图的边界为 X ±720 米、Z ±600 米，即 1.728 平方公里；原 0.702 平方公里地图扩大约 2.46 倍。地形使用 2 米网格，64 米分块，可见地形与物理碰撞使用同一网格。

| 地图 | 主要组合 | 发现地点 |
| --- | --- | --- |
| Old Frontier | 原有修理站、废车场、双桥、垃圾山、森林、草原、沙漠、泥地、沼泽、山地；扩展戈壁、废墟街区、攀岩路线、湖泊 | 15 |
| Salt Coast | 海岸沙滩、港口废墟、河口、沙漠、戈壁、湿地、草地、绿洲湖 | 7 |
| Alpine Reach | 松林、山口、雪山、岩石攀爬、草甸、冰湖、高山湖泊 | 8 |

原图的中心布局来自项目已有 `route.json`，原有六个区域中心和路线保持。新区域和新地图是本项目原创扩展，不是从参考视频推断出的原作完整地图。湖泊和海岸使用实际地形洼地与水面；冰湖使用可驾驶的低抓地力地面。树干、岩块、废墟骨架与攀爬台阶有碰撞，车辆可穿过废墟街道。海洋为地貌与背景，深水不适合作为驾驶路线；陷车可按 R 回到当前地图起点。

地图切换入口在 Esc 菜单与 M 导航图底部。保留所选车型和驾驶镜头，各地图发现记录、导航点在本次运行内分别保留；当前没有跨次启动存档，也没有地图之间的无缝驾驶连接。为保护视频保存流程，录制或编码收尾期间会提示先完成录像再切换地图。
