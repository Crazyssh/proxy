#!/usr/bin/env bash
# ============================================================
#  Generate gost config YAML dari proxies.txt (tampilan rapi)
#  SATU proses gost melayani SEMUA port.
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/proxies.txt"
CONF="$DIR/gost.yaml"
START_PORT=1080
UPSTREAM="socks5"

G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

# hitung total dulu untuk progress
TOTAL=$(grep -vcE '^\s*(REM|#|$)' "$LIST")

echo -e "${B}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo -e "  ║   ${W}G E N E R A T E   C O N F I G${B}                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${N}"
echo -e "  ${W}Sumber${N}  : proxies.txt (${G}${TOTAL}${N} proxy)"
echo -e "  ${W}Target${N}  : gost.yaml"
echo ""

echo "services:" > "$CONF"

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

    cat >> "$CONF" <<EOF
  - name: svc-$port
    addr: ":$port"
    handler:
      type: socks5
    listener:
      type: tcp
    forwarder:
      nodes:
        - name: up-$port
          addr: $user:$pass@$host:$pport
          connector:
            type: $UPSTREAM
          dialer:
            type: tcp
EOF
    port=$((port+1))
    count=$((count+1))

    # progress bar
    if [ "$TOTAL" -gt 0 ]; then
      filled=$(( count * barlen / TOTAL ))
      bar=$(printf '%*s' "$filled" '' | tr ' ' '#')
      space=$(printf '%*s' "$((barlen - filled))" '')
      pct=$(( count * 100 / TOTAL ))
      echo -ne "\r  ${B}[${G}${bar}${D}${space}${B}]${N} ${W}${pct}%%${N} ${D}(${count}/${TOTAL})${N}"
    fi
done < "$LIST"

echo ""
echo ""
echo -e "  ${G}✔ Selesai.${N} ${count} service, port ${START_PORT}-$((port-1))"
echo -e "  ${D}Jalankan: ${Y}./start-single.sh${N}"
echo ""
