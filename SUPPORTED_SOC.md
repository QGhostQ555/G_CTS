# G_CTS SoC 配置映射（v6.1.12-Ghost）

安装器根据 `ro.board.platform` / `ro.soc.model` / 设备核心频率识别配置。支持范围以 `customize.sh:get_config_name()` 和同名 `conf/*.ini` 同时存在为准。所有已映射配置都会尝试安装期 OPP 吸附；仅当设备暴露 `scaling_available_frequencies` 时才能校准到真实频点。

## Qualcomm
- SDM660、SDM750G、SDM765G
- SDM7G2+、SDM7G3+、SDM7sG2
- SDM855、SDM865、SDM870、SDM888
- SDM8G1、SDM8G1+、SDM8G2、SDM8G3、SDM8Elite

## MediaTek
- MTK720、MTK1080、MTKG99
- MTK1100、MTK1200、MTK8100、MTK8200
- MTK8300、MTK8300Ultra、MTK8400Ultra
- MTK9000、MTK9200+、MTK9300+、MTK9400+

## 注意
- 安装器会验证配置引用的 cpufreq policy，并从配置中移除设备不存在的簇；每个模式的频率上限会向下吸附到最近的可用 OPP。若目标低于设备最低 OPP，则采用最低 OPP。
- 安装输出用简洁分组汇总 I/O、KGSL 与 CPU 检测；每个实际 CPU policy 显示 OPP 范围和四档上限。极速档使用最高可用 OPP，前台应用 `uclamp.min=100`。
- 每次安装都会逐个检查块设备队列的 scheduler、`iostats` 和 `nomerges`。仅当所有队列都有可读写 scheduler 且存在共同选项时，才显示/启用 I/O scheduler 开关；兼容默认优先 `mq-deadline`，再回退 `kyber`、`bfq`、`none`。I/O 队列优化还要求所有队列的 `iostats` / `nomerges` 节点均可读写，并依赖 I/O scheduler 检测通过；能力不满足时安装器关闭对应配置，WebUI 隐藏开关并显示原因。节点存在/权限可写是应用前提，不是内核实际接受写入的证明。
- CPUIdle 自定义开关只在 `available_governors` 非空、`current_governor` 可写且配置值在可用列表中时显示；否则安装器关闭配置，WebUI 隐藏开关并报告不可用。
- Qualcomm DDR/LLCC 联动只在配置引用的四个 devfreq `min_freq` / `max_freq` 节点都存在且可读写时开放；缺项时安装器关闭配置、WebUI 隐藏开关及频率编辑器。Linux devfreq 是通用框架，但具体设备是否注册相应设备/路径取决于 OEM 内核，因此不能仅凭 SoC 型号宣称支持。
- WebUI 的频率与数值条仅用于显示；点按后在弹窗中选择。极速档频率上限自动校准并锁定为本机最高可用频点，不需要再次手动调整。
- 某 SoC 存在配置文件不代表已经完成该机型实测；OEM 内核可能合并/拆分 cpufreq policy，安装器会校验本机 policy。
- 正式模式只有 `powersave`、`balance`、`performance`、`fast`。`standby` 不受支持，调用会失败且保持现有模式和 GPU 状态不变；开机时遗留的未知档位会回到 `balance`。
- 超大核控制只会在设备实际提供独立最高性能 policy 时显示。三簇 SoC 的单核 Prime policy 在 UI 中显示为“超大核”，配置键沿用原始 BigCore 名称。
- GPU 场景联动只使用 `/sys/class/kgsl/kgsl-3d0/idle_timer`。15 个被安装器映射的 Qualcomm 配置包含各模式计时值，14 个 MediaTek 配置不包含该项；这只是配置覆盖情况，不代表所有 Qualcomm 设备都支持该节点。设备运行时会检查节点存在性及读写权限；不支持或不可读/写时不提供调节，模式切换也不会写入。WebUI 显示检测到的支持状态。
- I/O scheduler 由块设备队列和内核决定，不由 SoC 型号决定；安装器仅根据本机队列共同支持项配置一个全模式共用的兼容默认值。不同模式/SoC 没有可由配置文件单独证明的通用最佳 scheduler；需要针对目标设备及负载做 A/B 测试后再考虑按模式细分。
- 这些检测是安装时/打开 WebUI 时对本机 sysfs 的实时能力探测，并非 SoC 商品规格表。节点可读写不保证 SELinux、驱动或守护进程运行时接受目标值；运行时读回/日志才是实际应用证据。

## 上游接口依据
- [Linux blk-mq / I/O schedulers](https://docs.kernel.org/block/blk-mq.html)：调度器是块层按队列选择的运行时机制，不存在可从 SoC 名称推出的普适最优项。
- [Linux CPUIdle ABI](https://github.com/torvalds/linux/blob/master/Documentation/ABI/testing/sysfs-devices-system-cpu)：`available_governors` 报告可用列表，`current_governor` 是运行时切换接口；设备的实际导出仍需检查。
- [Linux devfreq framework](https://docs.kernel.org/driver-api/devfreq.html)：设备频率通过具体设备驱动注册的 sysfs 接口管理；框架存在不代表每台设备均导出同一路径。
- Bus_dcvs / LLCC / DDR 调整仅对配置提供对应节点的 SoC 展示；0 表示驱动自动管理。
- 不提供 FEAS/FAS 开关，不接管或关闭 MIUI 原生温控。
