#!/system/bin/sh
# install.sh — copy KernelSU modules into /data/adb/modules and apply once
#   usage: su -c 'sh install.sh /data/local/tmp/kmods'
set -u
SRC=${1:-/data/local/tmp/kmods}
DST=/data/adb/modules

[ -d "$SRC" ] || { echo "source dir not found: $SRC"; exit 1; }
[ "$(id -u)" = "0" ] || { echo "must run as root"; exit 1; }

for d in "$SRC"/*/; do
  m=$(basename "$d")
  echo "==> $m"
  mkdir -p "$DST/$m"
  cp -f "$d"* "$DST/$m"/ 2>/dev/null
  chmod 755 "$DST/$m"/*.sh 2>/dev/null
  chmod 644 "$DST/$m"/module.prop "$DST/$m"/state 2>/dev/null
  chmod 644 "$DST/$m"/*.txt "$DST/$m"/*.json "$DST/$m"/*.conf 2>/dev/null
  rm -f "$DST/$m/disable"
  sh "$DST/$m/service.sh" >/dev/null 2>&1 && echo "    applied" || echo "    service.sh returned non-zero"
  tail -1 "/data/local/tmp/$m.log" 2>/dev/null | sed 's/^/    /'
done

echo
echo "installed:"
ls -1 "$DST" 2>/dev/null | sed 's/^/  /'
