#!/system/bin/sh
# a0b-safety-off — 关掉 Honor 的安全检测 / 反诈提醒
#
# 与 a0-privacy-settings 同一手段（settings），独立模块、独立 state：
# a0  是「少上报 / 少推荐」；a0b 是「不要检测我」——后者是降防护，语义不同，
# 所以不放进同一个开关里，否则 restore 时会把广告推荐一起放回来。
#
# id 故意叫 a0b：按字母序紧跟 a0，两个 settings 层都排在 a1–a3 的
# pm 风暴之前（pm 风暴期间 SettingsProvider 会短暂拒绝事务）。

MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a0b-safety-off"
LOG=/data/local/tmp/a0b-safety-off.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply

# 注意：settings/cmd 会把 stdin 当成请求体，在 while read < file 循环里必须 </dev/null
sget(){ settings get "$1" "$2" </dev/null 2>/dev/null | head -1 | tr -d '\r\n'; }
sput(){ settings put "$1" "$2" "$3" </dev/null >/dev/null 2>&1; }

log "begin state=$STATE"
F=0
while read -r ns k v; do
  [ -z "$ns" ] && continue
  case "$ns" in \#*) continue ;; esac
  if [ "$STATE" = restore ]; then WANT=1; else WANT=$v; fi
  [ "$(sget "$ns" "$k")" = "$WANT" ] && continue
  ok=0; i=0
  while [ $i -lt 5 ]; do
    sput "$ns" "$k" "$WANT"
    [ "$(sget "$ns" "$k")" = "$WANT" ] && { ok=1; break; }
    i=$((i+1)); sleep 1
  done
  [ $ok -eq 0 ] && { log "REBOUND $ns/$k want=$WANT got=$(sget "$ns" "$k")"; F=$((F+1)); }
done < "$MODDIR/keys.txt"

log "done state=$STATE rebound=$F"
echo "state=$STATE rebound=$F"
