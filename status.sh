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

# status proses
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  PID=$(cat "$PIDFILE")
  STATE="${G}● RUNNING${N}"
else
  PID="-"
  STATE="${R}● STOPPED${N}"
fi

TOTAL=0
[ -f "$CONF" ] && TOTAL=$(grep -cE '^\s*-\s*name:\s*svc-' "$CONF")
END_PORT=$((START_PORT + TOTAL - 1))
LISTENING=$(ss -tlnp 2>/dev/null | grep -c "gost")

echo -e "  ${W}Status${N}        : $STATE"
echo -e "  ${W}PID${N}           : $PID"
echo -e "  ${W}Total proxy${N}   : ${G}${TOTAL}${N}"
echo -e "  ${W}Port lokal${N}    : 127.0.0.1:${START_PORT} ${D}..${N} 127.0.0.1:${END_PORT}"
echo -e "  ${W}Listening${N}     : ${G}${LISTENING}${N} socket"
echo ""

# resource proses
if [ "$PID" != "-" ]; then
  read -r CPU MEM RSS <<< "$(ps -p "$PID" -o %cpu=,%mem=,rss= 2>/dev/null)"
  RSS_MB=$(( ${RSS:-0} / 1024 ))
  echo -e "  ${W}CPU proses${N}    : ${CPU:-0}%"
  echo -e "  ${W}RAM proses${N}    : ${MEM:-0}%  (${RSS_MB} MB)"
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
