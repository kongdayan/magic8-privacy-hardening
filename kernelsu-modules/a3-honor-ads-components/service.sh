#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a3-honor-ads-components"
LOG=/data/local/tmp/a3-honor-ads-components.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply
N=0
log "begin state=$STATE targets=$(wc -l < "$MODDIR/targets.txt" | tr -d ' ')"
for c in $(cat "$MODDIR/targets.txt"); do
  if [ "$STATE" = restore ]; then pm enable --user 0 "$c" </dev/null >/dev/null 2>&1
  else pm disable --user 0 "$c" </dev/null >/dev/null 2>&1; fi
  N=$((N+1))
done
log "done state=$STATE handled=$N"
