#!/usr/bin/env python3
"""
GSOCKS Proxy Web Panel
- Login password
- Start / Stop / Restart semua proxy
- Test proxy (cek IP keluar)
- Tambah / hapus proxy
- Status realtime (RAM, CPU, jumlah proses)
"""
import os, re, json, subprocess, secrets, time, threading
from functools import wraps
from flask import (Flask, request, session, redirect, url_for,
                   render_template, jsonify, Response)

# ================== KONFIG ==================
BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
PROXY_DIR  = os.environ.get("PROXY_DIR", os.path.join(BASE_DIR, "..", "linux-datacenter"))
PROXY_DIR  = os.path.abspath(PROXY_DIR)
PROXIES_TXT= os.path.join(PROXY_DIR, "proxies.txt")
PIDFILE    = os.path.join(PROXY_DIR, "gost-pids.txt")
START_PORT = 1080
GOST       = "/usr/local/bin/gost"

# password panel (ganti lewat ENV PANEL_PASSWORD)
PANEL_PASSWORD = os.environ.get("PANEL_PASSWORD", "admin123")

app = Flask(__name__)
app.secret_key = os.environ.get("PANEL_SECRET", secrets.token_hex(16))

# ================== AUTH ==================
def login_required(f):
    @wraps(f)
    def wrap(*a, **k):
        if not session.get("auth"):
            if request.path.startswith("/api/"):
                return jsonify({"error": "unauthorized"}), 401
            return redirect(url_for("login"))
        return f(*a, **k)
    return wrap

@app.route("/login", methods=["GET", "POST"])
def login():
    err = ""
    if request.method == "POST":
        if request.form.get("password") == PANEL_PASSWORD:
            session["auth"] = True
            return redirect(url_for("index"))
        err = "Password salah"
    return render_template("login.html", err=err)

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

# ================== HELPERS ==================
def read_proxies():
    items = []
    if not os.path.exists(PROXIES_TXT):
        return items
    with open(PROXIES_TXT, "r") as f:
        port = START_PORT
        for line in f:
            s = line.strip()
            if not s or s.upper().startswith("REM") or s.startswith("#"):
                continue
            parts = s.split(":")
            if len(parts) < 4:
                continue
            host, pport, user, pwd = parts[0], parts[1], parts[2], parts[3]
            items.append({
                "local_port": port, "host": host, "port": pport,
                "user": user, "raw": s
            })
            port += 1
    return items

def write_proxies(lines):
    header = ["REM Daftar proxy gsocks. Format: host:port:username:password", "REM"]
    with open(PROXIES_TXT, "w") as f:
        f.write("\n".join(header + lines) + "\n")

def gost_count():
    try:
        out = subprocess.run(["pgrep", "-x", "gost"], capture_output=True, text=True)
        return len([x for x in out.stdout.split() if x.strip()])
    except Exception:
        return 0

def listening_count():
    try:
        out = subprocess.run("ss -tlnp 2>/dev/null | grep -c gost",
                             shell=True, capture_output=True, text=True)
        return int(out.stdout.strip() or 0)
    except Exception:
        return 0

def gost_mem_mb():
    try:
        out = subprocess.run("ps -C gost -o rss= 2>/dev/null | awk '{s+=$1} END{print int(s/1024)}'",
                             shell=True, capture_output=True, text=True)
        return int(out.stdout.strip() or 0)
    except Exception:
        return 0

def sys_info():
    info = {"cpu_cores": os.cpu_count() or 0, "ram_total": 0, "ram_used": 0}
    try:
        with open("/proc/meminfo") as f:
            m = {}
            for line in f:
                k, v = line.split(":")
                m[k.strip()] = int(v.strip().split()[0])
        info["ram_total"] = m.get("MemTotal", 0) // 1024
        avail = m.get("MemAvailable", 0) // 1024
        info["ram_used"] = info["ram_total"] - avail
    except Exception:
        pass
    return info

def run_script(name, args=None):
    """Jalankan script .sh di PROXY_DIR."""
    path = os.path.join(PROXY_DIR, name)
    cmd = ["bash", path] + (args or [])
    return subprocess.run(cmd, cwd=PROXY_DIR, capture_output=True, text=True, timeout=600)

# ================== HALAMAN ==================
@app.route("/")
@login_required
def index():
    return render_template("index.html")

# ================== API ==================
@app.route("/api/status")
@login_required
def api_status():
    running = gost_count()
    listen = listening_count()
    si = sys_info()
    return jsonify({
        "running": running,
        "listening": listen,
        "active": running > 0,
        "gost_mem_mb": gost_mem_mb(),
        "start_port": START_PORT,
        "end_port": START_PORT + listen - 1 if listen else START_PORT,
        "total_proxies": len(read_proxies()),
        "sys": si,
    })

@app.route("/api/proxies")
@login_required
def api_proxies():
    return jsonify(read_proxies())

@app.route("/api/proxy/add", methods=["POST"])
@login_required
def api_add():
    d = request.get_json(force=True)
    raw = (d.get("raw") or "").strip()
    # validasi format host:port:user:pass
    if not re.match(r"^[^:]+:\d+:[^:]+:[^:]+$", raw):
        return jsonify({"error": "Format harus host:port:user:pass"}), 400
    items = [p["raw"] for p in read_proxies()]
    if raw in items:
        return jsonify({"error": "Proxy sudah ada"}), 400
    items.append(raw)
    write_proxies(items)
    return jsonify({"ok": True, "total": len(items)})

@app.route("/api/proxy/delete", methods=["POST"])
@login_required
def api_delete():
    d = request.get_json(force=True)
    raw = (d.get("raw") or "").strip()
    items = [p["raw"] for p in read_proxies() if p["raw"] != raw]
    write_proxies(items)
    return jsonify({"ok": True, "total": len(items)})

@app.route("/api/action/<name>", methods=["POST"])
@login_required
def api_action(name):
    mapping = {
        "start": "start-single.sh",
        "stop":  "stop-all.sh",
    }
    if name not in mapping:
        return jsonify({"error": "aksi tidak dikenal"}), 400
    try:
        r = run_script(mapping[name])
        # bersihkan kode warna ANSI dari output
        clean = re.sub(r"\x1b\[[0-9;]*m", "", (r.stdout or "") + (r.stderr or ""))
        return jsonify({"ok": True, "output": clean[-4000:]})
    except subprocess.TimeoutExpired:
        return jsonify({"error": "timeout"}), 500

@app.route("/api/test")
@login_required
def api_test():
    """Tes beberapa port, stream hasil."""
    sample = request.args.get("count", "10")
    try:
        n = min(int(sample), 50)
    except Exception:
        n = 10
    proxies = read_proxies()[:n]

    def gen():
        for p in proxies:
            port = p["local_port"]
            try:
                out = subprocess.run(
                    ["curl", "-s", "--max-time", "15", "--socks5-hostname",
                     f"127.0.0.1:{port}", "https://api.ipify.org"],
                    capture_output=True, text=True, timeout=20)
                ip = out.stdout.strip()
                ok = bool(re.match(r"^\d+\.\d+\.\d+\.\d+$", ip))
            except Exception:
                ip, ok = "", False
            yield json.dumps({"port": port, "ip": ip, "ok": ok}) + "\n"
    return Response(gen(), mimetype="application/x-ndjson")

if __name__ == "__main__":
    port = int(os.environ.get("PANEL_PORT", "8088"))
    app.run(host="0.0.0.0", port=port)
