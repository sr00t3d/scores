#!/usr/bin/env bash
# ==============================================================================
# scores.sh — Linux Load, MySQL & Apache Top-Offenders Triage CLI (v2.0.0)
# ==============================================================================
# Clean-room Bash + Python 3.6+ reimplementation inspired by scores (2011,
# ford / jshanley / escalf, HostGator.com, LLC).
#
# Eliminates silent yum package installs (bc/elinks), broken check_result(),
# external dependencies on lynx/iostat/bc/scoreboard, /root/tmp tempfiles, and
# mismatched TOPURICOUNT vs TOPURI calculations.
#
# Reads Linux /proc telemetry directly (loadavg, CPU usr/sys/iowait/idle, RAM),
# inspects Apache & MySQL/MariaDB processes + thread counts, parses Apache
# mod_status HTML/?auto directly, ranks Top N VHosts & Top URIs, and supports
# --watch, --warn-load + --exit-code, and table/json/csv outputs.
#
# License: Apache-2.0
# Author:  Percio Castelo (https://perciocastelo.com.br)
# Repo:    https://github.com/sr00t3d/scores
# ==============================================================================

set -euo pipefail

readonly SCRIPT_NAME="scores.sh"
readonly SCRIPT_VERSION="2.0.0"

URL=""
FILE_PATH=""
TOP_N="5"
DOMAIN_WARN_THRESHOLD="100"
TIMEOUT_SEC="6"
INSECURE=0
WATCH_SEC="0"
WARN_LOAD=""
EXIT_CODE_MODE=0
OUTPUT_FMT="table"
QUIET=0
NO_COLOR=0

C_RED=""
C_GREEN=""
C_YELLOW=""
C_CYAN=""
C_BOLD=""
C_RESET=""

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && "$OUTPUT_FMT" == "table" ]]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_CYAN=$'\033[0;36m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
  fi
}

usage() {
  cat <<EOF
${SCRIPT_NAME} v${SCRIPT_VERSION} — Linux Load, MySQL & Apache Top-Offenders Triage CLI

Usage:
  ${SCRIPT_NAME} [options]

Options:
  -u, --url <url>         Apache server-status URL (default: auto-probe localhost)
  -f, --file <path>       Parse saved Apache mod_status HTML/?auto file
  -n, --top <N>           Number of top VHosts to show (default: 5)
  --timeout <sec>         HTTP timeout in seconds (default: 6)
  -k, --insecure          Allow self-signed TLS certificates
  --watch <sec>           Refresh continuously every <sec> seconds
  --warn-load <float>     1-min load average threshold for alert / --exit-code (2)
  --exit-code             Exit 2 if 1m load >= --warn-load (or >= CPU core count if unset)
  -o, --output <fmt>      Output format: table (default), json, csv
  -q, --quiet             Minimal output
  --no-color              Disable ANSI colors
  -h, --help              Show this help
  -v, --version           Show version

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --url http://127.0.0.1/server-status --top 10
  ${SCRIPT_NAME} --file /tmp/whm-server-status.html -o json
  ${SCRIPT_NAME} --warn-load 8.0 --exit-code
  ${SCRIPT_NAME} --watch 3
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -v|--version) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      -u|--url)
        [[ $# -ge 2 ]] || { printf '[ERR] --url requires a URL.\n' >&2; exit 1; }
        URL="$2"; shift 2 ;;
      -f|--file)
        [[ $# -ge 2 ]] || { printf '[ERR] --file requires a path.\n' >&2; exit 1; }
        FILE_PATH="$2"; shift 2 ;;
      -n|--top)
        [[ $# -ge 2 ]] || { printf '[ERR] --top requires an integer.\n' >&2; exit 1; }
        TOP_N="$2"; shift 2 ;;
      --timeout)
        [[ $# -ge 2 ]] || { printf '[ERR] --timeout requires seconds.\n' >&2; exit 1; }
        TIMEOUT_SEC="$2"; shift 2 ;;
      -k|--insecure) INSECURE=1; shift ;;
      --watch)
        [[ $# -ge 2 ]] || { printf '[ERR] --watch requires seconds.\n' >&2; exit 1; }
        WATCH_SEC="$2"; shift 2 ;;
      --warn-load)
        [[ $# -ge 2 ]] || { printf '[ERR] --warn-load requires a number.\n' >&2; exit 1; }
        WARN_LOAD="$2"; shift 2 ;;
      --exit-code) EXIT_CODE_MODE=1; shift ;;
      -o|--output)
        [[ $# -ge 2 ]] || { printf '[ERR] --output requires table|json|csv.\n' >&2; exit 1; }
        OUTPUT_FMT="$2"; shift 2 ;;
      -q|--quiet) QUIET=1; shift ;;
      --no-color) NO_COLOR=1; shift ;;
      *)
        printf '[ERR] Unknown option: %s\n' "$1" >&2
        exit 1 ;;
    esac
  done

  [[ "$TOP_N" =~ ^[0-9]+$ && "$TOP_N" -ge 1 ]] || { printf '[ERR] --top must be >= 1.\n' >&2; exit 1; }
  case "$OUTPUT_FMT" in
    table|json|csv) ;;
    *) printf '[ERR] Invalid --output: %s\n' "$OUTPUT_FMT" >&2; exit 1 ;;
  esac
}

main() {
  parse_args "$@"

  if ! command -v python3 >/dev/null 2>&1; then
    printf '[ERR] python3 is required.\n' >&2
    exit 1
  fi

  init_colors

  local py_script
  py_script="$(cat <<'PYEOF'
import collections
import csv
import html
import io
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.request
from html.parser import HTMLParser

(
    url_opt, file_opt, top_n_s, dom_warn_s, timeout_s, insecure_s,
    watch_s, warn_load_opt, exit_code_s, fmt, quiet_s,
    script_name, script_version,
    c_red, c_green, c_yellow, c_cyan, c_bold, c_reset
) = sys.argv[1:20]

top_n = int(top_n_s)
dom_warn_thresh = int(dom_warn_s)
timeout = float(timeout_s)
insecure = insecure_s == "1"
watch_sec = int(watch_s)
exit_code_mode = exit_code_s == "1"
quiet = quiet_s == "1"

DEFAULT_URLS = [
    "http://127.0.0.1/whm-server-status",
    "http://127.0.0.1/server-status",
    "http://localhost/whm-server-status",
    "http://localhost/server-status",
]


class StatusTableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self._in_table = False
        self._in_tr = False
        self._in_cell = False
        self._cur_table = []
        self._cur_row = []
        self._cur_cell = []
        self._cur_is_hdr = False

    def handle_starttag(self, tag, attrs):
        t = tag.lower()
        if t == "table":
            self._in_table = True
            self._cur_table = []
        elif t == "tr" and self._in_table:
            self._in_tr = True
            self._cur_row = []
        elif t in ("th", "td") and self._in_tr:
            self._in_cell = True
            self._cur_cell = []
            self._cur_is_hdr = (t == "th")

    def handle_endtag(self, tag):
        t = tag.lower()
        if t == "table" and self._in_table:
            if self._cur_table:
                self.tables.append(self._cur_table)
            self._in_table = False
        elif t == "tr" and self._in_tr:
            if self._cur_row:
                self._cur_table.append(self._cur_row)
            self._in_tr = False
        elif t in ("th", "td") and self._in_cell:
            txt = " ".join("".join(self._cur_cell).split())
            self._cur_row.append((self._cur_is_hdr, txt))
            self._in_cell = False

    def handle_data(self, data):
        if self._in_cell:
            self._cur_cell.append(data)


def read_proc_load():
    cpus = os.cpu_count() or 1
    load1, load5, load15 = 0.0, 0.0, 0.0
    try:
        with open("/proc/loadavg", "r") as f:
            parts = f.read().split()
            load1, load5, load15 = float(parts[0]), float(parts[1]), float(parts[2])
    except Exception:
        pass
    return {"cpus": cpus, "load1": load1, "load5": load5, "load15": load15}


def read_proc_cpu_pct():
    def snap():
        with open("/proc/stat", "r") as f:
            for ln in f:
                if ln.startswith("cpu "):
                    vals = [int(x) for x in ln.split()[1:8]]
                    while len(vals) < 7:
                        vals.append(0)
                    return vals
        return [0] * 7
    try:
        a = snap()
        time.sleep(0.25)
        b = snap()
        d = [b[i] - a[i] for i in range(7)]
        tot = sum(d) or 1
        return {
            "usr": round((d[0] / tot) * 100.0, 1),
            "nice": round((d[1] / tot) * 100.0, 1),
            "sys": round((d[2] / tot) * 100.0, 1),
            "idle": round((d[3] / tot) * 100.0, 1),
            "iowait": round((d[4] / tot) * 100.0, 1),
        }
    except Exception:
        return {"usr": 0.0, "nice": 0.0, "sys": 0.0, "idle": 100.0, "iowait": 0.0}


def read_proc_mem():
    info = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for ln in f:
                if ":" in ln:
                    k, v = ln.split(":", 1)
                    info[k.strip()] = int(v.strip().split()[0])
        tot = info.get("MemTotal", 0)
        avail = info.get("MemAvailable", info.get("MemFree", 0))
        used = max(0, tot - avail)
        return {
            "total_mib": round(tot / 1024.0, 0),
            "used_mib": round(used / 1024.0, 0),
            "used_pct": round((used / float(tot)) * 100.0, 1) if tot > 0 else 0.0,
        }
    except Exception:
        return {"total_mib": 0, "used_mib": 0, "used_pct": 0.0}


def read_process_stats():
    mysql_cpu = 0.0
    mysql_threads = 0
    apache_procs = 0
    try:
        p = subprocess.run(
            ["ps", "-eo", "comm,pcpu,nlwp", "--no-headers"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=5,
        )
        for ln in p.stdout.splitlines():
            parts = ln.split()
            if len(parts) < 3:
                continue
            comm, pcpu_s, nlwp_s = parts[0], parts[1], parts[2]
            if comm in ("mysqld", "mariadbd", "mysqld_safe"):
                mysql_cpu += float(pcpu_s)
                mysql_threads += int(nlwp_s)
            elif comm in ("httpd", "apache2"):
                apache_procs += 1
    except Exception:
        pass
    return {
        "mysql_cpu_pct": round(mysql_cpu, 1),
        "mysql_threads": mysql_threads,
        "apache_procs": apache_procs,
    }


def load_apache_status():
    raw = None
    src = None
    err_msg = None
    if file_opt:
        with open(file_opt, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
        src = file_opt
    else:
        candidates = [url_opt] if url_opt else DEFAULT_URLS
        for cand in candidates:
            try:
                req = urllib.request.Request(cand, headers={"User-Agent": f"{script_name}/{script_version}"})
                ctx = None
                if insecure and cand.lower().startswith("https://"):
                    ctx = ssl.create_default_context()
                    ctx.check_hostname = False
                    ctx.verify_mode = ssl.CERT_NONE
                with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                    body = resp.read().decode("utf-8", errors="replace")
                if any(k in body for k in ("Apache Server Status", "BusyWorkers", "Total Accesses", "<table")):
                    raw = body
                    src = cand
                    break
            except Exception as e:
                err_msg = str(e)
                continue

    if not raw:
        return {"available": False, "source": None, "error": err_msg or "Apache server-status unreachable", "top_vhosts": []}

    metrics = {"req_per_sec": None, "busy_workers": None, "idle_workers": None, "uptime": None}
    plain = re.sub(r'<[^>]+>', '\n', html.unescape(raw))
    for ln in plain.splitlines():
        line = ln.strip()
        m_bw = re.match(r'^(\d+)\s+requests currently being processed,\s+(\d+)\s+idle workers', line)
        if m_bw:
            metrics["busy_workers"] = int(m_bw.group(1))
            metrics["idle_workers"] = int(m_bw.group(2))
        elif line.startswith("Server uptime:"):
            metrics["uptime"] = line.split(":", 1)[1].strip()
        elif "requests/sec" in line and metrics["req_per_sec"] is None:
            m_r = re.search(r'([0-9.]+)\s+requests/sec', line)
            if m_r:
                metrics["req_per_sec"] = float(m_r.group(1))

    parser = StatusTableParser()
    parser.feed(raw)
    vhost_hits = collections.Counter()
    vhost_uris = collections.defaultdict(collections.Counter)
    vhost_ips = collections.defaultdict(collections.Counter)

    for tbl in parser.tables:
        if len(tbl) < 2:
            continue
        hdrs = [c[1].strip().lower() for c in tbl[0]]
        if not ("vhost" in hdrs and "request" in hdrs):
            continue
        cmap = {h: idx for idx, h in enumerate(hdrs)}
        for row in tbl[1:]:
            if all(c[0] for c in row):
                continue
            vals = [c[1] for c in row]
            m_val = vals[cmap["m"]].strip() if "m" in cmap and cmap["m"] < len(vals) else ""
            if m_val in (".", "_"):
                continue
            vh = vals[cmap["vhost"]].strip().lower()
            vh = re.sub(r'^www\.', '', vh).split(":", 1)[0]
            if not vh or vh == "-":
                continue
            req = vals[cmap["request"]].strip()
            uri = req
            m_u = re.match(r'^([A-Z]+)\s+(\S+)', req)
            if m_u:
                uri = f"{m_u.group(1)} {m_u.group(2).split('?', 1)[0]}"
            ip = vals[cmap["client"]].strip() if "client" in cmap and cmap["client"] < len(vals) else "-"
            vhost_hits[vh] += 1
            vhost_uris[vh][uri] += 1
            if ip and ip != "-":
                vhost_ips[vh][ip] += 1

    top_vhosts = []
    for vh, cnt in vhost_hits.most_common(top_n):
        top_u, top_u_cnt = vhost_uris[vh].most_common(1)[0]
        top_i, top_i_cnt = vhost_ips[vh].most_common(1)[0] if vhost_ips[vh] else ("-", 0)
        top_vhosts.append({
            "vhost": vh,
            "hits": cnt,
            "top_uri": top_u,
            "top_uri_hits": top_u_cnt,
            "top_ip": top_i,
            "top_ip_hits": top_i_cnt,
        })

    return {"available": True, "source": src, "metrics": metrics, "top_vhosts": top_vhosts}


def count_server_domains():
    if not os.path.isfile("/etc/userdomains"):
        return None
    try:
        with open("/etc/userdomains", "r", encoding="utf-8", errors="ignore") as f:
            return sum(1 for ln in f if ":" in ln and not ln.startswith("*:"))
    except Exception:
        return None


def run_once():
    ts_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    load = read_proc_load()
    cpu = read_proc_cpu_pct()
    mem = read_proc_mem()
    procs = read_process_stats()
    apache = load_apache_status()
    dom_cnt = count_server_domains()

    thresh = float(warn_load_opt) if warn_load_opt else float(load["cpus"])
    alert = load["load1"] >= thresh

    payload = {
        "tool": script_name,
        "version": script_version,
        "timestamp_utc": ts_utc,
        "system": {
            "load": load,
            "cpu_pct": cpu,
            "memory": mem,
            "processes": procs,
            "domain_count": dom_cnt,
            "load_alert": alert,
            "load_threshold": thresh,
        },
        "apache": apache,
    }

    if fmt == "json":
        print(json.dumps(payload, indent=2))
        return 2 if (exit_code_mode and alert) else 0

    if fmt == "csv":
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(["RANK", "VHOST", "HITS", "TOP_URI_HITS", "TOP_URI", "TOP_IP"])
        for idx, v in enumerate(apache.get("top_vhosts", []), 1):
            w.writerow([idx, v["vhost"], v["hits"], v["top_uri_hits"], v["top_uri"], v["top_ip"]])
        sys.stdout.write(buf.getvalue())
        return 2 if (exit_code_mode and alert) else 0

    if not quiet:
        print("=" * 96)
        print(f" {c_bold}{script_name} v{script_version}{c_reset} | System & Apache Triage | {ts_utc}")
        print("=" * 96)
        l_col = c_red if alert else c_green
        print(f"Load:    {l_col}{load['load1']:.2f}, {load['load5']:.2f}, {load['load15']:.2f}{c_reset} ({load['cpus']} CPUs)  |  Memory: {int(mem['used_mib'])}/{int(mem['total_mib'])} MiB ({mem['used_pct']}%)")
        print(f"CPU%:    {cpu['usr']}/usr  {cpu['nice']}/ni  {cpu['sys']}/sys  {cpu['iowait']}/wa  {cpu['idle']}/id")
        print(f"MySQL:   {procs['mysql_cpu_pct']}% CPU  ({procs['mysql_threads']} threads)  |  Apache procs: {procs['apache_procs']}")
        if apache["available"]:
            m = apache["metrics"]
            bw = m["busy_workers"] if m["busy_workers"] is not None else "-"
            iw = m["idle_workers"] if m["idle_workers"] is not None else "-"
            rps = m["req_per_sec"] if m["req_per_sec"] is not None else "-"
            up = m["uptime"] or "-"
            print(f"Apache:  {rps} req/s  |  Busy={bw} Idle={iw}  |  Uptime: {up}")
        else:
            print(f"Apache:  {c_yellow}{apache['error']}{c_reset}")
        if dom_cnt is not None and dom_cnt > dom_warn_thresh:
            print(f"{c_yellow}[NOTE]{c_reset} Server hosts {dom_cnt} domains (> {dom_warn_thresh})")
        print("-" * 96)

    vhosts = apache.get("top_vhosts", [])
    if not vhosts:
        print(f"{c_green}[CLEAN]{c_reset} No active VHost traffic captured.")
    else:
        print(f"{c_bold}{'RANK':<5} {'HITS':<6} {'VHOST':<28} {'TOP_URI (HITS)':<38} {'TOP_IP'}{c_reset}")
        print(f"{'-'*5} {'-'*6} {'-'*28} {'-'*38} {'-'*15}")
        for idx, v in enumerate(vhosts, 1):
            uri_s = f"{v['top_uri'][:28]} ({v['top_uri_hits']})"
            print(f"{idx:<5} {v['hits']:<6} {v['vhost'][:28]:<28} {uri_s:<38} {v['top_ip']}")

    return 2 if (exit_code_mode and alert) else 0


try:
    if watch_sec > 0:
        while True:
            if fmt == "table" and sys.stdout.isatty():
                sys.stdout.write("\033[2J\033[H")
            run_once()
            sys.stdout.flush()
            time.sleep(watch_sec)
    else:
        sys.exit(run_once())
except KeyboardInterrupt:
    sys.exit(0)
except Exception as e:
    print(f"[ERR] {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)"

  python3 -c "$py_script" \
    "$URL" "$FILE_PATH" "$TOP_N" "$DOMAIN_WARN_THRESHOLD" "$TIMEOUT_SEC" "$INSECURE" \
    "$WATCH_SEC" "$WARN_LOAD" "$EXIT_CODE_MODE" "$OUTPUT_FMT" "$QUIET" \
    "$SCRIPT_NAME" "$SCRIPT_VERSION" \
    "$C_RED" "$C_GREEN" "$C_YELLOW" "$C_CYAN" "$C_BOLD" "$C_RESET"
}

main "$@"
