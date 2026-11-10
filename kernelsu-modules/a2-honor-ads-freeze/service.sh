#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a2-honor-ads-freeze"
LOG=/data/local/tmp/a2-honor-ads-freeze.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply
N=0
log "begin state=$STATE"
for p in $(cat "$MODDIR/pkgs.txt"); do
  if [ "$STATE" = restore ]; then pm enable "$p" </dev/null >/dev/null 2>&1
  else pm disable-user --user 0 "$p" </dev/null >/dev/null 2>&1; fi
  N=$((N+1))
done
log "done state=$STATE handled=$N"
