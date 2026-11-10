#!/system/bin/sh
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a4-abox-lockdown"
LOG=/data/local/tmp/a4-abox-lockdown.log
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

IPT=/system/bin/iptables
IP6T=/system/bin/ip6tables
PORTS="10810 65535"
del_rules(){ for p in $PORTS; do
  while $IPT  -D INPUT -i lo -p tcp --dport $p -j REJECT 2>/dev/null; do :; done
  while $IP6T -D INPUT -i lo -p tcp --dport $p -j REJECT 2>/dev/null; do :; done
done; }
add_rules(){ for p in $PORTS; do
  $IPT  -I INPUT 1 -i lo -p tcp --dport $p -j REJECT
  $IP6T -I INPUT 1 -i lo -p tcp --dport $p -j REJECT
done; }
count(){ echo "v4=$($IPT -S INPUT 2>/dev/null | grep -cE '10810|65535') v6=$($IP6T -S INPUT 2>/dev/null | grep -cE '10810|65535')"; }
case "$1" in
  apply)  del_rules; add_rules; echo "LOCKED  $(count)" ;;
  clear)  del_rules;             echo "UNLOCKED $(count)" ;;
  status) echo "state=$(cat "$MODDIR/state" 2>/dev/null || echo unset)  $(count)" ;;
  *) echo "usage: $0 apply|clear|status"; exit 1 ;;
esac
