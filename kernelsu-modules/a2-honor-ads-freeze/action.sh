#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a2-honor-ads-freeze"
LOG=/data/local/tmp/a2-honor-ads-freeze.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
sh "$MODDIR/service.sh"
F=$(pm list packages -d </dev/null | grep -cE "$(paste -sd'|' "$MODDIR/pkgs.txt")")
[ "$NEW" = restore ] && echo "已解冻（当前仍冻结 $F 个）" || echo "已冻结 $F 个包"
echo "state=$NEW"
