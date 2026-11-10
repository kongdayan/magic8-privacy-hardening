#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a1-privacy-ops"
LOG=/data/local/tmp/a1-privacy-ops.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply
. "$MODDIR/appops.conf"
log "begin state=$STATE"
for p in $(cat "$MODDIR/usage.txt"); do
  if [ "$STATE" = restore ]; then cmd appops set --user 0 "$p" GET_USAGE_STATS default </dev/null >/dev/null 2>&1
  else cmd appops set --user 0 "$p" GET_USAGE_STATS ignore </dev/null >/dev/null 2>&1; fi
done
for o in $NETOPS; do
  if [ "$STATE" = restore ]; then
    cmd appops set --user 0 "$NET" "$o" default </dev/null >/dev/null 2>&1
    case $o in
      READ_SMS)       pm grant --user 0 "$NET" android.permission.READ_SMS </dev/null >/dev/null 2>&1 ;;
      READ_CALL_LOG)  pm grant --user 0 "$NET" android.permission.READ_CALL_LOG </dev/null >/dev/null 2>&1 ;;
      READ_CONTACTS)  pm grant --user 0 "$NET" android.permission.READ_CONTACTS </dev/null >/dev/null 2>&1 ;;
    esac
  else
    case $o in
      READ_SMS)       pm revoke --user 0 "$NET" android.permission.READ_SMS </dev/null >/dev/null 2>&1 ;;
      READ_CALL_LOG)  pm revoke --user 0 "$NET" android.permission.READ_CALL_LOG </dev/null >/dev/null 2>&1 ;;
      READ_CONTACTS)  pm revoke --user 0 "$NET" android.permission.READ_CONTACTS </dev/null >/dev/null 2>&1 ;;
    esac
    cmd appops set --user 0 "$NET" "$o" ignore </dev/null >/dev/null 2>&1
  fi
done
log "done state=$STATE"
