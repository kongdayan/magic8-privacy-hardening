#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a4-abox-lockdown"
LOG=/data/local/tmp/a4-abox-lockdown.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=lock
if [ "$CUR" = lock ]; then NEW=unlock; else NEW=lock; fi
echo "$NEW" > "$MODDIR/state"
if [ "$NEW" = lock ]; then
  sh "$MODDIR/lockdown.sh" apply
  echo "已封闭 127.0.0.1/::1 的本地代理端口（App 扫端口会看到 refused）"
else
  sh "$MODDIR/lockdown.sh" clear
  echo "已恢复：本机可访问本地代理端口"
fi
echo "state=$NEW"
