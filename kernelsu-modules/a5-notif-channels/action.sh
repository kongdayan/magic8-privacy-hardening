#!/system/bin/sh
# Action 按钮：apply <-> restore 切换，并回读几条渠道验证
MODDIR="${0%/*}"; [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/a5-notif-channels"

CUR=$(cat "$MODDIR/state" 2>/dev/null); [ -z "$CUR" ] && CUR=apply
if [ "$CUR" = apply ]; then NEW=restore; else NEW=apply; fi
echo "$NEW" > "$MODDIR/state"
OUT=$(sh "$MODDIR/service.sh")
echo "$OUT"

# 抽样回读：知乎营销渠道 / 知乎私信（后者应当始终 imp=3）
D=$(dumpsys notification --noredact </dev/null 2>/dev/null)
imp_of(){
  echo "$D" | grep -F "mId='$1'" | head -1 | sed -n 's/.*mImportance=\(-*[0-9]*\).*/\1/p'
}
echo "知乎 营销通知 imp=$(imp_of com.hihonor.android.pushagent.LOW.927503pnc)"
echo "知乎 私信     imp=$(imp_of DM)"
echo "state=$NEW"
