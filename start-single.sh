#!/usr/bin/env bash
# ============================================================
#  Jalankan SEMUA proxy dalam 1 proses gost (hemat RAM)
#  Tampilan: warna + box + progress + ringkasan
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/gost.yaml"
LIST="$DIR/proxies.txt"
GOST="$(command -v gost || echo /usr/local/bin/gost)"
START_PORT=1080

# --- warna ---
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'
BOLD='\033[1m'

banner() {
  clear
  echo -e "${B}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo -e "  ║   ${W}G S O C K S   P R O X Y   L A U N C H E R${B}              ║"
  echo "  ║   datacenter -> socks5 lokal (1 proses, hemat RAM)       ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${N}"
}

banner

# --- cek prasyarat ---
if [ ! -x "$GOST" ]; then
  echo -e "  ${R}✖ gost tidak ditemukan.${N} Jalankan: ${Y}./install-gost.sh${N}"
  exit 1
fi
if [ ! -f "$CONF" ]; then
  echo -e "  ${Y}⚠ gost.yaml belum ada, generate dulu...${N}"
  if [ -x "$DIR/gen-config.sh" ]; then bash "$DIR/gen-config.sh" >/dev/null 2>&1; fi
fi
if [ ! -f "$CONF" ]; then
  echo -e "  ${R}✖ Gagal membuat gost.yaml.${N} Jalankan manual: ${Y}./gen-config.sh${N}"
  exit 1
fi

# hitung jumlah proxy
TOTAL=$(grep -cE '^\s*-\s*name:\s*svc-' "$CONF")
END_PORT=$((START_PORT + TOTAL - 1))

echo -e "  ${D}Konfigurasi:${N}"
echo -e "    ${W}gost${N}        : $($GOST -V 2>/dev/null)"
echo -e "    ${W}Total proxy${N} : ${G}${TOTAL}${N}"
echo -e "    ${W}Port lokal${N}  : ${G}${START_PORT}${N} ${D}-${N} ${G}${END_PORT}${N}"
echo -e "    ${W}Mode${N}        : ${G}single-process${N} ${D}(1 proses untuk semua port)${N}"
echo ""

# --- stop proses lama kalau ada ---
if [ -f "$DIR/gost-single.pid" ] && kill -0 "$(cat "$DIR/gost-single.pid")" 2>/dev/null; then
  echo -e "  ${Y}↻ Menghentikan instance lama...${N}"
  kill "$(cat "$DIR/gost-single.pid")" 2>/dev/null
  sleep 1
fi

# --- jalankan ---
echo -ne "  ${B}▶ Menyalakan proxy"
nohup "$GOST" -C "$CONF" > "$DIR/gost-single.log" 2>&1 &
PID=$!
echo $PID > "$DIR/gost-single.pid"

# progress bar menunggu listener siap
for i in $(seq 1 20); do
  echo -ne "${B}.${N}"
  sleep 0.15
done
echo ""
echo ""

sleep 1

# --- verifikasi proses & port ---
if kill -0 "$PID" 2>/dev/null; then
  LISTENING=$(ss -tlnp 2>/dev/null | grep -c "gost" )
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
  echo -e "    ${D}Perintah berguna:${N}"
  echo -e "      ${Y}./test-all.sh${N}     ${D}# cek semua proxy${N}"
  echo -e "      ${Y}./status.sh${N}       ${D}# lihat status & resource${N}"
  echo -e "      ${Y}./stop-single.sh${N}  ${D}# matikan semua proxy${N}"
  echo ""
else
  echo -e "  ${R}✖ Proxy GAGAL jalan.${N} Cek log:"
  echo -e "    ${D}tail -n 30 ${DIR}/gost-single.log${N}"
  tail -n 10 "$DIR/gost-single.log"
  exit 1
fi
