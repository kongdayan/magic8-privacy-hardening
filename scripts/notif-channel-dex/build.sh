#!/usr/bin/env bash
# 重新汇编 ch.dex，不需要 Android SDK / d8：借 apktool 里 shaded 的 dexlib2 + smali
# 用法: ./build.sh [apiLevel]   (api<=34 → dex 039/040；api=35 → dex 041，本机 ART 拒绝加载)
set -euo pipefail
API="${1:-28}"
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/../../kernelsu-modules/a5-notif-channels/ch.dex"

APKTOOL_JAR=$(ls /opt/homebrew/Cellar/apktool/*/libexec/apktool_*.jar 2>/dev/null | tail -1 || true)
[ -n "$APKTOOL_JAR" ] || APKTOOL_JAR=$(find / -name 'apktool*.jar' -maxdepth 6 2>/dev/null | head -1)
[ -f "$APKTOOL_JAR" ] || { echo "apktool jar not found (brew install apktool)"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
javac -cp "$APKTOOL_JAR" -d "$TMP" "$HERE/Build.java"
java -cp "$APKTOOL_JAR:$TMP" Build "$HERE" "$API" "$OUT"
head -c 8 "$OUT" | xxd -p
