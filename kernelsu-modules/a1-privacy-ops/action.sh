#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a1-privacy-ops"
LOG=/data/local/tmp/a1-privacy-ops.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
sh "$MODDIR/service.sh"
N=0
for p in $(cat "$MODDIR/usage-stats-pkgs.txt"); do
  case "$(cmd appops get "$p" GET_USAGE_STATS </dev/null 2>/dev/null | head -1)" in *ignore*) N=$((N+1));; esac
done
echo "GET_USAGE_STATS=ignore: $N / $(wc -l < "$MODDIR/usage-stats-pkgs.txt" | tr -d ' ')"
echo "state=$NEW"
