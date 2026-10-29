#!/usr/bin/env bash
# ============================================================
#  Dashboard status proxy gsocks (mode single-process)
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$DIR/gost-single.pid"
CONF="$DIR/gost.yaml"
START_PORT=1080

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

clear
echo -e "${B}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo -e "  ║   ${W}P R O X Y   S T A T U S   D A S H B O A R D${B}            ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${N}"

# status proses (mode 1 proses/proxy)
RUNNING=$(pgrep -x gost | wc -l)
LISTENING=$(ss -tlnp 2>/dev/null | grep -c "gost")
if [ "$RUNNING" -gt 0 ]; then
  STATE="${G}● RUNNING${N}"
else
  STATE="${R}● STOPPED${N}"
fi
END_PORT=$((START_PORT + LISTENING - 1))

echo -e "  ${W}Status${N}        : $STATE"
echo -e "  ${W}Proses gost${N}   : ${G}${RUNNING}${N}"
echo -e "  ${W}Listening${N}     : ${G}${LISTENING}${N} socket"
echo -e "  ${W}Port lokal${N}    : 127.0.0.1:${START_PORT} ${D}..${N} 127.0.0.1:${END_PORT}"
echo ""

# total RAM semua proses gost
if [ "$RUNNING" -gt 0 ]; then
  TOTMEM=$(ps -C gost -o rss= 2>/dev/null | awk '{s+=$1} END{print int(s/1024)}')
  echo -e "  ${W}RAM total gost${N}: ${TOTMEM:-0} MB  ${D}(${RUNNING} proses)${N}"
fi

# resource sistem
echo ""
echo -e "  ${D}── Sistem ──${N}"
MEM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
MEM_USED=$(free -m | awk '/Mem:/{print $3}')
echo -e "  ${W}RAM sistem${N}    : ${MEM_USED} MB / ${MEM_TOTAL} MB"
echo -e "  ${W}CPU core${N}      : $(nproc)"
echo -e "  ${W}Uptime${N}        : $(uptime -p 2>/dev/null | sed 's/up //')"
echo ""

# cek cepat 1 proxy pertama
echo -e "  ${D}── Tes cepat (port ${START_PORT}) ──${N}"
IP=$(curl -s --max-time 15 --socks5-hostname 127.0.0.1:${START_PORT} https://api.ipify.org 2>/dev/null)
if echo "$IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo -e "  ${G}✔ Proxy OK${N} -> IP keluar: ${W}${IP}${N}"
else
  echo -e "  ${R}✖ Proxy tidak merespon${N} (pastikan sudah ./start-single.sh)"
fi
echo ""
