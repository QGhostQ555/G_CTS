# G_CTS

[简体中文](#简体中文) · [English](#english) · [完整中文说明](./README.zh-CN.md)

## 简体中文

G_CTS 是面向 Android Root 模块管理器的 CPU 调度模块，基于 MoWei CpuTurboScheduler 二次开发，提供四档调度、设备级 OPP 校准、WebUI、Scene 模式接口和守护进程异常恢复。

> **重要：**不同设备的内核、温控、负载和厂商策略会影响效果。本模块不关闭厂商温控、不锁定 CPU 最低频率，也不保证所有设备都能省电或提升性能。

### 功能概览

- 四种模式：省电、均衡、性能、极速。极速档按本机检测到的最高频点开放上限，不强制 CPU 持续满频。
- 安装时检测 CPUFreq policy、CPU 核心映射、OPP 和 governor，并按设备能力校准配置。
- WebUI 显示实时频率、模式上限、电池/温度信息，并提供参数编辑、日志、备份和恢复。
- I/O、CPUIdle、cpuset、Qualcomm DDR/LLCC 等选项依据设备实际接口决定是否可用。
- 开机服务持续看护调度守护进程；异常退出时回退到均衡档，并进行退避重试。

### 下载与安装

从 [Releases](https://github.com/QGhostQ555/G_CTS/releases) 下载 `G_CTS-v6.1.13-Ghost.zip`，使用 Magisk、KernelSU 或 APatch 等兼容的 Root 模块管理器刷入，并按安装提示重启。该 ZIP 是 Root 模块包，不是 APK。

### 实测设备

- POCO F6 Pro（Snapdragon 8 Gen 2）
- POCO F3（Snapdragon 870）

“实测”表示模块曾在设备上运行，不代表所有模式、参数和长时间续航均完成标准化 A/B 测试。详细文件说明、WebUI 交互、参数表、SoC 配置及兼容边界见[完整中文说明](./README.zh-CN.md)。

### 致谢

感谢小疣然分享 SoC 配置参考；项目基于 [MoWei CpuTurboScheduler](https://github.com/MoWei-2077/MW_CpuTurboScheduler) 二次开发。

## English

G_CTS is an Android CPU scheduling root module derived from [MoWei CpuTurboScheduler](https://github.com/MoWei-2077/MW_CpuTurboScheduler), rewritten and extended by Ghost. It installs through Magisk-compatible module installers and provides a WebUI plus a Scene-compatible mode interface.

> The module does not guarantee longer battery life or higher performance on every device. SoC profiles are starting points, not per-device benchmark claims. OEM kernels, thermal policy, workload, and other system services affect the result. The module does not disable vendor thermal protection or lock CPU minimum frequencies.

## Features

- Four selectable CPU profiles: `powersave`, `balance`, `performance`, and `fast`.
- Detects the device's CPUFreq policies and available operating points (OPPs); install-time calibration snaps profile frequency caps to device-supported values.
- `fast` uses each detected policy's highest readable frequency as its maximum cap and sets the foreground app `uclamp.min` to 100. It does not force the CPU to stay at maximum frequency.
- WebUI displays device, profile, CPU policy, current frequency, configured cap, battery and temperature readings where available.
- WebUI can edit profile parameters, cpusets, I/O settings, CPUIdle governor, and other settings when device capability checks pass.
- Mode changes can be made from the WebUI or the deployed Scene interface at `/data/powercfg.sh`.
- Capability checks are based on the device's live sysfs nodes and permissions. A writable node does not prove that the kernel or driver accepts a requested value.

## Installation

1. Download the release ZIP and install it with a supported root-module manager.
2. Reboot when installation completes so the module service can initialize.
3. Open the WebUI or Scene and select a mode.
4. Review the installation report for detected CPU policies, OPP calibration, and optional feature availability.

The project ZIP is a root-module package, not an ordinary Android application APK. Back up the existing configuration before replacing an installed build. Do not combine it with other tools that write the same CPUFreq, cpuset, I/O, or KGSL nodes unless you understand how their settings interact.

## WebUI interaction

### Navigation

- **Scheduling**: shows device identity, current mode, mode cards, live policy frequencies, battery and temperature values where readable.
- **Tuning**: has **Mode parameters** and **Global features** tabs.
- **Logs**: displays the daemon log and exposes the available log actions.
- **Settings**: contains module configuration, backup/restore, daemon restart, and appearance preferences.

### Mode cards

- Selecting a different mode writes the request through `/data/powercfg.sh`, which updates the mode state file and applies the configured KGSL idle timer when the kernel supports it.
- The UI then polls the daemon and CPUFreq policy limits to report the actual mode and limit-check result. A successful mode-file write does not by itself prove every parameter was applied.
- Tapping the already-selected mode does not request another transition; it only re-renders the selected state.
- The selected card keeps its mode color after touch/hover. The **Undo** action in the result notification requests the previous mode.
- `standby` is not a supported mode.

### Editing and saving

- Numeric fields and frequency sliders are read-only displays. Tap one to choose a value in a dialog; no drag slider is shown.
- The WebUI marks unsaved edits and provides **Save and apply**, **Discard**, and a navigation badge.
- Saving writes `config.ini`, retains the previous configuration as `config.ini.last`, and restarts the daemon so it can reload settings.
- Before saving, the UI validates device-dependent I/O, CPUIdle, queue-tuning, and DDR/LLCC settings against the latest capability report.
- Demo mode is for desktop preview only. It simulates data and does not change a real device.

## Configuration reference

The installed active configuration is `/sdcard/Android/MW_CpuSpeedController/config.ini`. The selected mode is stored separately in `config.txt`. Values in the SoC profiles under `conf/` are defaults; the installer may adjust them for the actual device.

| Section / key | Meaning |
|---|---|
| `[meta]` | Profile name, author, schema version, and daemon log level. Keep `configVersion` compatible with the bundled daemon. |
| `[function]` | Feature switches such as `EasScheduler`, `cpuset`, `LoadBalancing`, `AdjIOScheduler`, `LaunchBoost`, `AffintySetter`, `DisableQcomGpu`, and `CpuIdleScaling_Governor`. A switch only applies if its implementation and device interfaces are available. |
| `[CoreFramework]` | Maps logical clusters (`Small`, `Medium`, `Big`, `SuperBig`) to kernel CPUFreq policy IDs through `*CorePath`. The installer removes mappings for policies absent on the device. |
| `[powersave]`, `[balance]`, `[performance]`, `[fast]` | Per-mode governor, maximum/minimum CPU frequencies, uclamp bounds, rate limits, UFS/network toggles, and optional GPU idle timer. |
| `*CoreMaxFreq` | Maximum allowed frequency for a mapped policy, in kHz. Profile values are snapped down to a supported OPP when the OPP list is available. `fast` is calibrated to the highest readable frequency. |
| `*CoreMinFreq` | Minimum frequency in kHz. `0` means do not impose a minimum. This module's default profiles leave minimum frequencies unlocked. |
| `UclampTopApp*`, `UclampForeGround*`, `UclampBackGround*` | Per-mode utilization clamp minimum/maximum values, in the configuration's 0–100 scale. `UclampTopApplatency_sensitive` controls the foreground latency-sensitive flag where supported. |
| `ParamSchedPath` and `ParamSched1`–`ParamSched12` | Map numbered values to governor-specific sysfs parameter names. A parameter is meaningful only if the selected governor/kernel exposes that node. Rate-limit values are in microseconds. |
| `[Cpuset]` | CPU lists for `top_app`, `foreground`, `restricted`, `system_background`, and `background`; values use Linux CPU-list notation such as `0-3,6`. |
| `[IO_Settings] Scheduler` | One I/O scheduler choice applied globally to supported block queues. The installer picks a default from the intersection supported by all detected queues. It does not imply a workload-specific performance winner. |
| `[IO_Settings] IO_optimization` | Enables the daemon's queue tuning only when the required queue nodes (`iostats` and `nomerges`) are available and writable on all detected queues. |
| `[CpuIdle] current_governor` | Requested CPUIdle governor. The available list and writable control node are checked on the actual device. |
| `[Bus_dcvs]` and `[Other] AdjQcomBus_dcvs` | Qualcomm DDR/LLCC devfreq paths and feature switch, where a profile defines them. A value of `0` in a mode means leave the frequency under driver control. |
| `[LaunchBoost]` | App-launch boost duration (`BoostRateMs`), frequency multiplier (`FreqMulti`), and foreground uclamp minimum (`UclampTopAppBoostMin`). |
| `ufsClkGate`, `NetWorkOpt` | Per-mode UFS clock-gating and network optimization flags interpreted by the daemon when supported. |
| `GpuIdleTimerMs` | Optional KGSL idle timer request in milliseconds. `0` requests restoration of the value captured before the module first took control. Actual behavior is kernel-specific and verified by reading the node back. |

Do not copy a profile's bus paths or governor parameters to another device without checking its sysfs interfaces. Sysfs availability and permission checks are preconditions, not proof of runtime acceptance. If a value is rejected or left unchanged, trust the reported readback rather than the requested setting.

## Device profiles

`conf/` contains the profile INI files selected by the installer's SoC detection logic:

`MTK720.ini`, `MTKG99.ini`, `MTK1080.ini`, `MTK1100.ini`, `MTK1200.ini`, `MTK8100.ini`, `MTK8200.ini`, `MTK8300.ini`, `MTK8300Ultra.ini`, `MTK8400Ultra.ini`, `MTK9000.ini`, `MTK9200.ini`, `MTK9200+.ini`, `MTK9300+.ini`, `MTK9400+.ini`, `SDM660.ini`, `SDM750G.ini`, `SDM765G.ini`, `SDM7G2+.ini`, `SDM7G3.ini`, `SDM7G3+.ini`, `SDM7sG2.ini`, `SDM855.ini`, `SDM865.ini`, `SDM870.ini`, `SDM888.ini`, `SDM8G1.ini`, `SDM8G1+.ini`, `SDM8G2.ini`, `SDM8G3.ini`, and `SDM8Elite.ini`.

The filename indicates the installer's selected profile, not a guarantee that every phone using that SoC has identical CPU policies, OPPs, sysfs paths, or behavior. See [SUPPORTED_SOC.md](./SUPPORTED_SOC.md) for mapping and device-detection details.

## Repository file guide

### Module root

| File | Purpose |
|---|---|
| `module.prop` | Root-module identity, version, author, and manager-visible summary. |
| `customize.sh` | Installer: selects a SoC profile, copies/calibrates configuration, checks policies and device capabilities, reports results, and prepares module state. |
| `service.sh` | Post-boot service: deploys the Scene interface, synchronizes mode/GPU settings, and supervises the daemon with balance fallback and bounded retry backoff. |
| `uninstall.sh` | Stops the daemon, attempts to restore the saved KGSL idle timer, and removes module state and deployed Scene files. |
| `MW_CpuSpeedController` | Prebuilt native scheduler daemon. A pinned upstream source snapshot is included under `third_party/`; the exact build provenance of this binary should still be confirmed. |
| `SUPPORTED_SOC.md` | Profile mapping, calibration behavior, capability-detection rules, and kernel-interface caveats. |
| `TUNING_RESEARCH.md` | Controlled device A/B procedure, sampling guidance, and interpretation boundaries. |
| `调度说明.md` | Chinese technical guide to modes, profile assumptions, and known device/kernel limitations. |
| `updateLog.txt` | Version history and implementation notes. |

### `conf/`

The 31 `*.ini` files listed in **Device profiles** define the defaults for each mapped SoC family. Their shared schema is described in **Configuration reference**. They are templates; installer calibration and runtime device support take precedence.

### `vtools/`

| File | Purpose |
|---|---|
| `powercfg.sh` | Mode interface used by the WebUI and Scene. Validates mode requests, writes the active mode, applies/verifies optional KGSL idle timer settings, and reports the result. |
| `gen_json.sh` | Generates Scene's `powercfg.json` metadata from `module.prop`. |
| `init_vtools.sh` | Deploys the Scene JSON and `powercfg.sh` into `/data` and initializes the shared mode state. |
| `desc.sh` | Updates the root-manager module description with device, active mode, and daemon state. |
| `restart.sh` | Requests a supervised daemon restart and verifies the new process; provides a detached fallback when the service supervisor is unavailable. |
| `ab_sample.sh` | Read-only A/B sampler for battery, temperature, policy, and available throttling counters; it does not change modes or settings. |

### `webroot/`

| File | Purpose |
|---|---|
| `index.html` | WebUI document shell, navigation containers, and local script/style entry points. |
| `app.js` | Main UI state, KernelSU shell bridge, capability parsing, rendering, mode switching, configuration editing, save/restore, and diagnostics. |
| `styles.css` | Responsive Material 3 visual system, mode colors, cards, dialogs, controls, and touch interaction behavior. |
| `soc-data.js` | SoC display names, cluster topology and fallback CPU policy metadata used by the UI. |
| `demo.js` | Desktop-only simulated backend used when no KernelSU bridge is present; never applies settings to a device. |

### `META-INF/`

| File | Purpose |
|---|---|
| `META-INF/com/google/android/update-binary` | Recovery installer entry point. |
| `META-INF/com/google/android/updater-script` | Recovery script marker. |

## KGSL idle timer and Snapdragon 870

KGSL `idle_timer` is an optional kernel sysfs interface, not a regular file that a root module can replace by mounting another file. On the POCO F3 screenshot scenario, requests for 150/300/800 ms read back as the unchanged 60 ms. A public SM8250 source branch contains a KGSL timer store path that returns before applying the value; if the device kernel has this behavior, only a driver/kernel fix can make the control effective.

The module detects an unchanged readback, stops repeating the write for the current boot, and reports the feature as unavailable. It retries detection after the next boot. It does not bypass SELinux, overwrite thermal policy, or force writes to undocumented GPU nodes.

## Diagnostics and A/B testing

Use the module's install report and UI capability messages to understand what the current device exposes. For performance/power claims, change one factor at a time and follow [TUNING_RESEARCH.md](./TUNING_RESEARCH.md). The optional sampler is observational only; it is not a benchmark and does not establish causality by itself.

## License and source availability

The upstream project identifies its license as GNU GPL version 3. This repository includes the upstream `LICENSE` and a pinned source snapshot in `third_party/`; the snapshot commit is recorded in its filename. The exact build provenance of the prebuilt daemon should still be confirmed by the release maintainer. Keep original author attribution and notices and ensure that the distributed source corresponds to the binary.

Upstream project: [MoWei-2077/MW_CpuTurboScheduler](https://github.com/MoWei-2077/MW_CpuTurboScheduler).
