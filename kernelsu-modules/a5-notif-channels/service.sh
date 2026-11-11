#!/system/bin/sh
# a5-notif-channels — 按 channel 封禁营销通知
#
# 原理：Android 的 `cmd notification` 没有 channel 级开关，渠道状态只存在
#   /data/system/notification_policy.xml（Android 17 起是 ABX 二进制，改不动）。
# 所以这里用 app_process 以 uid 0 起一个进程，走
#   ActivityThread.systemMain() -> currentSystemContext()
#   -> NotificationManager.updateNotificationChannel(pkg, uid, channel)
# NMS 判定为 system/root 调用，按「用户修改」落盘：importance=0 + userLockedFields，
# 之后 app 自己再 createNotificationChannel 也改不回来。
#
# 清单：channels.tsv  pkg <TAB> channelId <TAB> 原始importance <TAB> 显示名
#      原始importance 仅用于 restore，按需自行增删行。

MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a5-notif-channels"
LOG=/data/local/tmp/a5-notif-channels.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

STATE=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$STATE" ] && STATE=apply
DEX="$MODDIR/ch.dex"
TSV="$MODDIR/channels.tsv"

[ -f "$DEX" ] || { log "FATAL missing $DEX"; echo "missing ch.dex"; exit 1; }
[ -f "$TSV" ] || { log "FATAL missing $TSV"; echo "missing channels.tsv"; exit 1; }
command -v app_process >/dev/null 2>&1 || { log "FATAL no app_process"; echo "no app_process"; exit 1; }

# 提权时机不固定（exploit root），等通知服务就绪
i=0
while [ $i -lt 30 ]; do
  service check notification </dev/null 2>/dev/null | grep -q found && break
  i=$((i+1)); sleep 2
done
[ "$i" -ge 30 ] && log "WARN notification service not ready after 60s"

# 注意：app_process / cmd 会把 stdin 当输入，循环里必须 </dev/null
run(){ CLASSPATH="$DEX" app_process /system/bin Ch "$@" </dev/null 2>&1 | tail -1; }

# 包名 -> user 0 uid。必须精确匹配：`pm list packages <filter>` 是子串匹配，
# 会把 com.unionpay 匹配到 com.unionpay.tsmservice，uid 一错就 "Channel does not exist"。
PMAP=/data/local/tmp/.a5-pmap
cmd package list packages -U --user 0 </dev/null 2>/dev/null \
  | sed 's/^package:\([^ ]*\) uid:\(.*\)$/\1\t\2/' > "$PMAP"
uid_of(){ awk -v p="$1" -F'\t' '$1==p{print $2; exit}' "$PMAP"; }

log "begin state=$STATE"
OK=0; MISS=0; SKIP=0
IFS=$(printf '\t')
while read -r pkg cid orig name; do
  [ -z "$pkg" ] && continue
  case "$pkg" in \#*) continue ;; esac
  U=$(uid_of "$pkg")
  if [ -z "$U" ]; then SKIP=$((SKIP+1)); log "SKIP not-installed $pkg"; continue; fi
  if [ "$STATE" = restore ]; then WANT=${orig:-3}; else WANT=0; fi
  R=$(run "$pkg" "$U" "$WANT" "$cid" "$name")
  case "$R" in
    OK*)   OK=$((OK+1)) ;;
    *)     MISS=$((MISS+1)); log "FAIL $pkg/$cid want=$WANT got=$R" ;;
  esac
done < "$TSV"
unset IFS

log "done state=$STATE ok=$OK fail=$MISS skip=$SKIP"
echo "state=$STATE ok=$OK fail=$MISS skip=$SKIP"
