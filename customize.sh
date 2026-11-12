#!/system/bin/sh
# G_CTS 安装脚本  ·  Ghost 基于 MoWei CpuTurboScheduler 二改
# 注：KSU / Magisk / APatch 安装器会 source 本文件，MODPATH 由安装器提供

SD=/sdcard/Android/MW_CpuSpeedController
CPUDIR=/sys/devices/system/cpu
# 与 get_config_name() 的实际映射保持一致，供安装提示使用
SUPPORTED_LIST="SDM660 SDM750G SDM765G SDM7G2+ SDM7G3+ SDM7sG2 SDM855 SDM865 SDM870 SDM888 SDM8Elite SDM8G1 SDM8G1+ SDM8G2 SDM8G3 MTK720 MTK1080 MTKG99 MTK1100 MTK1200 MTK8100 MTK8200 MTK8300 MTK8300Ultra MTK8400Ultra MTK9000 MTK9200+ MTK9300+ MTK9400+"
MODES="powersave balance performance fast"

command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
say() { ui_print "$1"; }


hr()  { say "──────────────────────────────"; }

# ───────────── 工具函数 ─────────────
prop() { getprop "$1"; }
num()  { v=$(cat "$1" 2>/dev/null); echo "${v:-0}"; }
get_maxfreq() { num "$CPUDIR/cpu$1/cpufreq/cpuinfo_max_freq"; }
get_socname() { cat /sys/devices/soc0/machine 2>/dev/null | tr '[A-Z]' '[a-z]'; }
soc_model()   { prop ro.soc.model; }
ghz() { v=$(($1 + 5000)); printf '%d.%02d' $((v / 1000000)) $(((v % 1000000) / 10000)); }   # kHz -> GHz(四舍五入到两位)

ini_get() {   # ini_get 文件 段 键
  sed -n "/^\[$2\]/,/^\[/p" "$1" | tr -d '\r' | sed -n "s/^$3[[:space:]]*=[[:space:]]*//p" | head -n1 | tr -d '"' | sed 's/[[:space:]]*$//'
}
ini_set() {   # ini_set 文件 段 键 新值   (仅替换数值/单词，保留行尾 CRLF 与引号)
  sed -i "/^\[$2\]/,/^\[/ s/^\($3[[:space:]]*=[[:space:]]*\)[^[:cntrl:]]*/\1$4/" "$1"
}
ini_ensure_zero() {
  file=$1 section=$2 key=$3
  [ -n "$(ini_get "$file" "$section" "$key")" ] && return 0
  tmp="${file}.tmp.$$"
  awk -v sec="[$section]" -v line="$key = 0" '
    { clean=$0; sub(/\r$/, "", clean); print }
    clean == sec { print line }
  ' "$file" > "$tmp" && mv -f "$tmp" "$file"
}
io_scheduler_options() { # 输出一个 I/O 队列支持的调度器列表，剥除当前项方括号
  for g in $(cat "$1" 2>/dev/null); do
    g=${g#\[}; g=${g%\]}
    [ -n "$g" ] && printf '%s ' "$g"
  done
}
snap_freq() { # snap_freq policy 目标kHz → 吸附到目标以下最近 OPP；低于最低 OPP 时取最低频点
  tbl=$(cat "$CPUDIR/cpufreq/policy$1/scaling_available_frequencies" 2>/dev/null)
  [ -z "$tbl" ] && { echo "$2"; return; }
  best=0; low=999999999
  for f in $tbl; do
    [ "$f" -le "$2" ] && [ "$f" -gt "$best" ] && best=$f
    [ "$f" -lt "$low" ] && low=$f
  done
  [ "$best" -eq 0 ] && best=$low
  echo "$best"
}
policy_maxfreq() {
  hw=$(num "$CPUDIR/cpufreq/policy$1/cpuinfo_max_freq")
  case "$hw" in ''|*[!0-9]*|0) ;; *) echo "$hw"; return ;; esac
  tbl=$(cat "$CPUDIR/cpufreq/policy$1/scaling_available_frequencies" 2>/dev/null)
  max=0
  for f in $tbl; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    [ "$f" -gt "$max" ] && max=$f
  done
  echo "$max"
}
cpus_of() { # policy → "0-2"
  l=$(cat "$CPUDIR/cpufreq/policy$1/related_cpus" 2>/dev/null)
  set -- $l; [ -z "$1" ] && return
  first=$1; last=$1; for c in "$@"; do last=$c; done
  [ "$first" = "$last" ] && echo "$first" || echo "$first-$last"
}

# ───────────── SoC 识别 ─────────────
_type_lahaina()   { [ "$(get_maxfreq 7)" -gt 2600000 ] && echo SDM888; }
_type_taro() {
  [ "$(get_maxfreq 7)" -le 2918400 ] && { echo "SDM7G2+"; return; }
  case "$(get_socname)" in
    cape|capep|ukee|ukeep) echo "SDM8G1+" ;;
    waipio|waipiop)        echo "SDM8G1" ;;
  esac
}
_type_kalama()    { echo SDM8G2; }                                  # kalama 仅有 SM8550 / SM8550-AB
_type_pineapple() {
  case "$(soc_model)" in
    SM8650*) echo SDM8G3; return ;;
    SM7675*|SM8635*) echo "SDM7G3+"; return ;;
  esac
  [ "$(get_maxfreq 7)" -le 3000000 ] && echo "SDM7G3+" || echo SDM8G3
}
_type_kona()      { [ "$(get_maxfreq 7)" -lt 3187000 ] && echo SDM865 || echo SDM870; }
_type_mt6893()    { [ "$(get_maxfreq 7)" -le 2600000 ] && echo MTK1100 || echo MTK1200; }
_type_mt6895()    { [ "$(get_maxfreq 7)" -lt 3100000 ] && echo MTK8100 || echo MTK8200; }

get_config_name() {
  case "$1" in
    pineapple) _type_pineapple ;;  kalama) _type_kalama ;;  taro) _type_taro ;;
    lahaina) _type_lahaina ;;      kona) _type_kona ;;      sun) echo SDM8Elite ;;
    SAIPAN) echo SDM765G ;;        sdm660|sdm636) echo SDM660 ;;
    SM7675) echo "SDM7G3+" ;;      msmnile) echo SDM855 ;;  parrot) echo "SDM7G2+" ;;
    bengal) echo SDM7sG2 ;;        SM7225) echo SDM750G ;;
    mt6853) echo MTK720 ;;  mt6893) _type_mt6893 ;;  mt6895) _type_mt6895 ;;
    mt6983) echo MTK9000 ;; mt6985) echo "MTK9200+" ;; mt6989) echo "MTK9300+" ;;
    mt6892) echo MTK8300 ;; mt6897) echo MTK8300Ultra ;; mt6899) echo MTK8400Ultra ;;
    k6991v1_64) echo "MTK9400+" ;; mt6877) echo MTK1080 ;; mt6789) echo MTKG99 ;;
    *) echo unsupported ;;
  esac
}

mode_cn() { case "$1" in powersave) echo 省电;; balance) echo 均衡;; performance) echo 性能;; fast) echo 极速;; esac; }

# ───────────── 安装流程 ─────────────
[ "$(id -u)" != "0" ] && { say "请以 root 权限安装"; exit 1; }

banner() {
  hr
  say "G_CTS $(grep_ver) · Ghost"
  hr
}
grep_ver() { sed -n 's/^version=//p' "$MODPATH/module.prop" | head -n1; }



device_info() {
  dev=$(prop ro.product.marketname); [ -z "$dev" ] && dev=$(prop ro.product.model)
  say "设备：$dev · SoC：$(soc_model) · Android $(prop ro.build.version.release)"
}


banner
device_info

target="$(prop ro.board.platform)"; cfgname="$(get_config_name "$target")"
if [ "$cfgname" = "unsupported" ] || [ -z "$cfgname" ]; then
  target="$(prop ro.product.board)"; cfgname="$(get_config_name "$target")"
fi
if [ "$cfgname" = "unsupported" ] || [ -z "$cfgname" ] || [ ! -f "$MODPATH/conf/$cfgname.ini" ]; then
  say " "; say "▌ 识别失败"
  say "  处理器 [$target] 暂不支持。"
  say "  当前安装脚本映射支持的配置："
  say "  配置代号：$SUPPORTED_LIST"
  abort "! 不支持的处理器：$target"
fi

SRC="$MODPATH/conf/$cfgname.ini"
cpu_name="$(ini_get "$SRC" meta name)"

say " "; say "▌ 处理器识别"
say "  型号     $cpu_name"
say "  配置档   $cfgname  （按本机 policy 校准）"
say "  以下频率单位为 GHz；档位值是允许上限，不代表 CPU 会持续运行在该频率。"

say " "; say "▌ 部署配置"
mkdir -p "$SD"
rm -f "$SD/Performance.conf" "$SD/Performance.conf.bak"
cp -f "$SRC" "$SD/config.ini"
echo "$cfgname" > "$MODPATH/profile"
for mode in $MODES; do
  ini_ensure_zero "$SD/config.ini" "$mode" GpuMinFreq ||
    abort "! 无法初始化 $mode GPU 最低频率配置"
  ini_ensure_zero "$SD/config.ini" "$mode" GpuMaxFreq ||
    abort "! 无法初始化 $mode GPU 最高频率配置"
done
say "  已复制 $cpu_name 的四档配置到 $SD/config.ini。"
say "  后续会按本机 CPU policy 校验簇映射，并校准各档频率上限。"

say " "
say "  ┌─ 本机能力检测 ──────────────────┐"
io_common=""; io_seen=0; io_queues=0; io_sched_ok=1; io_tune_ok=1; io_tuned=0
for queue in /sys/block/*/queue; do
  [ -d "$queue" ] || continue
  io_queues=$((io_queues + 1))
  q="$queue/scheduler"
  if [ ! -r "$q" ] || [ ! -w "$q" ]; then
    io_sched_ok=0
  else
    available="$(io_scheduler_options "$q")"
    [ -n "$available" ] || io_sched_ok=0
    if [ "$io_seen" -eq 0 ]; then
      io_common="$available"; io_seen=1
    else
      common_next=""
      for g in $io_common; do
        case " $available " in *" $g "*) common_next="$common_next $g" ;; esac
      done
      io_common="${common_next# }"
    fi
  fi
  if [ -r "$queue/iostats" ] && [ -w "$queue/iostats" ] &&
     [ -r "$queue/nomerges" ] && [ -w "$queue/nomerges" ]; then
    io_tuned=$((io_tuned + 1))
  else io_tune_ok=0
  fi
done
if [ "$io_queues" -eq 0 ] || [ "$io_sched_ok" -ne 1 ] || [ "$io_seen" -eq 0 ] || [ -z "$io_common" ]; then
  ini_set "$SD/config.ini" function AdjIOScheduler false
  io_summary="I/O scheduler：未全量支持/可写 · 开关关闭"
else
  io_pick=""
  for preferred in mq-deadline kyber bfq none; do
    case " $io_common " in *" $preferred "*) io_pick=$preferred; break ;; esac
  done
  [ -n "$io_pick" ] || io_pick=${io_common%% *}
  ini_set "$SD/config.ini" IO_Settings Scheduler "\"$io_pick\""
  io_summary="I/O scheduler：$io_queues 队列 · 自动 $io_pick"
fi
if [ "$io_queues" -eq 0 ] || [ "$io_sched_ok" -ne 1 ] || [ "$io_seen" -eq 0 ] || [ -z "$io_common" ] || [ "$io_tune_ok" -ne 1 ]; then
  ini_set "$SD/config.ini" IO_Settings IO_optimization false
  io_tune_summary="I/O 队列调优：scheduler 或 iostats/nomerges 未全量支持 · 开关关闭"
else
  io_tune_summary="I/O 队列调优：$io_tuned/$io_queues 队列节点可读写"
fi
idle_file="$CPUDIR/cpuidle/current_governor"
idle_available="$(cat "$CPUDIR/cpuidle/available_governors" 2>/dev/null)"
idle_current="$(cat "$idle_file" 2>/dev/null)"
idle_config="$(ini_get "$SD/config.ini" CpuIdle current_governor)"
case " $idle_available " in *" $idle_config "*) idle_choice_ok=1 ;; *) idle_choice_ok=0 ;; esac
if [ -z "$idle_available" ] || [ -z "$idle_current" ] || [ ! -w "$idle_file" ] || [ "$idle_choice_ok" -ne 1 ]; then
  ini_set "$SD/config.ini" function CpuIdleScaling_Governor false
  idle_summary="CPUIdle：无可写接口/配置值不支持 · 开关关闭"
else
  idle_summary="CPUIdle：可用项 $idle_available · 当前 $idle_current"
fi
bus_ok=1; bus_count=0
for key in CPUllccmin CPUllccmax CPUddrmin CPUddrmax; do
  node="$(ini_get "$SD/config.ini" Bus_dcvs "$key")"
  if [ -n "$node" ] && [ -r "$node" ] && [ -w "$node" ]; then
    bus_count=$((bus_count + 1))
  else bus_ok=0
  fi
done
[ "$bus_count" -eq 4 ] || bus_ok=0
if [ "$bus_ok" -ne 1 ]; then
  ini_set "$SD/config.ini" Other AdjQcomBus_dcvs false
  bus_summary="DDR/LLCC：配置引用节点未全量支持 · 开关关闭"
else
  bus_summary="DDR/LLCC：4 个配置节点可读写"
fi
gpu_node=/sys/class/kgsl/kgsl-3d0/idle_timer
if [ -r "$gpu_node" ] && [ -w "$gpu_node" ]; then
  gpu_current=$(tr -d '\r\n ' < "$gpu_node" 2>/dev/null)
  gpu_summary="KGSL idle_timer：支持 · 当前 ${gpu_current:-未知} ms"
elif [ -e "$gpu_node" ]; then
  gpu_summary="KGSL idle_timer：不可读/写 · 不提供调节"
else
  gpu_summary="KGSL idle_timer：不支持 · 不会写入"
fi
gpu_freq_dir=/sys/class/kgsl/kgsl-3d0/devfreq
gpu_freq_count=0
for f in $(cat "$gpu_freq_dir/available_frequencies" 2>/dev/null); do
  case "$f" in ''|*[!0-9]*) continue ;; esac
  gpu_freq_count=$((gpu_freq_count + 1))
done
if [ "$gpu_freq_count" -gt 1 ] &&
   [ -r "$gpu_freq_dir/min_freq" ] && [ -w "$gpu_freq_dir/min_freq" ] &&
   [ -r "$gpu_freq_dir/max_freq" ] && [ -w "$gpu_freq_dir/max_freq" ]; then
  gpu_freq_summary="KGSL GPU 频率：$gpu_freq_count 个可用频点 · 上下限节点可读写"
elif [ -e "$gpu_freq_dir/min_freq" ] || [ -e "$gpu_freq_dir/max_freq" ]; then
  gpu_freq_summary="KGSL GPU 频率：接口/频点不完整 · 不提供调节"
else
  gpu_freq_summary="KGSL GPU 频率：不支持 · 保持驱动控制"
fi
say "  │ $io_summary"
say "  │ $io_tune_summary"
say "  │ $idle_summary"
say "  │ $bus_summary"
say "  │ $gpu_summary"
say "  │ $gpu_freq_summary"
say "  └────────────────────────────────┘"

# 校验 CoreFramework：本机不存在的 policy 从配置中移除，避免「大核无频率」幽灵簇
# （部分 8Gen2 / OEM 内核不单独暴露 policy5，A710 可能并入其他 policy）
say " "; say "▌ CPU 簇与 policy 校验"
say "  policy 是内核实际控制的一组 CPU；同一 policy 内核心共用频率上下限。"
for nm in Small Medium Big SuperBig; do
  p="$(ini_get "$SD/config.ini" CoreFramework ${nm}CorePath)"
  [ -z "$p" ] && continue
  if [ ! -d "$CPUDIR/cpufreq/policy$p" ]; then
    say "  ! ${nm}CorePath=policy$p 本机不存在，已从配置移除"
    # 删除该键行（保留段头）
    sed -i "/^\[CoreFramework\]/,/^\[/ {/^${nm}CorePath[[:space:]]*=/d;}" "$SD/config.ini"
    for m in $MODES; do
      sed -i "/^\[$m\]/,/^\[/ {
        /^${nm}CoreMaxFreq[[:space:]]*=/d
        /^${nm}CoreMinFreq[[:space:]]*=/d
      }" "$SD/config.ini"
    done
  else
    say "  OK  ${nm} → policy$p  cpu$(cpus_of "$p")"
  fi
done

say " "; say "▌ CPU 频率校准"
say "  各档上限吸附到本机 OPP；极速档使用最高可用频点，不锁最低频。"
changed=0
for nm in Small Medium Big SuperBig; do
  p="$(ini_get "$SD/config.ini" CoreFramework ${nm}CorePath)"; [ -z "$p" ] && continue
  policy_dir="$CPUDIR/cpufreq/policy$p"
  cpus="$(cpus_of "$p")"
  opp="$(cat "$policy_dir/scaling_available_frequencies" 2>/dev/null)"
  opp_count=0; opp_low=0; opp_high=0
  for f in $opp; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    opp_count=$((opp_count + 1))
    if [ "$opp_low" -eq 0 ] || [ "$f" -lt "$opp_low" ]; then opp_low=$f; fi
    [ "$f" -gt "$opp_high" ] && opp_high=$f
  done
  fast_target="$(ini_get "$SD/config.ini" fast ${nm}CoreMaxFreq)"
  hw="$(policy_maxfreq "$p")"
  fast_known=1
  if [ "$hw" -gt 0 ] 2>/dev/null; then
    fast_target=$hw
  else
    fast_known=0
  fi
  fast_max=0
  for m in $MODES; do
    cur="$(ini_get "$SD/config.ini" $m ${nm}CoreMaxFreq)"; [ -z "$cur" ] && continue
    target=$cur
    [ "$m" = fast ] && target=$fast_target
    new="$(snap_freq "$p" "$target")"
    [ "$m" = fast ] && fast_max=$new
    if [ "$new" != "$cur" ]; then
      ini_set "$SD/config.ini" "$m" "${nm}CoreMaxFreq" "$new"; changed=$((changed + 1))
    fi
  done
  if [ "$opp_count" -gt 0 ]; then
    opp_summary="$opp_count OPP $(ghz "$opp_low")–$(ghz "$opp_high") GHz"
  elif [ "$fast_known" = 1 ]; then
    opp_summary="OPP 列表不可读"
  else
    opp_summary="最高频不可读"
  fi
  mode_line="    上限："
  for m in $MODES; do
    configured="$(ini_get "$SD/config.ini" "$m" ${nm}CoreMaxFreq)"
    [ -n "$configured" ] || continue
    case "$configured" in ''|*[!0-9]*) shown="$configured" ;; *) shown="$(ghz "$configured")" ;; esac
    mode_line="$mode_line $(mode_cn "$m") $shown"
    [ "$m" = fast ] && fast_max=$configured
  done
  say "  $nm/policy$p cpu${cpus:-?} · $opp_summary ·$mode_line GHz"
done
if [ "$changed" -gt 0 ]; then
  say "  已将 $changed 项配置频率吸附到本机 OPP。"
else
  say "  配置频率未发生调整（或设备频点信息不可用）；极速档已按可读到的最高频校准。"
fi
ini_set "$SD/config.ini" fast UclampTopAppMin 100
say "  极速档前台 uclamp.min=100；全档 CPU 最低频不锁定。"
# 调速器按每个实际控制簇校验；只有所有相关 policy 都支持 schedutil 时才安全回退。
say " "; say "▌ 调速器兼容性校验"
for m in $MODES; do
  g="$(ini_get "$SD/config.ini" "$m" scaling_governor)"
  unavailable=0; schedutil_ok=1
  for nm in Small Medium Big SuperBig; do
    p="$(ini_get "$SD/config.ini" CoreFramework ${nm}CorePath)"; [ -n "$p" ] || continue
    [ -d "$CPUDIR/cpufreq/policy$p" ] || continue
    avail="$(cat "$CPUDIR/cpufreq/policy$p/scaling_available_governors" 2>/dev/null)"
    if [ -z "$avail" ]; then schedutil_ok=0; continue; fi
    case " $avail " in *" $g "*) ;; *) unavailable=1 ;; esac
    case " $avail " in *" schedutil "*) ;; *) schedutil_ok=0 ;; esac
  done
  if [ "$unavailable" = 1 ] && [ "$schedutil_ok" = 1 ]; then
    ini_set "$SD/config.ini" "$m" scaling_governor schedutil
    say "  ! $(mode_cn "$m") 调速器 $g 在部分 policy 不可用，已回退 schedutil"
  elif [ "$unavailable" = 1 ]; then
    say "  ! $(mode_cn "$m") 调速器 $g 不可用，且 schedutil 并非所有 policy 都支持；请检查内核可用调速器列表，该档保留原配置"
  else
    say "  OK  $(mode_cn "$m") 调速器：$g"
  fi
done

cp -f "$SD/config.ini" "$MODPATH/config.default.ini"
     # WebUI「恢复出厂」使用

# 模式状态、Scene 接口
say " "; say "▌ 接口与状态"
killall -9 MW_CpuSpeedController 2>/dev/null
cur="$(cat "$SD/config.txt" 2>/dev/null)"
case "$cur" in powersave|balance|performance|fast) ;; *) echo balance > "$SD/config.txt"; cur=balance ;; esac
sh "$MODPATH/vtools/init_vtools.sh" "$MODPATH/module.prop"
say "  当前模式 $(mode_cn "$cur")（可在 WebUI 或 Scene 中切换）"
say "  配置已按本机 policy/OPP 校准；当前模式将在重启后的守护进程启动时应用。"
say "  省电优先请选择省电档；极速档开放全簇最高频，持续负载会增加耗电和发热。"
say "  MIUI/厂商温控保持启用；本模块不会关闭温控或锁定 CPU 最低频率。"
say "  已部署 /data/powercfg.sh 与 powercfg.json，Scene 可直接切换四档。"
sh "$MODPATH/vtools/desc.sh" "$MODPATH/module.prop" 2>/dev/null

rm -rf "$MODPATH/conf"
if command -v set_perm_recursive >/dev/null 2>&1; then
  set_perm_recursive "$MODPATH" 0 0 0755 0644 ||
    say "警告：递归权限设置失败，继续显式设置模块脚本权限"
fi
chmod 0755 "$MODPATH"/*.sh "$MODPATH"/vtools/*.sh "$MODPATH/MW_CpuSpeedController" ||
  abort "! 无法设置模块脚本与守护进程的执行权限"

say " "; hr
say "安装完成：SoC 配置、CPU policy、OPP 与调速器检查已结束。"
say "请重启设备后应用本次配置；WebUI 可查看频率、温度和模式状态。"
say "注意：安装配置不保证延长续航，实际效果取决于模式、负载、屏幕及网络。"

hr
