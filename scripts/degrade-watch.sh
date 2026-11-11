#!/usr/bin/env bash
# degrade-watch.sh — 定期快照「厂商配置 / 频率上限 / 电池容量 / 音量下限」，用于判断是否存在长期劣化
#
#   ./degrade-watch.sh            # 采一次，追加到 history.tsv，明细写到 snapshots/<ts>/
#   SERIAL=xxx ./degrade-watch.sh
#
# 每次只读，不改设备。连续采 3–7 天后再看 history.tsv 的趋势列才有意义。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/../snapshots"
HIST="$OUT/history.tsv"
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
ADB="adb -s $SERIAL"
SU() { $ADB shell "su -c '$*'" 2>/dev/null </dev/null; }
TS=$(date '+%Y%m%d-%H%M%S')
mkdir -p "$OUT/$TS"

# 1. 频率上限：每个 cluster 的 cur / scaling_max / 硬件上限
cpus=$(seq 0 7)
freq_rows=""
for c in $cpus; do
  cur=$(SU "cat /sys/devices/system/cpu/cpu$c/cpufreq/scaling_cur_freq")
  mx=$(SU "cat /sys/devices/system/cpu/cpu$c/cpufreq/scaling_max_freq")
  hw=$(SU "cat /sys/devices/system/cpu/cpu$c/cpufreq/cpuinfo_max_freq")
  freq_rows+="cpu$c ${cur:-?} ${mx:-?} ${hw:-?}"$'\n'
done
printf 'cpu cur scaling_max hw_max\n%s' "$freq_rows" > "$OUT/$TS/cpu-freq.txt"

# 2. 电池：容量 / 循环 / 健康
bat=""
for f in charge_full charge_full_design cycle_count health capacity status temp voltage_now; do
  bat+="$f $(SU "cat /sys/class/power_supply/battery/$f")"$'\n'
done
printf '%s' "$bat" > "$OUT/$TS/battery.txt"

# 3. msc.* 全部配置键（音量/相机/电源/性能都在这）
$ADB shell getprop 2>/dev/null | grep '^\[msc\.' > "$OUT/$TS/msc-props.txt"

# 4. 音量上限与当前值
$ADB shell 'dumpsys audio' 2>/dev/null | grep -E "^- STREAM_|^   Max:|^   Min:|^   streamVolume:" > "$OUT/$TS/audio-volumes.txt"

# 5. 相机能力 vs 配置
$ADB shell 'dumpsys media.camera' 2>/dev/null \
  | grep -A1 -E "pixelArraySize \(f0006\)|superResolutionPictureSize|videoResolutionFpsSupported \(807e0005\)" \
  > "$OUT/$TS/camera-caps.txt"

# 6. 当天热记录 DB（含 cpu 频率/亮度/音量/温度/场景）
SU "cp /data/data/com.hihonor.powergenie/databases/secethermal/thermal_trace_sece.db /data/local/tmp/_tt.db; chmod 644 /data/local/tmp/_tt.db" >/dev/null
$ADB pull /data/local/tmp/_tt.db "$OUT/$TS/thermal_trace_sece.db" >/dev/null 2>&1 || true

# 7. 一行趋势
cpu7mx=$(printf '%s' "$freq_rows" | awk '$1=="cpu7"{print $3}')
cpu7hw=$(printf '%s' "$freq_rows" | awk '$1=="cpu7"{print $4}')
cf=$(SU "cat /sys/class/power_supply/battery/charge_full")
cfd=$(SU "cat /sys/class/power_supply/battery/charge_full_design")
cyc=$(SU "cat /sys/class/power_supply/battery/cycle_count")
vol_music=$(printf '%s' "$(cat "$OUT/$TS/audio-volumes.txt")" | sed -n '/^- STREAM_MUSIC:/,/^- STREAM_/p' | sed -n 's/^   streamVolume://p' | tr -d ' ')
vol_ring=$(printf '%s' "$(cat "$OUT/$TS/audio-volumes.txt")" | sed -n '/^- STREAM_RING:/,/^- STREAM_/p' | sed -n 's/^   streamVolume://p' | tr -d ' ')
pct=$(( cpu7mx * 100 / cpu7hw ))
[ -f "$HIST" ] || printf 'ts\tcpu7_max\tcpu7_hw\tcpu7_pct\tcharge_full\tcharge_full_design\tcycles\tvol_music\tvol_ring\n' > "$HIST"
printf '%s\t%s\t%s\t%s%%\t%s\t%s\t%s\t%s\t%s\n' \
  "$TS" "$cpu7mx" "$cpu7hw" "$pct" "$cf" "$cfd" "$cyc" "$vol_music" "$vol_ring" >> "$HIST"

echo "snapshot: $OUT/$TS"
echo "cpu7 max $cpu7mx / hw $cpu7hw = ${pct}%   battery $cf/$cfd (cycles $cyc)   vol music/ring $vol_music/$vol_ring"
tail -3 "$HIST"
