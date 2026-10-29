#!/usr/bin/env bash
# ============================================================
#  Installer Web Panel (Flask) di VPS Ubuntu
# ============================================================
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

G='\033[0;32m'; Y='\033[1;33m'; W='\033[1;37m'; N='\033[0m'

echo -e "${W}[1/3] Install python3 + venv...${N}"
apt-get update -y >/dev/null 2>&1
apt-get install -y python3 python3-venv python3-pip curl >/dev/null 2>&1

echo -e "${W}[2/3] Buat virtualenv + install Flask...${N}"
cd "$DIR"
python3 -m venv venv
./venv/bin/pip install --quiet --upgrade pip
./venv/bin/pip install --quiet -r requirements.txt

echo -e "${W}[3/3] Selesai.${N}"
echo ""
echo -e "  ${G}✔ Web panel siap.${N}"
echo ""
echo -e "  Jalankan (ganti PASSWORD dengan punyamu):"
echo -e "  ${Y}PANEL_PASSWORD='rahasiaku' ./venv/bin/python app.py${N}"
echo ""
echo -e "  Akses dari browser: ${Y}http://IP_VPS:8088${N}"
echo ""
