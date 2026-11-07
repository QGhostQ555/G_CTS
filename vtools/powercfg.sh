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
gpu_freq_has_opp() {
  case " $GPU_FREQS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}
gpu_freq_write_pair_raw() {
  target_min=$1
  target_max=$2
  current_min=$(cat "$GPU_FREQ_MIN" 2>/dev/null)
  current_max=$(cat "$GPU_FREQ_MAX" 2>/dev/null)
  case "$current_min:$current_max:$target_min:$target_max" in
    *[!0-9:]*|:*|*::*|*:) return 1 ;;
  esac
  if [ "$target_min" -gt "$current_max" ]; then
    first_node=$GPU_FREQ_MAX; first_value=$target_max
    second_node=$GPU_FREQ_MIN; second_value=$target_min
  elif [ "$target_max" -lt "$current_min" ]; then
    first_node=$GPU_FREQ_MIN; first_value=$target_min
    second_node=$GPU_FREQ_MAX; second_value=$target_max
  else
    first_node=$GPU_FREQ_MAX; first_value=$target_max
    second_node=$GPU_FREQ_MIN; second_value=$target_min
  fi
  printf '%s\n' "$first_value" > "$first_node" 2>/dev/null || return 1
  [ "$(cat "$first_node" 2>/dev/null)" = "$first_value" ] || return 1
  printf '%s\n' "$second_value" > "$second_node" 2>/dev/null || return 1
  [ "$(cat "$second_node" 2>/dev/null)" = "$second_value" ]
}
gpu_freq_restore() {
  GPU_FREQ_DIR=/sys/class/kgsl/kgsl-3d0/devfreq
  GPU_FREQ_MIN="$GPU_FREQ_DIR/min_freq"
  GPU_FREQ_MAX="$GPU_FREQ_DIR/max_freq"
  original_file="$SD/gpu_freq.orig"
  if [ ! -s "$original_file" ]; then
    GPUF_RESULT="unchanged|没有已接管的 GPU 频率上下限"
    return 0
  fi
  if [ ! -r "$GPU_FREQ_MIN" ] || [ ! -w "$GPU_FREQ_MIN" ] ||
     [ ! -r "$GPU_FREQ_MAX" ] || [ ! -w "$GPU_FREQ_MAX" ]; then
    GPUF_RESULT="unavailable|KGSL GPU devfreq 上下限不可读写，未恢复"
    return 1
  fi
  IFS='|' read -r original_min original_max < "$original_file"
  case "$original_min:$original_max" in
    *[!0-9:]*|:*|*:) GPUF_RESULT="failed|已保存的 GPU 原始上下限格式无效"; return 1 ;;
  esac
  if gpu_freq_write_pair_raw "$original_min" "$original_max"; then
    rm -f "$original_file"
    GPUF_RESULT="restored|已恢复首次接管前的 GPU 频率上下限"
    return 0
  fi
  GPUF_RESULT="failed|恢复 GPU 原始上下限失败；当前读回 $(cat "$GPU_FREQ_MIN" 2>/dev/null)/$(cat "$GPU_FREQ_MAX" 2>/dev/null) Hz"
  return 1
}
gpu_freq_reject() {
  reason=$1
  recovery="未保存 GPU 上下限需要恢复"
  if [ -s "$original_file" ]; then
    gpu_freq_restore
    recovery=$GPUF_RESULT
  fi
  GPUF_RESULT="failed|$reason；$recovery"
  return 1
}
gpu_freq_apply() {
  mode=$1
  GPU_FREQ_DIR=/sys/class/kgsl/kgsl-3d0/devfreq
  GPU_FREQ_MIN="$GPU_FREQ_DIR/min_freq"
  GPU_FREQ_MAX="$GPU_FREQ_DIR/max_freq"
  GPU_FREQ_AVAIL="$GPU_FREQ_DIR/available_frequencies"
  original_file="$SD/gpu_freq.orig"
  file="$SD/config.ini"
  requested_min=$(ini_get "$file" "$mode" GpuMinFreq)
  requested_max=$(ini_get "$file" "$mode" GpuMaxFreq)
  if [ -z "$requested_min" ] && [ -z "$requested_max" ]; then
    GPUF_RESULT="not_configured|该配置未定义 GPU 频率上下限"
    return 0
  fi
  requested_min=${requested_min:-0}
  requested_max=${requested_max:-0}
  case "$requested_min:$requested_max" in
    *[!0-9:]*|:*|*:) gpu_freq_reject "GPU 频率配置必须是非负整数 Hz"; return 1 ;;
  esac
  if [ "$(ini_get "$file" function DisableQcomGpu)" = "true" ] &&
     { [ "$requested_min" -gt 0 ] || [ "$requested_max" -gt 0 ]; }; then
    gpu_freq_reject "禁用 GPU Boost 与 GPU 频率上下限控制冲突"
    return 1
  fi
  if [ "$requested_min" -eq 0 ] && [ "$requested_max" -eq 0 ] && [ ! -s "$original_file" ]; then
    GPUF_RESULT="automatic|本档保持设备默认 GPU 频率范围"
    return 0
  fi
  if [ "$requested_min" -eq 0 ] && [ "$requested_max" -eq 0 ]; then
    gpu_freq_restore
    return $?
  fi
  if [ ! -r "$GPU_FREQ_MIN" ] || [ ! -w "$GPU_FREQ_MIN" ] ||
     [ ! -r "$GPU_FREQ_MAX" ] || [ ! -w "$GPU_FREQ_MAX" ] ||
     [ ! -r "$GPU_FREQ_AVAIL" ]; then
    gpu_freq_reject "KGSL GPU devfreq 上下限或 OPP 列表不可读写"
    return 1
  fi
  GPU_FREQS=""
  for f in $(cat "$GPU_FREQ_AVAIL" 2>/dev/null); do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    GPU_FREQS="$GPU_FREQS $f"
  done
  [ -n "$GPU_FREQS" ] || { gpu_freq_reject "设备没有提供有效 GPU OPP 列表"; return 1; }
  if [ "$requested_min" -gt 0 ] && ! gpu_freq_has_opp "$requested_min"; then
    gpu_freq_reject "请求的 GPU 最低频率不在设备 OPP 列表中"
    return 1
  fi
  if [ "$requested_max" -gt 0 ] && ! gpu_freq_has_opp "$requested_max"; then
    gpu_freq_reject "请求的 GPU 最高频率不在设备 OPP 列表中"
    return 1
  fi
  if [ -s "$original_file" ]; then
    IFS='|' read -r original_min original_max < "$original_file"
    case "$original_min:$original_max" in
      *[!0-9:]*|:*|*:) GPUF_RESULT="failed|已保存的 GPU 原始上下限格式无效"; return 1 ;;
    esac
  else
    original_min=$(cat "$GPU_FREQ_MIN" 2>/dev/null)
    original_max=$(cat "$GPU_FREQ_MAX" 2>/dev/null)
    case "$original_min:$original_max" in
      *[!0-9:]*|:*|*:) GPUF_RESULT="failed|无法读取当前 GPU 频率上下限"; return 1 ;;
    esac
    tmp="$original_file.tmp.$$"
    if ! printf '%s|%s\n' "$original_min" "$original_max" > "$tmp" ||
       ! mv -f "$tmp" "$original_file"; then
      rm -f "$tmp"
      GPUF_RESULT="failed|无法保存首次接管前的 GPU 频率上下限"
      return 1
    fi
  fi
  target_min=$requested_min
  target_max=$requested_max
  [ "$target_min" -gt 0 ] || target_min=$original_min
  [ "$target_max" -gt 0 ] || target_max=$original_max
  if [ "$target_min" -gt "$target_max" ]; then
    gpu_freq_reject "GPU 最低频率不能高于最高频率"
    return 1
  fi
  if gpu_freq_write_pair_raw "$target_min" "$target_max"; then
    if [ "$requested_min" -eq 0 ] && [ "$requested_max" -eq 0 ]; then
      rm -f "$original_file"
      GPUF_RESULT="restored|已恢复首次接管前的 GPU 频率上下限"
    else
      GPUF_RESULT="applied|最低 $(cat "$GPU_FREQ_MIN" 2>/dev/null) Hz，最高 $(cat "$GPU_FREQ_MAX" 2>/dev/null) Hz"
    fi
    return 0
  fi
  current_min=$(cat "$GPU_FREQ_MIN" 2>/dev/null)
  current_max=$(cat "$GPU_FREQ_MAX" 2>/dev/null)
  rollback=failed
  gpu_freq_write_pair_raw "$original_min" "$original_max" && rollback=restored
  GPUF_RESULT="failed|GPU 频率写入/读回失败；原上下限恢复尝试=$rollback，当前=$current_min/$current_max Hz"
  return 1
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
  gpu_freq_apply "$requested"
  gpu_freq_status=$?
  printf 'MODE|%s|written\n' "$requested"
  printf 'GPU|%s\n' "$GPU_RESULT"
  printf 'GPUF|%s\n' "$GPUF_RESULT"
  if [ "$gpu_status" -ne 0 ]; then
    echo "档位 $requested 已写入，但 GPU idle_timer 未能应用；CPU 档位保持不变。" >&2
  fi
  if [ "$gpu_freq_status" -ne 0 ]; then
    echo "档位 $requested 已写入，但 GPU 频率上下限未能应用；请查看读回结果。" >&2
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
  restore_gpu_freq)
    gpu_freq_restore
    status=$?
    printf 'GPUF|%s\n' "$GPUF_RESULT"
    exit "$status"
    ;;
  apply_gpu)
    current_mode=$(tr -d '\r\n ' < "$SD/config.txt" 2>/dev/null)
    case "$current_mode" in powersave|balance|performance|fast) ;; *) current_mode=balance ;; esac
    gpu_freq_apply "$current_mode"
    status=$?
    printf 'GPUF|%s\n' "$GPUF_RESULT"
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
