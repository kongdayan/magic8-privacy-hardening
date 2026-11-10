#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a0-privacy-settings"
LOG=/data/local/tmp/a0-privacy-settings.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
sh "$MODDIR/service.sh"
echo "oaid_limit_state=$(settings get secure oaid_limit_state </dev/null)"
echo "recommendation_switch=$(settings get global recommendation_switch </dev/null)"
echo "RFTrackFlag=$(settings get global RFTrackFlag </dev/null)"
echo "state=$NEW"
