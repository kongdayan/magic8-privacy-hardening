#!/system/bin/sh
# Action 按钮：apply（关检测） <-> restore（恢复检测）
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a0b-safety-off"
LOG=/data/local/tmp/a0b-safety-off.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
sh "$MODDIR/service.sh"

g(){ settings get "$1" "$2" </dev/null 2>/dev/null | tr -d '\r\n'; }
echo "hsm_antivirus=$(g system hsm_antivirus)  antifraud_remind=$(g global antifraud_remind)  ai_scam_detect=$(g secure ai_scam_detect_switch)"
echo "state=$NEW"
