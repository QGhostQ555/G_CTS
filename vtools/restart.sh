#!/system/bin/sh
# 请求开机服务安全重启守护进程；服务退出时会自动拉起并退避重试。
SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null)
[ -n "$SCRIPT_PATH" ] || SCRIPT_PATH="$0"
SCRIPT_DIR=${SCRIPT_PATH%/*}
MODDIR=${SCRIPT_DIR%/vtools}
SD=/sdcard/Android/MW_CpuSpeedController
BIN="$MODDIR/MW_CpuSpeedController"

fail() { echo "stopped: $*" >&2; exit 1; }
is_running_pid() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null || return 1
  case " $(pidof MW_CpuSpeedController 2>/dev/null) " in *" $1 "*) return 0 ;; esac
  return 1
}

[ -x "$BIN" ] || chmod 0755 "$BIN" 2>/dev/null
[ -x "$BIN" ] || fail "守护进程不存在或不可执行：$BIN"
mkdir -p "$SD" || fail "无法创建状态目录：$SD"
[ -f "$MODDIR/vtools/powercfg.sh" ] || fail "找不到模式应用脚本"
cp -f "$MODDIR/vtools/powercfg.sh" /data/powercfg.sh || fail "无法更新 /data/powercfg.sh"
chmod 0755 /data/powercfg.sh || fail "无法设置 /data/powercfg.sh 执行权限"
[ -s "$SD/config.txt" ] || echo balance > "$SD/config.txt"

old_pid=$(cat "$SD/daemon.pid" 2>/dev/null)
service_pid=$(cat "$SD/service.pid" 2>/dev/null)
supervisor=0
case "$service_pid" in
  ''|*[!0-9]*) ;;
  *)
    if kill -0 "$service_pid" 2>/dev/null &&
      [ -r "/proc/$service_pid/cmdline" ] &&
      tr '\000' ' ' < "/proc/$service_pid/cmdline" | grep -F "$MODDIR/service.sh" >/dev/null 2>&1; then
      supervisor=1
    fi
    ;;
esac

if [ "$supervisor" -eq 1 ]; then
  if is_running_pid "$old_pid"; then
    printf '%s\n' "$old_pid" > "$SD/daemon.restart.tmp" || fail "无法记录重启请求"
    mv -f "$SD/daemon.restart.tmp" "$SD/daemon.restart" || fail "无法提交重启请求"
    kill "$old_pid" 2>/dev/null || fail "无法停止旧守护进程 PID $old_pid"
    i=0
    while is_running_pid "$old_pid" && [ "$i" -lt 12 ]; do
      sleep 0.25
      i=$((i + 1))
    done
    if is_running_pid "$old_pid"; then
      kill -9 "$old_pid" 2>/dev/null || fail "无法结束旧守护进程 PID $old_pid"
    fi
  else
    printf 'restart\n' > "$SD/daemon.restart.tmp" || fail "无法记录重启请求"
    mv -f "$SD/daemon.restart.tmp" "$SD/daemon.restart" || fail "无法提交重启请求"
  fi

  i=0
  while [ "$i" -lt 60 ]; do
    new_pid=$(cat "$SD/daemon.pid" 2>/dev/null)
    if [ "$new_pid" != "$old_pid" ] && is_running_pid "$new_pid"; then
      [ "$(cat "$SD/daemon.restart" 2>/dev/null)" = "restart" ] && rm -f "$SD/daemon.restart"
      sh "$MODDIR/vtools/desc.sh" >/dev/null 2>&1
      echo "running"
      exit 0
    fi
    sleep 0.25
    i=$((i + 1))
  done
  fail "开机服务未能在 15 秒内重新启动守护进程"
fi

# 服务看护进程不存在时提供一次独立启动，避免 WebUI 的重启操作成为空操作。
killall MW_CpuSpeedController 2>/dev/null
i=0
while pidof MW_CpuSpeedController >/dev/null 2>&1 && [ "$i" -lt 12 ]; do
  sleep 0.25
  i=$((i + 1))
done
if pidof MW_CpuSpeedController >/dev/null 2>&1; then
  killall -9 MW_CpuSpeedController 2>/dev/null
fi
rm -f "$SD/daemon.pid"
setsid nohup "$BIN" >/dev/null 2>&1 &
i=0
while [ "$i" -lt 12 ]; do
  DPID=
  for pid in $(pidof MW_CpuSpeedController 2>/dev/null); do
    DPID=$pid
    break
  done
  if is_running_pid "$DPID"; then
    printf '%s\n' "$DPID" > "$SD/daemon.pid"
    sh "$MODDIR/vtools/desc.sh" >/dev/null 2>&1
    echo "running"
    exit 0
  fi
  sleep 0.25
  i=$((i + 1))
done
fail "守护进程未能启动，请查看 $SD/service.log"
