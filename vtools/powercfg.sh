#!/system/bin/sh
# Scene / WebUI 模式切换入口：powercfg.sh <powersave|balance|performance|fast|init>
# 必须原地写入 config.txt，不可 mv 替换（否则守护进程 inotify 监视的 inode 失效）
SD=/sdcard/Android/MW_CpuSpeedController
MOD=/data/adb/modules/MW_CpuTurboScheduler
DESC="$MOD/vtools/desc.sh"
IDLE_TIMER_READBACK_TOLERANCE_MS=10

# 仅操作 KGSL idle_timer；不触碰 thermal、GPU 频率上限或厂商性能服务。
ini_get() {
  file=$1 section=$2 key=$3
  [ -r "$file" ] || return 0
  awk -v sec="[$section]" -v key="$key" '
    $0 == sec { inside=1; next }
    /^\[/ { inside=0 }
    inside && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/["\r]/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$file"
}
timer_values_match() {
  actual=$1
  expected=$2
  case "$actual:$expected" in
    *[!0-9:]*|:*|*:) return 2 ;;
  esac
  actual=$(printf '%s' "$actual" | sed 's/^0*//')
  expected=$(printf '%s' "$expected" | sed 's/^0*//')
  actual=${actual:-0}
  expected=${expected:-0}
  delta=$((actual - expected))
  [ "$delta" -ge 0 ] || delta=$((-delta))
  [ "$delta" -le "$IDLE_TIMER_READBACK_TOLERANCE_MS" ]
}
gpu_idle_restore() {
  node=/sys/class/kgsl/kgsl-3d0/idle_timer
  if [ ! -e "$node" ]; then
    GPU_RESULT="unavailable|未发现 KGSL idle_timer 节点"
    return 0
  fi
  if [ ! -r "$node" ] || [ ! -w "$node" ]; then
    GPU_RESULT="unavailable|KGSL idle_timer 节点不可读或不可写，未修改"
    return 0
  fi
  if [ ! -s "$SD/gpu_idle_timer.orig" ]; then
    GPU_RESULT="unchanged|尚未保存原始值，未修改节点"
    return 0
  fi
  original=$(cat "$SD/gpu_idle_timer.orig" 2>/dev/null)
  if [ -z "$original" ]; then
    GPU_RESULT="failed|无法读取已保存的原始值"
    return 1
  fi
  if ! printf '%s\n' "$original" > "$node"; then
    readback=$(tr -d '\r\n ' < "$node" 2>/dev/null)
    GPU_RESULT="failed|内核拒绝恢复原值 ${original} ms；当前读回=${readback:-<unreadable>} ms"
    return 1
  fi
  readback=$(tr -d '\r\n ' < "$node" 2>/dev/null)
  if timer_values_match "$readback" "$original"; then
    if [ "$readback" = "$original" ]; then
      GPU_RESULT="restored|已恢复首次接管前的值 ${original} ms"
    else
      GPU_RESULT="restored|已恢复原值 ${original} ms；内核量化读回 ${readback} ms"
    fi
    return 0
  fi
  GPU_RESULT="failed|恢复原值 ${original} ms 后读回 ${readback:-<unreadable>} ms；超出 ${IDLE_TIMER_READBACK_TOLERANCE_MS} ms 误差"
  return 1
}
gpu_idle() {
  mode=$1
  node=/sys/class/kgsl/kgsl-3d0/idle_timer
  if [ ! -e "$node" ]; then
    GPU_RESULT="unavailable|未发现 KGSL idle_timer 节点"
    return 0
  fi
  if [ ! -r "$node" ] || [ ! -w "$node" ]; then
    GPU_RESULT="unavailable|KGSL idle_timer 节点不可读或不可写，未修改"
    return 0
  fi
  file="$SD/config.ini"
  ms=$(ini_get "$file" "$mode" GpuIdleTimerMs)
  case "$ms" in
    ''|*[!0-9]*)
      GPU_RESULT="not_configured|该 SoC 配置没有有效的 GpuIdleTimerMs"
      return 0
      ;;
  esac
  if [ -s "$SD/gpu_idle_timer.unsupported" ]; then
    GPU_RESULT="unsupported|本次启动已检测到内核忽略 idle_timer 写入；停止重复尝试"
    return 1
  fi
  if [ ! -s "$SD/gpu_idle_timer.orig" ]; then
    if ! cat "$node" > "$SD/gpu_idle_timer.orig" 2>/dev/null || [ ! -s "$SD/gpu_idle_timer.orig" ]; then
      rm -f "$SD/gpu_idle_timer.orig"
      GPU_RESULT="failed|无法保存首次接管前的 KGSL idle_timer"
      return 1
    fi
  fi
  if [ "$ms" -eq 0 ]; then
    gpu_idle_restore
  else
    previous=$(tr -d '\r\n ' < "$node" 2>/dev/null)
    if ! printf '%s\n' "$ms" > "$node"; then
      readback=$(tr -d '\r\n ' < "$node" 2>/dev/null)
      GPU_RESULT="failed|内核拒绝写入 ${ms} ms；当前读回=${readback:-<unreadable>} ms"
      return 1
    fi
    readback=$(tr -d '\r\n ' < "$node" 2>/dev/null)
    if timer_values_match "$readback" "$ms"; then
      if [ "$readback" = "$ms" ]; then
        GPU_RESULT="applied|${ms} ms"
      else
        GPU_RESULT="applied|请求 ${ms} ms；内核量化读回 ${readback} ms（误差 ≤ ${IDLE_TIMER_READBACK_TOLERANCE_MS} ms）"
      fi
      return 0
    fi
    if [ -n "$previous" ] && [ -n "$readback" ] && [ "$readback" = "$previous" ]; then
      detail="请求 ${ms} ms 后仍读回 ${readback:-<unreadable>} ms，节点未接受写入"
      printf '%s\n' "$detail" > "$SD/gpu_idle_timer.unsupported"
      GPU_RESULT="unsupported|$detail"
      return 1
    fi
    GPU_RESULT="failed|请求 ${ms} ms 后读回 ${readback:-<unreadable>} ms；超出 ${IDLE_TIMER_READBACK_TOLERANCE_MS} ms 误差"
    return 1
  fi
}

write_mode() {
  mkdir -p "$SD"
  requested=$1
  previous=$(tr -d '\r\n ' < "$SD/config.txt" 2>/dev/null)
  case "$previous" in
    powersave|balance|performance|fast) ;;
    *) previous=balance ;;
  esac

  if ! printf '%s\n' "$requested" > "$SD/config.txt"; then
    echo "无法写入当前模式文件：$SD/config.txt" >&2
    if printf '%s\n' "$previous" > "$SD/config.txt" 2>/dev/null &&
        [ "$(cat "$SD/config.txt" 2>/dev/null)" = "$previous" ]; then
      printf 'MODE|%s|rolled_back|%s\n' "$requested" "$previous"
    else
      printf 'MODE|%s|rollback_failed|%s\n' "$requested" "$previous"
      echo "当前模式文件写入失败，且无法恢复原档位 $previous。" >&2
    fi
    return 1
  fi
  touch "$SD/config.txt" 2>/dev/null || :
  chmod 0644 "$SD/config.txt" 2>/dev/null || :
  if [ "$(cat "$SD/config.txt" 2>/dev/null)" != "$requested" ]; then
    echo "当前模式写入后校验失败，尝试恢复原档位 $previous" >&2
    if printf '%s\n' "$previous" > "$SD/config.txt" 2>/dev/null &&
        [ "$(cat "$SD/config.txt" 2>/dev/null)" = "$previous" ]; then
      printf 'MODE|%s|rolled_back|%s\n' "$requested" "$previous"
    else
      printf 'MODE|%s|rollback_failed|%s\n' "$requested" "$previous"
      echo "无法恢复原档位 $previous，请检查 config.txt。" >&2
    fi
    return 1
  fi
  GPU_RESULT="not_run|未执行"
  gpu_idle "$requested"
  gpu_status=$?
  printf 'MODE|%s|written\n' "$requested"
  printf 'GPU|%s\n' "$GPU_RESULT"
  if [ "$gpu_status" -ne 0 ]; then
    echo "档位 $requested 已写入，但 GPU idle_timer 未能应用；CPU 档位保持不变。" >&2
  fi
  [ -x "$DESC" ] && (sh "$DESC" >/dev/null 2>&1 &)
  return 0
}

case "$1" in
  powersave|balance|performance|fast)
    write_mode "$1"
    exit $?
    ;;
  init)
    [ -s "$SD/config.txt" ] || write_mode balance
    exit $?
    ;;
  restore_gpu)
    gpu_idle_restore
    status=$?
    printf 'GPU|%s\n' "$GPU_RESULT"
    exit "$status"
    ;;
  "")
    cat "$SD/config.txt" 2>/dev/null
    ;;
  *)
    if [ "$1" = standby ]; then
      echo "standby 不受支持；当前档位与 GPU 状态未更改。请使用 powersave、balance、performance 或 fast。" >&2
    else
      echo "未知模式: $1" >&2
    fi
    exit 1
    ;;
esac
