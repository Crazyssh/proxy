#!/usr/bin/env bash
# ============================================================
#  Jalankan SEMUA proxy dalam 1 proses gost (hemat RAM)
#  Pakai banyak -L/-F (command line) -> cara yang TERBUKTI jalan
#  untuk upstream socks5 dengan auth.
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/proxies.txt"
GOST="$(command -v gost || echo /usr/local/bin/gost)"
START_PORT=1080
UPSTREAM="socks5"

# --- warna ---
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

clear
echo -e "${B}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo -e "  ║   ${W}G S O C K S   P R O X Y   L A U N C H E R${B}              ║"
echo "  ║   datacenter -> socks5 lokal (1 proses, hemat RAM)       ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${N}"

if [ ! -x "$GOST" ]; then
  echo -e "  ${R}✖ gost tidak ditemukan.${N} Jalankan: ${Y}./install-gost.sh${N}"
  exit 1
fi
if [ ! -f "$LIST" ]; then
  echo -e "  ${R}✖ proxies.txt tidak ditemukan.${N}"
  exit 1
fi

# naikkan limit file descriptor untuk ribuan port
ulimit -n 1048576 2>/dev/null || ulimit -n 65535 2>/dev/null

# --- bangun argumen -L/-F dari proxies.txt ---
ARGS=()
port=$START_PORT
count=0
while IFS= read -r line || [ -n "$line" ]; do
    line="$(echo "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    case "$line" in REM*|\#*) continue ;; esac

    host="$(echo "$line" | cut -d: -f1)"
    pport="$(echo "$line" | cut -d: -f2)"
    user="$(echo "$line" | cut -d: -f3)"
    pass="$(echo "$line" | cut -d: -f4)"
    [ -z "$host" ] && continue

    ARGS+=( -L "socks5://:$port" -F "${UPSTREAM}://${user}:${pass}@${host}:${pport}" )
    port=$((port+1))
    count=$((count+1))
done < "$LIST"

END_PORT=$((port-1))

echo -e "  ${D}Konfigurasi:${N}"
echo -e "    ${W}gost${N}        : $($GOST -V 2>/dev/null)"
echo -e "    ${W}Total proxy${N} : ${G}${count}${N}"
echo -e "    ${W}Port lokal${N}  : ${G}${START_PORT}${N} ${D}-${N} ${G}${END_PORT}${N}"
echo -e "    ${W}Mode${N}        : ${G}single-process (-L/-F)${N}"
echo ""

# stop instance lama
if [ -f "$DIR/gost-single.pid" ] && kill -0 "$(cat "$DIR/gost-single.pid")" 2>/dev/null; then
  echo -e "  ${Y}↻ Menghentikan instance lama...${N}"
  kill "$(cat "$DIR/gost-single.pid")" 2>/dev/null
  sleep 1
fi

echo -ne "  ${B}▶ Menyalakan proxy"
nohup "$GOST" "${ARGS[@]}" > "$DIR/gost-single.log" 2>&1 &
PID=$!
echo $PID > "$DIR/gost-single.pid"
for i in $(seq 1 15); do echo -ne "${B}.${N}"; sleep 0.2; done
echo ""; echo ""
sleep 1

if kill -0 "$PID" 2>/dev/null; then
  LISTENING=$(ss -tlnp 2>/dev/null | grep -c "gost")
  echo -e "  ${G}╔════════════════════════════════════════════╗${N}"
  echo -e "  ${G}║            PROXY BERHASIL AKTIF             ║${N}"
  echo -e "  ${G}╚════════════════════════════════════════════╝${N}"
  echo ""
  echo -e "    ${W}Status${N}       : ${G}● RUNNING${N}"
  echo -e "    ${W}PID${N}          : ${PID}"
  echo -e "    ${W}Port aktif${N}   : 127.0.0.1:${START_PORT} ${D}..${N} 127.0.0.1:${END_PORT}"
  echo -e "    ${W}Listening${N}    : ${G}${LISTENING}${N} socket"
  echo -e "    ${W}Log${N}          : ${D}${DIR}/gost-single.log${N}"
  echo ""
  echo -e "    ${D}Cek status: ${Y}./status.sh${N}   Test: ${Y}./test-all.sh${N}   Stop: ${Y}./stop-single.sh${N}"
  echo ""
else
  echo -e "  ${R}✖ Proxy GAGAL jalan.${N} Cek log:"
  tail -n 15 "$DIR/gost-single.log"
  exit 1
fi
