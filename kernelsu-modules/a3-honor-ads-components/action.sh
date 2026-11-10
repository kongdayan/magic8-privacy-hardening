#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a3-honor-ads-components"
LOG=/data/local/tmp/a3-honor-ads-components.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
sh "$MODDIR/service.sh"
[ "$NEW" = restore ] && echo "已恢复全部 adsdk 组件" || echo "已禁用全部 adsdk 组件"
echo "state=$NEW"
