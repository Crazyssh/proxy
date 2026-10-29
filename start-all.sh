#!/usr/bin/env bash
# ============================================================
#  Jalanin BANYAK proxy gsocks jadi SOCKS5 lokal (tanpa auth)
#  Baca proxies.txt, tiap proxy dapat port sendiri (mulai 1080).
#    127.0.0.1:1080 -> proxy baris ke-1
#    127.0.0.1:1081 -> proxy baris ke-2  ... dst
#  Semua gost jalan di background. Log di folder logs/.
# ============================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/proxies.txt"
LOGDIR="$DIR/logs"
PIDFILE="$DIR/gost-pids.txt"
START_PORT=1080
UPSTREAM="socks5"

GOST="$(command -v gost || echo /usr/local/bin/gost)"

if [ ! -x "$GOST" ]; then
    echo "[ERROR] gost tidak ditemukan. Jalankan install-gost.sh dulu."
    exit 1
fi
if [ ! -f "$LIST" ]; then
    echo "[ERROR] proxies.txt tidak ditemukan di $DIR"
    exit 1
fi

mkdir -p "$LOGDIR"
: > "$PIDFILE"

port=$START_PORT
count=0

echo ""
echo "================ MENJALANKAN PROXY ================"
echo ""

while IFS= read -r line || [ -n "$line" ]; do
    # lewati baris kosong / komentar (REM atau #)
    line="$(echo "$line" | tr -d '\r')"
    [ -z "$line" ] && continue
    case "$line" in
        REM*|\#*) continue ;;
    esac

    host="$(echo "$line" | cut -d: -f1)"
    pport="$(echo "$line" | cut -d: -f2)"
    user="$(echo "$line" | cut -d: -f3)"
    pass="$(echo "$line" | cut -d: -f4)"

    [ -z "$host" ] && continue

    echo "  127.0.0.1:$port  ->  $host:$pport"
    nohup "$GOST" -L "socks5://:$port" \
        -F "${UPSTREAM}://${user}:${pass}@${host}:${pport}" \
        > "$LOGDIR/gost-$port.log" 2>&1 &
    echo $! >> "$PIDFILE"

    port=$((port+1))
    count=$((count+1))
done < "$LIST"

echo ""
echo "================================================"
echo "  Total $count proxy dijalankan."
echo "  Port lokal: $START_PORT - $((port-1))"
echo "  PID tersimpan di gost-pids.txt"
echo "  Stop semua: ./stop-all.sh"
echo "================================================"
