#!/usr/bin/env bash
# ============================================================
#  Jalankan SEMUA proxy (1 proses gost per proxy).
#  CATATAN: gost tidak bisa pasangan 1:1 untuk banyak -L/-F
#  dalam satu proses, jadi tiap proxy = 1 proses terpisah.
#  VPS besar? aman. Tampilan tetap rapi + progress.
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/proxies.txt"
LOGDIR="$DIR/logs"
PIDFILE="$DIR/gost-pids.txt"
GOST="$(command -v gost || echo /usr/local/bin/gost)"
START_PORT=1080
UPSTREAM="socks5"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

clear
echo -e "${B}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo -e "  ║   ${W}G S O C K S   P R O X Y   L A U N C H E R${B}              ║"
echo "  ║   datacenter -> socks5 lokal (1 proses / proxy)          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${N}"

if [ ! -x "$GOST" ]; then
  echo -e "  ${R}✖ gost tidak ada.${N} Jalankan: ${Y}./install-gost.sh${N}"; exit 1
fi
if [ ! -f "$LIST" ]; then
  echo -e "  ${R}✖ proxies.txt tidak ada.${N}"; exit 1
fi

# naikkan limit (banyak proses + socket)
ulimit -n 1048576 2>/dev/null || ulimit -n 65535 2>/dev/null
ulimit -u 200000 2>/dev/null

# stop proses lama
if [ -f "$PIDFILE" ]; then
  while read -r pid; do [ -n "$pid" ] && kill "$pid" 2>/dev/null; done < "$PIDFILE"
fi
pkill -9 gost 2>/dev/null
sleep 1

mkdir -p "$LOGDIR"
: > "$PIDFILE"

TOTAL=$(grep -vcE '^\s*(REM|#|$)' "$LIST")
echo -e "  ${W}Total proxy${N} : ${G}${TOTAL}${N}"
echo -e "  ${W}gost${N}        : $($GOST -V 2>/dev/null)"
echo ""

port=$START_PORT
count=0
barlen=40
while IFS= read -r line || [ -n "$line" ]; do
    line="$(echo "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    case "$line" in REM*|\#*) continue ;; esac

    host="$(echo "$line" | cut -d: -f1)"
    pport="$(echo "$line" | cut -d: -f2)"
    user="$(echo "$line" | cut -d: -f3)"
    pass="$(echo "$line" | cut -d: -f4)"
    [ -z "$host" ] && continue

    nohup "$GOST" -L "socks5://:$port" \
        -F "${UPSTREAM}://${user}:${pass}@${host}:${pport}" \
        > "$LOGDIR/gost-$port.log" 2>&1 &
    echo $! >> "$PIDFILE"

    port=$((port+1)); count=$((count+1))

    if [ $((count % 10)) -eq 0 ] || [ "$count" -eq "$TOTAL" ]; then
      filled=$(( count * barlen / TOTAL )); [ $filled -gt $barlen ] && filled=$barlen
      bar=$(printf '%*s' "$filled" '' | tr ' ' '#')
      space=$(printf '%*s' "$((barlen-filled))" '')
      pct=$(( count * 100 / TOTAL ))
      echo -ne "\r  ${B}[${G}${bar}${D}${space}${B}]${N} ${W}${pct}%%${N} ${D}(${count}/${TOTAL})${N}  "
    fi
done < "$LIST"

END_PORT=$((port-1))
echo ""; echo ""
sleep 2

LISTENING=$(ss -tlnp 2>/dev/null | grep -c "gost")
RUNNING=$(pgrep -x gost | wc -l)

echo -e "  ${G}╔════════════════════════════════════════════╗${N}"
echo -e "  ${G}║            PROXY BERHASIL AKTIF             ║${N}"
echo -e "  ${G}╚════════════════════════════════════════════╝${N}"
echo ""
echo -e "    ${W}Proses gost${N}  : ${G}${RUNNING}${N}"
echo -e "    ${W}Listening${N}    : ${G}${LISTENING}${N} socket"
echo -e "    ${W}Port lokal${N}   : 127.0.0.1:${START_PORT} ${D}..${N} 127.0.0.1:${END_PORT}"
echo -e "    ${W}Log${N}          : ${D}${LOGDIR}/${N}"
echo ""
echo -e "    ${D}Test: ${Y}./test-all.sh${N}   Stop: ${Y}./stop-all.sh${N}"
echo ""
