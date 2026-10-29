#!/usr/bin/env bash
# ============================================================
#  Tester semua proxy lokal (tampilan rapi + progress + ringkasan)
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/proxies.txt"
OUT="$DIR/hasil-test.txt"
START_PORT=1080
TIMEOUT=15
PARALLEL="${1:-50}"   # jumlah tes paralel (default 50), bisa override: ./test-all.sh 100

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

TOTAL=$(grep -vcE '^\s*(REM|#|$)' "$LIST")
END_PORT=$((START_PORT + TOTAL - 1))

clear
echo -e "${B}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo -e "  ║   ${W}P R O X Y   T E S T E R${B}                                ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${N}"
echo -e "  ${W}Total${N}    : ${G}${TOTAL}${N} proxy"
echo -e "  ${W}Port${N}     : 127.0.0.1:${START_PORT} ${D}..${N} 127.0.0.1:${END_PORT}"
echo -e "  ${W}Paralel${N}  : ${PARALLEL}  ${D}(timeout ${TIMEOUT}s)${N}"
echo ""

TMP=$(mktemp -d)
test_one() {
  local port=$1
  local ip
  ip=$(curl -s --max-time "$TIMEOUT" --socks5-hostname "127.0.0.1:$port" https://api.ipify.org 2>/dev/null)
  if echo "$ip" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "OK $port $ip"
  else
    echo "FAIL $port -"
  fi
}
export -f test_one
export TIMEOUT

# jalankan paralel
seq $START_PORT $END_PORT | xargs -P "$PARALLEL" -I{} bash -c 'test_one "$@"' _ {} > "$TMP/res.txt" 2>/dev/null &
XPID=$!

# progress sambil nunggu
barlen=40
while kill -0 $XPID 2>/dev/null; do
  done_n=$(wc -l < "$TMP/res.txt" 2>/dev/null || echo 0)
  [ "$TOTAL" -gt 0 ] || TOTAL=1
  filled=$(( done_n * barlen / TOTAL ))
  [ $filled -gt $barlen ] && filled=$barlen
  bar=$(printf '%*s' "$filled" '' | tr ' ' '#')
  space=$(printf '%*s' "$((barlen - filled))" '')
  pct=$(( done_n * 100 / TOTAL ))
  echo -ne "\r  ${B}[${G}${bar}${D}${space}${B}]${N} ${W}${pct}%%${N} ${D}(${done_n}/${TOTAL})${N}  "
  sleep 0.3
done
wait $XPID

done_n=$(wc -l < "$TMP/res.txt")
echo -ne "\r  ${B}[${G}$(printf '%*s' $barlen '' | tr ' ' '#')${B}]${N} ${W}100%%${N} ${D}(${done_n}/${TOTAL})${N}  \n\n"

OK=$(grep -c '^OK' "$TMP/res.txt")
FAIL=$(grep -c '^FAIL' "$TMP/res.txt")
UNIQ=$(grep '^OK' "$TMP/res.txt" | awk '{print $3}' | sort -u | wc -l)

# simpan hasil rapi
{
  echo "Hasil test - $(date)"
  echo "Total $TOTAL | OK $OK | FAIL $FAIL | IP unik $UNIQ"
  echo "----------------------------------------"
  sort -t' ' -k2 -n "$TMP/res.txt" | while read -r st port ip; do
    printf "127.0.0.1:%-6s -> %s (%s)\n" "$port" "$ip" "$st"
  done
} > "$OUT"

# ringkasan di layar
echo -e "  ${G}╔════════════════════════════════════════════╗${N}"
echo -e "  ${G}║                 RINGKASAN                  ║${N}"
echo -e "  ${G}╚════════════════════════════════════════════╝${N}"
echo -e "    ${W}Total${N}    : ${TOTAL}"
echo -e "    ${W}Jalan${N}    : ${G}${OK}${N}"
echo -e "    ${W}Mati${N}     : ${R}${FAIL}${N}"
echo -e "    ${W}IP unik${N}  : ${B}${UNIQ}${N}  ${D}(variasi IP keluar)${N}"
echo ""
echo -e "  ${D}Contoh 5 proxy pertama:${N}"
grep '^OK' "$TMP/res.txt" | sort -t' ' -k2 -n | head -5 | while read -r st port ip; do
  echo -e "    ${G}●${N} 127.0.0.1:${port} -> ${W}${ip}${N}"
done
echo ""
echo -e "  ${D}Hasil lengkap: ${W}hasil-test.txt${N}"
echo ""

rm -rf "$TMP"
