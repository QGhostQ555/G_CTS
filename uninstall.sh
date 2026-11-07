killall -9 MW_CpuSpeedController 2>/dev/null
GPU_FREQ_RESTORE_FAILED=0
POWERCFG=/data/powercfg.sh
if [ ! -f "$POWERCFG" ]; then
  MODDIR=${0%/*}
  [ "$MODDIR" = "$0" ] && MODDIR=.
  POWERCFG="$MODDIR/vtools/powercfg.sh"
fi
# 卸载时恢复首次接管前的 KGSL idle_timer 原值。
[ -f "$POWERCFG" ] && sh "$POWERCFG" restore_gpu >/dev/null 2>&1
if [ -f "$POWERCFG" ]; then
  gpu_freq_result=$(sh "$POWERCFG" restore_gpu_freq 2>&1)
  gpu_freq_status=$?
  [ -n "$gpu_freq_result" ] && echo "$gpu_freq_result"
  if [ "$gpu_freq_status" -ne 0 ]; then
    GPU_FREQ_RESTORE_FAILED=1
    echo "警告：GPU 频率上下限未能恢复；原始值记录将保留供手动恢复。"
  fi
elif [ -s /sdcard/Android/MW_CpuSpeedController/gpu_freq.orig ]; then
  GPU_FREQ_RESTORE_FAILED=1
  echo "警告：无法找到模式脚本恢复 GPU 频率上下限；原始值记录将保留供手动恢复。"
fi
rm -rf /data/powercfg.sh /data/powercfg.json /data/powercfg
if [ "${GPU_FREQ_RESTORE_FAILED:-0}" -eq 1 ]; then
  echo "保留 /sdcard/Android/MW_CpuSpeedController/gpu_freq.orig。"
else
  rm -rf /sdcard/Android/MW_CpuSpeedController
fi
pm uninstall io.github.xsheeee.cs_controller >/dev/null 2>&1
echo "G_CTS 已卸载，请重启手机"
