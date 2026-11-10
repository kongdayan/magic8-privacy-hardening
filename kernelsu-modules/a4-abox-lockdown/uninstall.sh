#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a4-abox-lockdown"
LOG=/data/local/tmp/a4-abox-lockdown.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a4-abox-lockdown"
sh "$MODDIR/lockdown.sh" clear >/dev/null 2>&1
log "uninstall: rules cleared"
