#!/usr/bin/env bash
# Matikan semua proxy gost yang dijalankan start-all.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$DIR/gost-pids.txt"

if [ -f "$PIDFILE" ]; then
    echo "Menghentikan gost dari daftar PID ..."
    while read -r pid; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done < "$PIDFILE"
    : > "$PIDFILE"
fi

# jaga-jaga, matikan sisa proses gost
pkill -f "/usr/local/bin/gost" 2>/dev/null
pkill -x gost 2>/dev/null

echo "Semua proxy gost dihentikan."
