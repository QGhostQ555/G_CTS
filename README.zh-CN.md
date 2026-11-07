# G_CTS 项目说明

G_CTS 是面向 Android root 环境的 CPU 调度模块，基于 [MoWei 公开的 CpuTurboScheduler](https://github.com/MoWei-2077/MW_CpuTurboScheduler) 二次开发。模块包含 SoC 配置、安装时设备校准、常驻调度守护进程、WebUI 与 Scene 模式接口。

> **重要说明：**调度配置是设备级起点，不代表所有同 SoC 机型经过了相同测试。系统内核、厂商策略、温度、负载、其他调度工具都会影响结果。模块不关闭厂商温控，不锁定 CPU 最低频率，也不承诺安装后必然省电或提升性能。

## 项目目标与功能边界

- 提供 `powersave`（省电）、`balance`（均衡）、`performance`（性能）、`fast`（极速）四档。
- 安装时读取设备实际 CPUFreq policy、CPU 映射、可用 OPP 与 governor，校准 SoC 配置，并移除设备不存在的 policy 映射。
- `fast` 把实际识别到的各 CPU policy 最高可读取频点作为频率上限，前台应用 `uclamp.min=100`；它开放最高上限，不代表持续强制最高频，也不锁最低频。
- WebUI 显示设备信息、CPU policy 实时频率与上限，以及设备提供的电量、温度等数据。
- 调校页按模式设置 KGSL GPU 最低/最高频率；仅当设备导出可读写上下限和可用 OPP 列表时开放，未设置时恢复接管前的设备值。
- 按设备实时 sysfs 能力决定是否开放 I/O scheduler、队列调优、CPUIdle 和 Qualcomm DDR/LLCC 等选项；能力检测不等于驱动最终接受写入。
- WebUI 与 Scene 都可切换模式；共享模式状态文件，便于显示当前档位。
- KGSL GPU idle timer 是可选能力。若内核接受写入才会生效；节点存在或权限可写不代表内核一定支持修改。

## 已实测设备

目前已实机测试的设备为：

| 设备 | SoC | 说明 |
|---|---|---|
| POCO F6 Pro | Snapdragon 8 Gen 2 | 已实机测试；具体结果会受系统版本、内核和温度策略影响。 |
| POCO F3 | Snapdragon 870 | 已实机测试。该设备报告切档请求 KGSL `idle_timer` 为 150/300/800 ms 时，读回仍为 60 ms；见下方 GPU 说明。 |

“已实测”仅表示在这些设备上实际运行过模块，不代表所有档位、配置组合、应用工作负载或长期续航都完成了标准化 A/B 测试。测试流程见 [TUNING_RESEARCH.md](./TUNING_RESEARCH.md)。

## 安装和运行流程

1. 在支持的 root 模块管理器中刷入安装 ZIP。该 ZIP 是 root 模块包，不是普通 APK。
2. 安装器通过设备属性和硬件信息选择 `conf/*.ini` 配置。
3. 安装器检查真实 CPUFreq policy、CPU 核心映射、OPP 和 governor；频率目标会按设备频点校准。
4. 安装器探测块设备队列、CPUIdle、配置中引用的 devfreq 节点，以及 KGSL idle timer 等接口；不具备应用条件的设置会被关闭或标记为不可用。
5. 重启后 `service.sh` 等待 Android 用户存储可用，部署 Scene 接口，按当前模式同步可选 GPU timer，并持续看护预编译调度守护进程；异常退出时回退到 balance 并按退避间隔自动重试。
6. 用户从 WebUI 或 Scene 选择四档之一；守护进程读取配置并应用其支持的 CPU/系统参数。

请在更新前备份现有配置。不要同时运行多个会改写相同 CPUFreq、cpuset、I/O 或 GPU 节点的调度工具，除非明确了解冲突关系。“禁用 GPU Boost”与 GPU 频率上下限控制不能同时启用。

## WebUI 界面和交互逻辑

### 页面导航

| 页面 | 内容 |
|---|---|
| 调度 | SoC/设备信息、当前模式、四档卡片、各 policy 实时频率/模式上限，以及设备能提供的电池和温度信息。 |
| 调校 | 分为“模式参数”和“全局功能”。模式参数针对选中的档位；全局功能配置跨档位设置。 |
| 日志 | 查看守护进程日志，提供页面上显示的日志操作。 |
| 设置 | 外观、配置备份/恢复、恢复默认值、守护进程重启等操作。 |

### 模式选择

- 点击非当前档位后，界面立即更新选择态，并调用 `/data/powercfg.sh <mode>` 写入模式状态。
- 接口会尝试应用该档的 KGSL idle timer（仅配置定义且节点条件满足时），写后读回并向 WebUI 报告状态。
- WebUI 随后轮询守护进程和 CPUFreq policy 上限，报告模式同步及上限校验结果。**模式文件写入成功不等于每项参数都已生效。**
- 再次点击当前档位不重复切换，只重新绘制当前选中卡片；触摸/悬停时仍保持对应主题色。
- 通知中的“撤销”会请求切回操作前的档位。
- 仅支持 `powersave`、`balance`、`performance`、`fast`。`standby` 不受支持。

### 参数编辑和保存

- 频率/数值条用于显示当前值；点击后通过弹出选项选择，不需要拖动滑条。
- 编辑后出现未保存提示和“保存并应用”操作；也可放弃更改。
- 保存会写入 `config.ini`，保留上次版本为 `config.ini.last`，然后通过 `restart.sh` 请求开机服务重启守护进程，并确认新进程已运行。
- 保存前按当前设备能力校验 I/O、队列优化、CPUIdle、DDR/LLCC；不支持的值不会允许通过 UI 保存。
- 不在 KernelSU 环境运行时，`demo.js` 提供桌面演示数据。**演示模式不会连接手机、不会写入配置，也不能证明真机能力。**

## 参数配置说明

安装后的活动配置位于 `/sdcard/Android/MW_CpuSpeedController/config.ini`；当前档位单独存储于同目录的 `config.txt`。`conf/` 中是每个 SoC 的默认模板，安装器可能根据设备实测接口进行校准或关闭不支持功能。

| 段 / 参数 | 作用、单位与注意事项 |
|---|---|
| `[meta]` | `name` 为配置显示名称；`configVersion` 必须与预编译守护进程读取的 schema 兼容；`loglevel` 控制日志等级。 |
| `[function]` | 全局功能开关，如 `EasScheduler`、`cpuset`、`LoadBalancing`、`AdjIOScheduler`、`LaunchBoost`、`AffintySetter`、`DisableQcomGpu`、`CpuIdleScaling_Governor`。参数存在不代表内核接口存在。 |
| `[CoreFramework]` | `SmallCorePath`、`MediumCorePath`、`BigCorePath`、`SuperBigCorePath` 将逻辑簇映射到 kernel CPUFreq policy 编号。policy 编号不是固定 SoC 规格，安装时会检查实际目录。 |
| `[powersave]` / `[balance]` / `[performance]` / `[fast]` | 每档的 governor、CPU/GPU 频率上下限、uclamp、governor 参数、UFS/网络选项及可选 GPU timer。 |
| `*CoreMaxFreq` | CPU policy 频率上限，单位 kHz。若能读到 OPP 列表，安装器将目标向下吸附至可用频点；极速档使用最高可读频点。 |
| `*CoreMinFreq` | CPU policy 频率下限，单位 kHz；`0` 表示不设置下限。默认配置不锁最低频。 |
| `UclampTopAppMin/Max`、`UclampForeGroundMin/Max`、`UclampBackGroundMin/Max` | 前台应用、前台组、后台组的 utilization clamp 边界，配置使用 0–100 数值。`UclampTopApplatency_sensitive` 是前台延迟敏感标志（0/1），具体支持由内核决定。 |
| `[ParamSchedPath]` 与 `ParamSched1`–`ParamSched12` | `ParamSchedPathN` 把编号参数映射到 governor 参数名；对应模式里的 `ParamSchedN` 是写入值。节点必须由当前 policy/governor 导出。`up_rate_limit_us`、`down_rate_limit_us` 的单位为 µs。 |
| `[Cpuset]` | `top_app`、`foreground`、`restricted`、`system_background`、`background` 的 CPU 列表，使用 Linux cpulist 格式，如 `0-3,6`。受设备实际 CPU 数和系统 cpuset 限制。 |
| `[IO_Settings] Scheduler` | 对块设备队列选择 I/O scheduler。安装时求各队列共同支持项，并选择兼容默认；此项是设备存储队列能力，不是 SoC 必然特征，也不是普适性能排名。 |
| `[IO_Settings] IO_optimization` | 守护进程的 I/O 队列调优开关。要求所有目标队列的 `iostats`、`nomerges` 节点及 scheduler 检查具备支持条件。 |
| `[CpuIdle] current_governor` | 请求的 CPUIdle governor。要求设备提供 `available_governors`、可写 `current_governor` 且配置值在可用列表中。 |
| `[Bus_dcvs]` / `[Other] AdjQcomBus_dcvs` | 配置中引用的 Qualcomm DDR/LLCC devfreq 节点和联动开关。路径由内核/OEM 决定；模式值 `0` 表示让驱动自动管理。只在配置定义且节点存在可读写时展示。 |
| `[LaunchBoost] BoostRateMs` | 启动加速时长，毫秒。 |
| `[LaunchBoost] FreqMulti` | 启动加速频率倍数，实际生效范围取决于守护进程实现与设备 policy。 |
| `[LaunchBoost] UclampTopAppBoostMin` | 启动加速期间前台应用的 uclamp 下限，0–100 配置刻度。 |
| `ufsClkGate` / `NetWorkOpt` | 模式级 UFS 时钟门控和网络优化布尔值。具体节点与效果依赖守护进程和 OEM 内核。 |
| `GpuIdleTimerMs` | KGSL `idle_timer` 目标值，单位 ms。`0` 请求恢复首次接管前保存值。写入后读回验证；驱动忽略或改写时以实际读回为准。 |
| `GpuMinFreq` / `GpuMaxFreq` | 模式级 KGSL devfreq 最低/最高频率，单位 Hz；仅允许选择设备 `available_frequencies` 中的 OPP。`0` 表示该边界跟随首次接管前的设备值；两者都为 `0` 时恢复并释放控制。应用后按 sysfs 读回结果报告，卸载时尝试恢复原始上下限。 |

**不要把一个机型的 policy 编号、devfreq 路径、governor 参数或 OPP 值直接套到另一台手机。** sysfs 节点可写仅代表具备尝试条件，不代表 SELinux、驱动或守护进程接受该值。

## 四档的调度取舍

频率上限决定调速器可请求的最高范围；uclamp 影响调度器看到的任务利用率边界；cpuset 限定任务可运行的 CPU 集合。三者作用不同，不能把某个数值单独解释成整机功耗或流畅度结论。

| 档位 | 设计目标 | 配置取舍 |
|---|---|---|
| 省电 | 降低持续 CPU 负载的上限 | 降低可用最高频率，降低后台 uclamp 上限；可能牺牲 CPU 密集型响应。 |
| 均衡 | 日常响应与负载上限折中 | 使用中等频率上限和适中的前后台约束；这是默认折中而非所有机型/任务的唯一最佳点。 |
| 性能 | 重载时提高可用上限和前台响应 | 提高频率上限及部分延迟响应参数；持续负载可能更耗电、更热并触发 OEM 温控。 |
| 极速 | 开放每个实际 policy 的最高可用 OPP | 安装时将最高上限校准至本机可用最高点，前台 `uclamp.min=100`；不锁最低频、不绕过温控，长时间负载更可能增加热量和耗电。 |

CPU 的动态功耗受电压、频率、活动因子、芯片漏电和任务耗时共同影响。屏幕、GPU、存储、无线电或系统温控可能主导体验和耗电；降低 CPU 上限不保证整机一定省电，极速也不代表每项任务都更快。比较档位请遵照 [真机 A/B 说明](./TUNING_RESEARCH.md)，每轮只改变一个因素。

## SoC 配置文件索引

每个文件定义 `[meta]`、功能开关、簇到 policy 的映射，以及四档参数。名称表示安装器配置族，并不表示不同 OEM 设备具有完全相同的拓扑或参数。

| 文件 | 配置目标 |
|---|---|
| `conf/MTK720.ini` | 天玑 800U / 720 |
| `conf/MTKG99.ini` | 天玑 G99 |
| `conf/MTK1080.ini` | 天玑 1080 |
| `conf/MTK1100.ini` | 天玑 1100 |
| `conf/MTK1200.ini` | 天玑 1200 |
| `conf/MTK8100.ini` | 天玑 8100 |
| `conf/MTK8200.ini` | 天玑 8200 |
| `conf/MTK8300.ini` | 天玑 8300 |
| `conf/MTK8300Ultra.ini` | 天玑 8300 Ultra |
| `conf/MTK8400Ultra.ini` | 天玑 8400 Ultra |
| `conf/MTK9000.ini` | 天玑 9000 |
| `conf/MTK9200.ini` | 天玑 9200 |
| `conf/MTK9200+.ini` | 天玑 9200 系列配置变体 |
| `conf/MTK9300+.ini` | 天玑 9300 系列配置变体 |
| `conf/MTK9400+.ini` | 天玑 9400+ |
| `conf/SDM660.ini` | 骁龙 660 |
| `conf/SDM750G.ini` | 骁龙 750G |
| `conf/SDM765G.ini` | 骁龙 765G |
| `conf/SDM7G2+.ini` | 骁龙 7+ Gen 2 |
| `conf/SDM7G3.ini` | 骁龙 7 Gen 3 |
| `conf/SDM7G3+.ini` | 骁龙 7+ Gen 3 配置族 |
| `conf/SDM7sG2.ini` | 骁龙 7s Gen 2 |
| `conf/SDM855.ini` | 骁龙 855 / 860 |
| `conf/SDM865.ini` | 骁龙 865 |
| `conf/SDM870.ini` | 骁龙 870 |
| `conf/SDM888.ini` | 骁龙 888 |
| `conf/SDM8G1.ini` | 骁龙 8 Gen 1 |
| `conf/SDM8G1+.ini` | 骁龙 8+ Gen 1 |
| `conf/SDM8G2.ini` | 骁龙 8 Gen 2 |
| `conf/SDM8G3.ini` | 骁龙 8 Gen 3 |
| `conf/SDM8Elite.ini` | 骁龙 8 Elite |

自动匹配范围和运行时校验详见 [SUPPORTED_SOC.md](./SUPPORTED_SOC.md)。

## 仓库文件逐项说明

### 根目录

| 文件 | 用途 |
|---|---|
| `README.md` | GitHub 首页入口（中英文项目简介）。 |
| `README.zh-CN.md` | 本文：中文功能、交互、参数、文件和适配说明。 |
| `module.prop` | root 模块 ID、名称、版本、作者及管理器显示简介。 |
| `customize.sh` | 安装主流程：SoC 配置匹配、拷贝、I/O/CPUIdle/devfreq 能力探测、policy 校验和 OPP 校准。 |
| `service.sh` | 开机后部署 Scene 入口、同步模式与 GPU 状态；持续看护守护进程，意外退出时回退到 balance 并退避重试。 |
| `uninstall.sh` | 停止守护进程、请求恢复已保存的 KGSL 原值并清除模块部署文件。 |
| `MW_CpuSpeedController` | 预编译 native 调度守护进程；它负责消费配置并处理运行期调度参数。 |
| `SUPPORTED_SOC.md` | 配置族覆盖、policy/OPP 校准与 sysfs 能力检测说明。 |
| `TUNING_RESEARCH.md` | 控制变量的真机 A/B 测试与采样结果解释。 |
| `调度说明.md` | 中文 SoC 频点目标、四档逻辑、已知问题和内核边界。 |
| `updateLog.txt` | 版本改动记录。 |
| `LICENSE`（发布包需包含） | 上游 GPL-3.0 许可证文本。发布时保留原始许可证和作者声明。 |
| `third_party/MW_CpuTurboScheduler-*-source.tar.gz`（发布包需包含） | 固定上游提交的源代码快照，用于提供预编译守护进程来源/对应源代码；构建来源仍应以实际二进制 provenance 核实。 |

### `conf/`

31 个 SoC INI 文件逐项列于上一节。每个 profile 的职责相同：定义设备族默认参数；其中 `CoreFramework` 映射逻辑 CPU 簇，四个模式段提供 per-mode 值，安装器再以真机 policy/OPP/sysfs 能力作为最终依据。

### `vtools/`

| 文件 | 用途 |
|---|---|
| `vtools/powercfg.sh` | WebUI/Scene 模式接口；校验档位、写模式状态、尝试应用并读回 GPU idle timer、输出实际结果。 |
| `vtools/gen_json.sh` | 从 `module.prop` 生成 Scene 使用的 `powercfg.json`。 |
| `vtools/init_vtools.sh` | 安装时把 Scene JSON 与 `powercfg.sh` 部署到 `/data`，初始化共享模式文件。 |
| `vtools/desc.sh` | 更新 root 管理器展示的设备、档位和守护进程状态。 |
| `vtools/restart.sh` | 通过开机服务请求重启并确认新进程；服务未运行时提供 detached 启动回退。 |
| `vtools/ab_sample.sh` | 只读采集电量、温度、CPU policy 和可用降频计数；不切模式、不写节点。 |

### `webroot/`

| 文件 | 用途 |
|---|---|
| `webroot/index.html` | WebUI 页面骨架、页面容器和脚本/样式入口。 |
| `webroot/app.js` | 主交互：KernelSU shell bridge、真机探测协议、模式切换、参数编辑、保存/恢复和诊断提示。 |
| `webroot/styles.css` | 响应式 Material 3 主题、模式色、卡片、弹窗、按钮和触屏交互状态。 |
| `webroot/soc-data.js` | UI 使用的 SoC 名称、簇拓扑和 policy 展示回退信息。 |
| `webroot/demo.js` | 浏览器桌面预览的模拟接口和测试数据；不连接真机，不写设备。 |

### `META-INF/`

| 文件 | 用途 |
|---|---|
| `META-INF/com/google/android/update-binary` | recovery 安装入口。 |
| `META-INF/com/google/android/updater-script` | recovery 安装脚本标记。 |

## Snapdragon 870 的 `idle_timer`

POCO F3 截图中请求 150/300/800 ms 后仍读回 60 ms。这不是颜色或参数选择错误：公开 SM8250 内核源码存在 KGSL timer store 函数提前返回、跳过实际参数写入的实现。若设备内核使用此类驱动，普通 root 模块或 magic mount 覆盖一个同名文件都不能绕过内核 handler。真正改变值需要内核/驱动修复。

当前模块在写后值和写前值相同的情况下，将其识别为本次启动内核未接受写入，停止重复尝试并提示不可调；下一次开机重新探测。不要通过修改 sysfs 权限、关闭 SELinux 或写入未文档化 GPU 节点来强行绕过。

## 许可与鸣谢

- 感谢 **小疣然** 分享和提供 SoC 调度配置参考。
- 感谢 **MoWei** 发布 CpuTurboScheduler 公开模块和相关源码，本项目基于该项目继续修改。
- 本项目保留上游作者信息；上游项目采用 GNU GPL v3。公开发布包含预编译守护进程的版本时，必须随附适用许可证文本和对应源代码/源码可获得方式。发行包中的 `third_party/` 快照固定到上游提交，二进制的实际构建来源仍建议由发布者核对。

## 相关文档

- [SoC 映射和能力检测](./SUPPORTED_SOC.md)
- [调度说明与参数研究](./调度说明.md)
- [真机 A/B 测试方法](./TUNING_RESEARCH.md)
- [MoWei 上游项目](https://github.com/MoWei-2077/MW_CpuTurboScheduler)
