#!/usr/bin/env bash
# Matikan proxy (mode single-process) dengan tampilan rapi.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$DIR/gost-single.pid"
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; N='\033[0m'; W='\033[1;37m'

echo ""
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  PID=$(cat "$PIDFILE")
  echo -e "  ${Y}↻ Menghentikan gost (PID $PID)...${N}"
  kill "$PID" 2>/dev/null
  sleep 1
  kill -9 "$PID" 2>/dev/null
  rm -f "$PIDFILE"
  echo -e "  ${G}✔ Semua proxy dihentikan.${N}"
else
  # fallback
  if pkill -f "gost -C" 2>/dev/null; then
    echo -e "  ${G}✔ Proxy dihentikan (fallback).${N}"
  else
    echo -e "  ${R}• Tidak ada proxy yang berjalan.${N}"
  fi
  rm -f "$PIDFILE" 2>/dev/null
fi
echo ""
