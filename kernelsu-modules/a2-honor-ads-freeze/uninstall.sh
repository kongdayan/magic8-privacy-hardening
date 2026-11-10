#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a2-honor-ads-freeze"
LOG=/data/local/tmp/a2-honor-ads-freeze.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# 卸载不自动解冻（避免意外把广告放回），需要时手动执行 action.sh
log "uninstall"
