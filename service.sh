#!/system/bin/sh
# 开机后作为延迟服务启动
MODDIR=${0%/*}
SD=/sdcard/Android/MW_CpuSpeedController
SERVICE_LOG="$SD/service.log"

log_service() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$SERVICE_LOG"
}

wait_until_login() {
  while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 0.5; done
  # 用户首次解锁前无 /sdcard 读写权限
  t=/sdcard/Android/.PERMISSION_TEST_GCTS
  true > "$t"
  while [ ! -f "$t" ]; do sleep 2; true > "$t"; done
  rm -f "$t"
}
wait_until_login
mkdir -p "$SD"
# The result is kernel/boot specific; probe again once after each reboot.
rm -f "$SD/gpu_idle_timer.unsupported"
chmod 0755 "$MODDIR"/vtools/*.sh "$MODDIR/MW_CpuSpeedController"
if ! cp -f "$MODDIR/vtools/powercfg.sh" /data/powercfg.sh; then
  log_service "无法部署 /data/powercfg.sh；停止启动以避免使用过期模式接口"
  exit 1
fi
if ! chmod 0755 /data/powercfg.sh; then
  log_service "无法设置 /data/powercfg.sh 执行权限"
  exit 1
fi
[ -f "$SD/config.txt" ] || echo balance > "$SD/config.txt"
# 开机后按当前档位同步 GPU 空闲保持时间；不修改 MIUI 温控。
current_mode=$(cat "$SD/config.txt" 2>/dev/null)
case "$current_mode" in
  powersave|balance|performance|fast)
    sh /data/powercfg.sh "$current_mode" >> "$SERVICE_LOG" 2>&1 ||
      log_service "模式/GPU 状态同步失败：$current_mode"
    ;;
  *)
    log_service "检测到非法或缺失模式 '${current_mode:-<empty>}'，恢复为 balance"
    sh /data/powercfg.sh balance >> "$SERVICE_LOG" 2>&1 ||
      log_service "非法模式恢复 balance 失败"
    if [ "$(cat "$SD/config.txt" 2>/dev/null)" != "balance" ]; then
      log_service "模式文件未能恢复为 balance；停止启动守护进程"
      exit 1
    fi
    ;;
esac

"$MODDIR/MW_CpuSpeedController" &
DPID=$!
sleep 3
if ! kill -0 "$DPID" 2>/dev/null; then
  wait "$DPID"
  first_status=$?
  log_service "调度守护进程启动失败（exit $first_status）；切换到 balance 并仅重试一次"
  sh /data/powercfg.sh balance >> "$SERVICE_LOG" 2>&1 ||
    log_service "启动失败后的 balance/GPU 恢复失败"
  if [ "$(cat "$SD/config.txt" 2>/dev/null)" != "balance" ]; then
    log_service "模式文件未能恢复为 balance；不重试启动守护进程"
    sh "$MODDIR/vtools/desc.sh"
    exit 1
  fi
  "$MODDIR/MW_CpuSpeedController" &
  DPID=$!
  sleep 3
  if ! kill -0 "$DPID" 2>/dev/null; then
    wait "$DPID"
    retry_status=$?
    log_service "balance 下重试启动仍失败（exit $retry_status）；未继续循环重启"
    sh "$MODDIR/vtools/desc.sh"
    exit "$retry_status"
  fi
  log_service "守护进程在 balance 下重试启动成功"
fi
sh "$MODDIR/vtools/desc.sh"
wait $DPID
sh "$MODDIR/vtools/desc.sh"
