#!/usr/bin/env bash
# 按 notification channel 精准封禁（不误伤功能通知）
# 依赖: adb + 已 root 的设备（KernelSU/Magisk 均可）
#
#   notif-channel.sh list [marketing|active|all]   列出渠道
#   notif-channel.sh info <pkg>                    某个 app 的全部渠道
#   notif-channel.sh block <pkg>                   封禁该 app 所有营销渠道
#   notif-channel.sh block-all                     封禁全部 app 的营销渠道
#   notif-channel.sh set <pkg> <imp> <cid> <name>  手动置某渠道 importance
#   notif-channel.sh unblock-all                   按备份恢复
#   notif-channel.sh app-off / app-on <pkg>        整包静音 / 恢复（粗粒度）
set -euo pipefail

BASE=$(cd "$(dirname "$0")" && pwd)
PARSE="$BASE/parse.py"
LOCAL_DEX="$BASE/../../kernelsu-modules/a5-notif-channels/ch.dex"
DEV_DEX="/data/local/tmp/ch.dex"
BACKUP="$BASE/backup.local.tsv"   # 本机记录原始 importance，unblock-all 用；已 gitignore
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
ADB="adb -s $SERIAL"

[ -n "${SERIAL:-}" ] || { echo "no adb device"; exit 1; }

ensure_dex() {
  [ -f "$LOCAL_DEX" ] || { echo "missing $LOCAL_DEX"; exit 1; }
  if ! $ADB shell "test -f $DEV_DEX" 2>/dev/null; then
    $ADB push "$LOCAL_DEX" "$DEV_DEX" >/dev/null
  fi
}

dump() { $ADB shell 'dumpsys notification --noredact' 2>/dev/null; }

# dumpsys 里的 uid 可能是残留的旧值，以 PackageManager 的 user 0 uid 为准
UIDCACHE=""
uid_of() {
  if [ -z "$UIDCACHE" ]; then
    UIDCACHE=$(mktemp)
    $ADB shell 'cmd package list packages -U --user 0' 2>/dev/null </dev/null \
      | sed 's/^package:\([^ ]*\) uid:\([0-9]*\).*/\1	\2/' >"$UIDCACHE"
  fi
  awk -v p="$1" -F'\t' '$1==p{print $2; exit}' "$UIDCACHE"
}

run_dex() {
  local q
  q=$(python3 -c 'import shlex,sys;print(" ".join(shlex.quote(a) for a in sys.argv[1:]))' "$@")
  $ADB shell "su -c 'CLASSPATH=$DEV_DEX app_process /system/bin Ch $q'" 2>&1 </dev/null | tail -2
}

# set_channel pkg uid imp cid name [orig_imp]
set_channel() {
  local pkg="$1" uid="$2" imp="$3" cid="$4" name="$5" orig="${6:-$3}"
  if [ "$imp" = "0" ]; then
    grep -qF "$(printf '%s\t%s\t' "$pkg" "$cid")" "$BACKUP" 2>/dev/null || \
      printf '%s\t%s\t%s\t%s\t%s\n' "$pkg" "$uid" "$orig" "$cid" "$name" >>"$BACKUP" || true
  fi
  printf '  %-45s imp=%-2s %s\n' "${cid:0:45}" "$imp" "$name"
  run_dex "$pkg" "$uid" "$imp" "$cid" "$name"
}

cmd_list() {
  local what="${1:-marketing}"
  printf '%-42s %-6s %-4s %-7s %s\n' PKG UID IMP LOCKED CHANNEL
  dump | python3 "$PARSE" list "$what" | while IFS=$'\t' read -r pkg uid imp lock cid name flag; do
    u=$(uid_of "$pkg"); [ -z "$u" ] || uid="$u"
    printf '%-42s %-6s %-4s %-7s %s%s\n' "$pkg" "$uid" "$imp" "$lock" "$name" "${flag:+  [$flag]}"
  done
}

cmd_info() {
  printf '%-6s %-4s %-7s %s\n' UID IMP LOCKED CHANNEL
  dump | python3 "$PARSE" list all "$1" | while IFS=$'\t' read -r pkg uid imp lock cid name flag; do
    u=$(uid_of "$pkg"); [ -z "$u" ] || uid="$u"
    printf '%-6s %-4s %-7s %s  (%s)\n' "$uid" "$imp" "$lock" "$name" "$cid"
  done
}

cmd_block() {
  local pkg="$1"
  dump | python3 "$PARSE" list marketing "$pkg" | while IFS=$'\t' read -r p uid imp lock cid name flag; do
    [ "$imp" = "0" ] && { printf '  %-45s already blocked\n' "${cid:0:45}"; continue; }
    u=$(uid_of "$p"); [ -z "$u" ] || uid="$u"
    set_channel "$p" "$uid" 0 "$cid" "$name" "$imp"
  done
}

cmd_block_all() {
  dump | python3 "$PARSE" list marketing | while IFS=$'\t' read -r pkg uid imp lock cid name flag; do
    [ "$imp" = "0" ] && continue
    [ "$flag" = "appblocked" ] && { printf '  %-45s skip(app already silenced)\n' "${cid:0:45}"; continue; }
    u=$(uid_of "$pkg"); [ -z "$u" ] || uid="$u"
    set_channel "$pkg" "$uid" 0 "$cid" "$name" "$imp"
  done
}

cmd_unblock_all() {
  [ -f "$BACKUP" ] || { echo "no backup"; exit 1; }
  while IFS=$'\t' read -r pkg uid orig cid name; do
    printf '  restore %-40s -> imp=%s  %s\n' "$pkg" "${orig:-3}" "$name"
    run_dex "$pkg" "$uid" "${orig:-3}" "$cid" "$name"
  done <"$BACKUP"
}

cmd_app_off() {
  $ADB shell "pm revoke $1 android.permission.POST_NOTIFICATIONS" && echo "app silenced: $1"
}
cmd_app_on() {
  $ADB shell "pm grant $1 android.permission.POST_NOTIFICATIONS" && echo "app restored: $1"
}

ensure_dex
case "${1:-list}" in
  list)        shift; cmd_list "${1:-marketing}" ;;
  info)        cmd_info "$2" ;;
  block)       cmd_block "$2" ;;
  block-all)   cmd_block_all ;;
  set)         set_channel "$2" "$3" "$4" "$5" "$6" ;;
  unblock-all) cmd_unblock_all ;;
  app-off)     cmd_app_off "$2" ;;
  app-on)      cmd_app_on "$2" ;;
  *)           sed -n '2,14p' "$0" ;;
esac
