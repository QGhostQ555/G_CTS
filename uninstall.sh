killall -9 MW_CpuSpeedController 2>/dev/null
# 卸载时恢复首次接管前的 KGSL idle_timer 原值。
[ -x /data/powercfg.sh ] && sh /data/powercfg.sh restore_gpu >/dev/null 2>&1
rm -rf /data/powercfg.sh /data/powercfg.json /data/powercfg
rm -rf /sdcard/Android/MW_CpuSpeedController
pm uninstall io.github.xsheeee.cs_controller >/dev/null 2>&1
echo "G_CTS 已卸载，请重启手机"
