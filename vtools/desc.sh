#!/system/bin/sh
# 刷新 module.prop 的 description：SoC · 机型 · 当前模式 · 守护进程状态
# 用法：desc.sh [module.prop 路径]
MODDIR=/data/adb/modules/MW_CpuTurboScheduler
PROP="${1:-$MODDIR/module.prop}"
SD=/sdcard/Android/MW_CpuSpeedController
[ -f "$PROP" ] || exit 0

mode="$(cat "$SD/config.txt" 2>/dev/null | tr -d '\r\n ')"
case "$mode" in
  powersave) mn=省电 ;; balance) mn=均衡 ;; performance) mn=性能 ;; fast) mn=极速 ;;
  "") mn=未知 ;; *) mn="$mode" ;;
esac
cpu="$(sed -n '/^\[meta\]/,/^\[/{s/^name[[:space:]]*=[[:space:]]*//p}' "$SD/config.ini" 2>/dev/null | head -n1 | tr -d '"\r')"
[ -z "$cpu" ] && cpu="未识别"
soc="$(getprop ro.soc.model)"
dev="$(getprop ro.product.marketname)"; [ -z "$dev" ] && dev="$(getprop ro.product.model)"
if pidof MW_CpuSpeedController >/dev/null 2>&1; then st=运行中; else st=未运行; fi

desc="$cpu"
[ -n "$soc" ] && desc="${desc}（${soc}）"
[ -n "$dev" ] && desc="${desc} · ${dev}"
desc="${desc} | 当前模式：${mn} | 守护进程：${st} | Ghost 基于 MoWei 二改"
desc="$(printf '%s' "$desc" | tr -d '&\\#\r\n')"
sed -i "s#^description=.*#description=${desc}#" "$PROP"
