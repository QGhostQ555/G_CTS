#!/system/bin/sh
SD=${SD:-/sdcard/Android/MW_CpuSpeedController}
SYSROOT=${SYSROOT:-/sys}
CPUDIR=${CPUDIR:-$SYSROOT/devices/system/cpu}
BATTERY_DIR=${BATTERY_DIR:-$SYSROOT/class/power_supply/battery}
THERMALROOT=${THERMALROOT:-$SYSROOT/class/thermal}

usage() {
  echo "用法：ab_sample.sh <标签> [时长秒数=300] [采样间隔秒数=5]" >&2
  echo "标签仅可包含字母、数字、下划线和连字符；时长范围 60-86400 秒，间隔范围 1-600 秒。" >&2
}

normalize_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  normalized=$(printf '%s' "$1" | sed 's/^0*//')
  printf '%s\n' "${normalized:-0}"
}

csv_quote() {
  escaped=$(printf '%s' "$1" | sed 's/"/""/g')
  printf '"%s"' "$escaped"
}

csv_row() {
  separator=
  for field in "$@"; do
    printf '%s' "$separator"
    csv_quote "$field"
    separator=,
  done
  printf '\n'
}

read_value() {
  [ -r "$1" ] && tr -d '\r\n' < "$1" 2>/dev/null
}

sample() {
  now=$(date '+%Y-%m-%dT%H:%M:%S%z')
  now_epoch=$(date +%s)
  elapsed=$((now_epoch - start_epoch))
  mode=$(read_value "$SD/config.txt")
  capacity=$(read_value "$BATTERY_DIR/capacity")
  battery_temp=$(read_value "$BATTERY_DIR/temp")
  battery_status=$(read_value "$BATTERY_DIR/status")
  voltage=$(read_value "$BATTERY_DIR/voltage_now")
  current=$(read_value "$BATTERY_DIR/current_now")
  csv_row "$now" "$elapsed" "$tag" battery "$mode" "$capacity" "$battery_temp" "$battery_status" "$voltage" "$current" "" "" "" "" "" "" ""

  for policy_dir in "$CPUDIR"/cpufreq/policy*; do
    [ -d "$policy_dir" ] || continue
    policy=${policy_dir##*/}
    cpus=$(read_value "$policy_dir/related_cpus")
    current_freq=$(read_value "$policy_dir/scaling_cur_freq")
    max_freq=$(read_value "$policy_dir/scaling_max_freq")
    hw_max_freq=$(read_value "$policy_dir/cpuinfo_max_freq")
    governor=$(read_value "$policy_dir/scaling_governor")
    csv_row "$now" "$elapsed" "$tag" policy "$mode" "" "" "" "" "" "$policy" "$cpus" "$current_freq" "$max_freq" "$hw_max_freq" "$governor" ""
  done

  for zone_dir in "$THERMALROOT"/thermal_zone*; do
    [ -d "$zone_dir" ] || continue
    zone=${zone_dir##*/}
    zone_type=$(read_value "$zone_dir/type")
    zone_temp=$(read_value "$zone_dir/temp")
    [ -n "$zone_temp" ] || continue
    csv_row "$now" "$elapsed" "$tag" thermal "$mode" "" "" "" "" "" "$zone:$zone_type" "" "" "" "" "" "$zone_temp"
  done

  for throttle_file in "$CPUDIR"/cpu*/thermal_throttle/*; do
    [ -r "$throttle_file" ] || continue
    throttle_value=$(read_value "$throttle_file")
    [ -n "$throttle_value" ] || continue
    csv_row "$now" "$elapsed" "$tag" throttle "$mode" "" "" "" "" "" "$throttle_file" "" "" "" "" "" "$throttle_value"
  done
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then usage; exit 2; fi
tag=$1
case "$tag" in ''|*[!A-Za-z0-9_-]*) usage; exit 2 ;; esac
[ "${#tag}" -le 32 ] || { usage; exit 2; }

duration=$(normalize_uint "${2:-300}") || { usage; exit 2; }
interval=$(normalize_uint "${3:-5}") || { usage; exit 2; }
[ "${#duration}" -le 5 ] || { usage; exit 2; }
[ "${#interval}" -le 3 ] || { usage; exit 2; }
[ "$duration" -ge 60 ] && [ "$duration" -le 86400 ] || { usage; exit 2; }
[ "$interval" -ge 1 ] && [ "$interval" -le 600 ] && [ "$interval" -le "$duration" ] || { usage; exit 2; }

mkdir -p "$SD" || { echo "无法创建采样目录：$SD" >&2; exit 1; }
umask 077
start_epoch=$(date +%s)
case "$start_epoch" in ''|*[!0-9]*) echo "系统 date 无法提供 epoch 时间。" >&2; exit 1 ;; esac
stamp=$(date '+%Y%m%d-%H%M%S')
output="$SD/ab_${stamp}_${tag}.csv"
suffix=1
while [ -e "$output" ]; do
  output="$SD/ab_${stamp}_${tag}_${suffix}.csv"
  suffix=$((suffix + 1))
done

printf '%s\n' 'timestamp,elapsed_s,tag,record,mode,battery_capacity_pct,battery_temp_raw,battery_status,battery_voltage_raw,battery_current_raw,source,cpus,current_freq_raw,scaling_max_freq_raw,hardware_max_freq_raw,governor,value_raw' > "$output" ||
  { echo "无法创建采样文件：$output" >&2; exit 1; }
echo "采样文件：$output"
echo "标签=$tag 时长=${duration}s 间隔=${interval}s；仅读取设备状态，不切换模式或修改参数。"
trap 'exit 130' INT
trap 'exit 143' TERM

while :; do
  elapsed=$(($(date +%s) - start_epoch))
  [ "$elapsed" -le "$duration" ] || break
  sample >> "$output" || { echo "写入采样文件失败：$output" >&2; exit 1; }
  [ "$elapsed" -eq "$duration" ] && break
  sleep "$interval"
done

echo "采样完成：$output"
