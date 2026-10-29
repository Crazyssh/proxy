#!/usr/bin/env bash
# ============================================================
#  Firewall: izinkan HANYA IP kamu akses port proxy 1080-2079
#  Proxy tetap tanpa auth, tapi orang lain diblokir di firewall.
# ============================================================
#  PAKAI:  ./firewall-setup.sh <IP_PUBLIK_KAMU>
#  Contoh: ./firewall-setup.sh 182.9.227.111
# ============================================================
set -e

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

PORT_START=1080
PORT_END=2079
MYIP="$1"

if [ -z "$MYIP" ]; then
  echo -e "  ${R}✖ Masukkan IP publik kamu.${N}"
  echo -e "  Contoh: ${Y}./firewall-setup.sh 182.9.227.111${N}"
  echo -e "  ${D}(cek IP kamu: buka https://api.ipify.org di browser)${N}"
  exit 1
fi

echo -e "  ${W}Mengatur firewall (ufw)...${N}"

# pastikan ufw ada
if ! command -v ufw >/dev/null 2>&1; then
  echo -e "  ${Y}ufw belum ada, install...${N}"
  apt-get update -y >/dev/null 2>&1 && apt-get install -y ufw >/dev/null 2>&1
fi

# JANGAN kunci diri sendiri: izinkan SSH dulu
echo -e "  ${D}• Izinkan SSH (22) biar tidak terkunci${N}"
ufw allow 22/tcp >/dev/null 2>&1

# izinkan IP kamu ke range port proxy
echo -e "  ${D}• Izinkan ${W}${MYIP}${D} ke port ${PORT_START}-${PORT_END}${N}"
ufw allow from "$MYIP" to any proto tcp port ${PORT_START}:${PORT_END} >/dev/null 2>&1

# tolak siapapun selain itu ke range port proxy
echo -e "  ${D}• Tolak IP lain ke port ${PORT_START}-${PORT_END}${N}"
ufw deny ${PORT_START}:${PORT_END}/tcp >/dev/null 2>&1

# aktifkan
echo "y" | ufw enable >/dev/null 2>&1
ufw reload >/dev/null 2>&1

echo ""
echo -e "  ${G}✔ Firewall aktif.${N}"
echo -e "    ${W}Hanya IP ${MYIP}${N} yang boleh akses proxy ${PORT_START}-${PORT_END}."
echo -e "    IP lain otomatis ditolak."
echo ""
echo -e "  ${D}Status:${N}"
ufw status numbered | head -20
echo ""
echo -e "  ${Y}CATATAN:${N} kalau IP publik kamu berubah (internet rumah dinamis),"
echo -e "  jalankan ulang script ini dengan IP baru."
