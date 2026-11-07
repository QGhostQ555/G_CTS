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
SUPERVISOR_PID="$$"
printf '%s\n' "$SUPERVISOR_PID" > "$SD/service.pid"
DPID=
restore_legacy_app_affinity() {
  records=/data/local/tmp/gcts-app-affinity.records
  boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  legacy_pid="$(cat /data/local/tmp/gcts-app-affinity.pid 2>/dev/null)"
  case "$legacy_pid" in
    ''|*[!0-9]*) ;;
    *)
      legacy_cmd=
      [ -r "/proc/$legacy_pid/cmdline" ] &&
        legacy_cmd="$(tr '\000' ' ' < "/proc/$legacy_pid/cmdline" 2>/dev/null)"
      case "$legacy_cmd" in
        *app-affinity.sh*watch*)
          kill "$legacy_pid" 2>/dev/null
          tries=0
          while kill -0 "$legacy_pid" 2>/dev/null && [ "$tries" -lt 20 ]; do
            sleep 0.1
            tries=$((tries + 1))
          done
          if kill -0 "$legacy_pid" 2>/dev/null; then
            kill -9 "$legacy_pid" 2>/dev/null
            log_service "旧线程亲和性服务未响应退出信号，已强制停止"
          fi
          ;;
      esac
      ;;
  esac
  if [ -r "$records" ] && [ -n "$boot_id" ]; then
    while IFS='|' read -r pid tid start original state saved_boot; do
      case "$pid:$tid:$start" in
        *[!0-9:]*|'') continue ;;
      esac
      [ "$saved_boot" = "$boot_id" ] || continue
      case "$original" in
        ''|*[!0-9,-]*) continue ;;
      esac
      stat="/proc/$pid/task/$tid/stat"
      [ -r "$stat" ] || continue
      current="$(sed 's/^.*) //' "$stat" | awk '{print $20}')"
      [ "$current" = "$start" ] || continue
      taskset -pc "$original" "$tid" >/dev/null 2>&1 ||
        log_service "移除旧线程亲和性规则时恢复 TID $tid 失败"
    done < "$records"
  fi
  rm -f "$records" /data/local/tmp/gcts-app-affinity.pid \
    /data/local/tmp/gcts-app-affinity.status
  rm -f "$SD/app-affinity.conf" "$SD/app-affinity.discovered" \
    "$SD/app-affinity.log"
}
restore_legacy_app_affinity
remove_legacy_game_thread() {
  records=/data/local/tmp/gcts-game-thread.records
  boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  game_pid="$(cat /data/local/tmp/gcts-game-thread.pid 2>/dev/null)"
  case "$game_pid" in
    ''|*[!0-9]*) ;;
    *)
      game_cmd=
      [ -r "/proc/$game_pid/cmdline" ] &&
        game_cmd="$(tr '\000' ' ' < "/proc/$game_pid/cmdline" 2>/dev/null)"
      case "$game_cmd" in
        *game-thread.sh*watch*)
          kill "$game_pid" 2>/dev/null
          tries=0
          while kill -0 "$game_pid" 2>/dev/null && [ "$tries" -lt 20 ]; do
            sleep 0.1
            tries=$((tries + 1))
          done
          if kill -0 "$game_pid" 2>/dev/null; then
            kill -9 "$game_pid" 2>/dev/null
            log_service "旧游戏线程服务未响应退出信号，已强制停止"
          fi
          ;;
      esac
      ;;
  esac
  if [ -r "$records" ] && [ -n "$boot_id" ]; then
    while IFS='|' read -r pid tid start original saved_boot state group applied; do
      case "$pid:$tid:$start" in
        *[!0-9:]*|'') continue ;;
      esac
      [ "$saved_boot" = "$boot_id" ] || continue
      case "$original" in
        ''|*[!0-9,-]*) continue ;;
      esac
      stat="/proc/$pid/task/$tid/stat"
      [ -r "$stat" ] || continue
      current="$(sed 's/^.*) //' "$stat" | awk '{print $20}')"
      [ "$current" = "$start" ] || continue
      taskset -pc "$original" "$tid" >/dev/null 2>&1 ||
        log_service "移除旧游戏线程亲和性规则时恢复 TID $tid 失败"
    done < "$records"
  fi
  rm -f "$records" /data/local/tmp/gcts-game-thread.pid \
    /data/local/tmp/gcts-game-thread.status
  rm -f "$SD/game-thread.enabled" "$SD/game-thread.rules" "$SD/game-thread.log"
}
remove_legacy_game_thread
cleanup_service() {
  if [ -n "$DPID" ]; then
    kill "$DPID" 2>/dev/null
    wait "$DPID" 2>/dev/null
    [ "$(cat "$SD/daemon.pid" 2>/dev/null)" = "$DPID" ] && rm -f "$SD/daemon.pid"
  fi
  [ "$(cat "$SD/service.pid" 2>/dev/null)" = "$SUPERVISOR_PID" ] && rm -f "$SD/service.pid"
}
trap cleanup_service 0
trap 'exit 0' HUP INT TERM
# The result is kernel/boot specific; probe again once after each reboot.
rm -f "$SD/gpu_idle_timer.unsupported"
rm -f "$SD/daemon.restart"
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

restart_delay=2
while :; do
  if [ "$(cat "$SD/daemon.restart" 2>/dev/null)" = "restart" ]; then
    rm -f "$SD/daemon.restart"
    restart_delay=2
    log_service "收到 WebUI 重启请求，立即启动守护进程"
  fi

  "$MODDIR/MW_CpuSpeedController" &
  DPID=$!
  printf '%s\n' "$DPID" > "$SD/daemon.pid"
  sleep 3

  if kill -0 "$DPID" 2>/dev/null; then
    log_service "调度守护进程运行中（PID $DPID）"
    sh "$MODDIR/vtools/desc.sh"
    if [ "$(cat "$SD/daemon.restart" 2>/dev/null)" = "restart" ]; then
      rm -f "$SD/daemon.restart"
      kill "$DPID" 2>/dev/null
    fi
    wait "$DPID"
    daemon_status=$?
  else
    wait "$DPID"
    daemon_status=$?
    log_service "调度守护进程启动失败（exit $daemon_status）"
  fi

  [ "$(cat "$SD/daemon.pid" 2>/dev/null)" = "$DPID" ] && rm -f "$SD/daemon.pid"
  restart_request=$(cat "$SD/daemon.restart" 2>/dev/null)
  if [ "$restart_request" = "$DPID" ] || [ "$restart_request" = "restart" ]; then
    rm -f "$SD/daemon.restart"
    log_service "收到 WebUI 重启请求，重新启动守护进程"
    restart_delay=2
    continue
  fi

  log_service "守护进程意外退出（exit $daemon_status）；切换到 balance 后自动重试"
  sh /data/powercfg.sh balance >> "$SERVICE_LOG" 2>&1 ||
    log_service "异常退出后的 balance/GPU 恢复失败"
  if [ "$(cat "$SD/config.txt" 2>/dev/null)" != "balance" ]; then
    log_service "模式文件未能恢复为 balance；等待后重试恢复"
  fi
  sh "$MODDIR/vtools/desc.sh"
  log_service "${restart_delay} 秒后重试守护进程"
  waited=0
  expedite_restart=0
  while [ "$waited" -lt "$restart_delay" ]; do
    if [ "$(cat "$SD/daemon.restart" 2>/dev/null)" = "restart" ]; then
      rm -f "$SD/daemon.restart"
      expedite_restart=1
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  if [ "$expedite_restart" -eq 1 ]; then
    restart_delay=2
    continue
  fi
  [ "$restart_delay" -lt 60 ] && restart_delay=$((restart_delay * 2))
  [ "$restart_delay" -gt 60 ] && restart_delay=60
done
