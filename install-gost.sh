#!/usr/bin/env bash
# ============================================================
#  Installer gost untuk Linux (Ubuntu 22) - amd64
#  Pasang gost ke /usr/local/bin/gost
# ============================================================
set -e

GOST_VER="3.3.2"
GOST_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VER}/gost_${GOST_VER}_linux_amd64.tar.gz"
TMP="/tmp/gost.tar.gz"

if command -v gost >/dev/null 2>&1; then
    echo "gost sudah terpasang: $(gost -V)"
    exit 0
fi

echo "Mengunduh gost v${GOST_VER} ..."
curl -L -o "$TMP" "$GOST_URL"

echo "Mengekstrak ..."
tar -xzf "$TMP" -C /tmp gost

echo "Memasang ke /usr/local/bin/gost (butuh sudo) ..."
sudo mv /tmp/gost /usr/local/bin/gost
sudo chmod +x /usr/local/bin/gost
rm -f "$TMP"

echo ""
echo "BERHASIL. Versi: $(gost -V)"
