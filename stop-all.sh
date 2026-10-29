#!/usr/bin/env bash
# Matikan semua proxy gost (mode 1 proses/proxy)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$DIR/gost-pids.txt"
G='\033[0;32m'; Y='\033[1;33m'; N='\033[0m'

echo ""
echo -e "  ${Y}Menghentikan semua proxy gost...${N}"
if [ -f "$PIDFILE" ]; then
  while read -r pid; do [ -n "$pid" ] && kill "$pid" 2>/dev/null; done < "$PIDFILE"
  : > "$PIDFILE"
fi
pkill -9 gost 2>/dev/null
sleep 1
echo -e "  ${G}✔ Selesai. Sisa proses gost: $(pgrep -x gost | wc -l)${N}"
echo ""
