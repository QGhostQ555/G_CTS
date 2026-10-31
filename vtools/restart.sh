#!/system/bin/sh
# 重启调度守护进程（WebUI「保存并应用」调用），使新的 config.ini 立即生效
MODDIR=/data/adb/modules/MW_CpuTurboScheduler
SD=/sdcard/Android/MW_CpuSpeedController
BIN="$MODDIR/MW_CpuSpeedController"
[ -x "$BIN" ] || chmod 0755 "$BIN"

killall MW_CpuSpeedController 2>/dev/null
i=0; while pidof MW_CpuSpeedController >/dev/null 2>&1 && [ $i -lt 10 ]; do sleep 0.2; i=$((i + 1)); done
pidof MW_CpuSpeedController >/dev/null 2>&1 && killall -9 MW_CpuSpeedController 2>/dev/null
[ -s "$SD/config.txt" ] || echo balance > "$SD/config.txt"
setsid nohup "$BIN" >/dev/null 2>&1 &
sleep 1.5
if pidof MW_CpuSpeedController >/dev/null 2>&1; then echo running; else echo stopped; fi
sh "$MODDIR/vtools/desc.sh" >/dev/null 2>&1
