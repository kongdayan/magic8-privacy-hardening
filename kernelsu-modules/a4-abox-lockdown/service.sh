#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a4-abox-lockdown"
LOG=/data/local/tmp/a4-abox-lockdown.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=lock
log "service.sh begin state=$STATE"
case "$STATE" in
  unlock) sh "$MODDIR/lockdown.sh" clear ;;
  *)      sh "$MODDIR/lockdown.sh" apply ;;
esac
