#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a0-privacy-settings"
LOG=/data/local/tmp/a0-privacy-settings.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply
DEFAULT='[{"prefix":"hiapp","pkgs":["com.huawei.appmarket","com.huawei.gamebox"]},{"prefix":"market","pkgs":["com.huawei.appmarket","com.huawei.gamebox"]},{"prefix":"hiapplink","pkgs":["com.huawei.appmarket","com.huawei.gamebox"]},{"prefix":"appmarket","pkgs":["com.huawei.appmarket","com.huawei.gamebox"]}]'

# 注意：settings/cmd 会把 stdin 当成请求体，在 while read < file 循环里必须 < /dev/null
sget(){ settings get "$1" "$2" </dev/null 2>/dev/null | head -1 | tr -d '\r\n'; }
sput(){ settings put "$1" "$2" "$3" </dev/null >/dev/null 2>&1; }

log "begin state=$STATE"
if [ "$STATE" = restore ]; then
  while read -r ns k v; do
    [ -z "$ns" ] && continue
    if [ "$k" = RFTrackFlag ]; then sput "$ns" "$k" on; else sput "$ns" "$k" 1; fi
  done < "$MODDIR/keys.txt"
  sput secure intercept_deeplink_protocols "$DEFAULT"
  log "done state=restore"; exit 0
fi

F=0
while read -r ns k v; do
  [ -z "$ns" ] && continue
  [ "$(sget "$ns" "$k")" = "$v" ] && continue
  ok=0; i=0
  while [ $i -lt 5 ]; do
    sput "$ns" "$k" "$v"
    [ "$(sget "$ns" "$k")" = "$v" ] && { ok=1; break; }
    i=$((i+1)); sleep 1
  done
  [ $ok -eq 0 ] && { log "REBOUND $ns/$k want=$v got=$(sget "$ns" "$k")"; F=$((F+1)); }
done < "$MODDIR/keys.txt"

DP=$(cat "$MODDIR/deeplink.json" 2>/dev/null)
if [ -n "$DP" ] && [ "$(sget secure intercept_deeplink_protocols)" != "$DP" ]; then sput secure intercept_deeplink_protocols "$DP"; fi
log "done state=apply rebound=$F"
