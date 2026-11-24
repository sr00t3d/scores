[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# scores

![scores cover](scores-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/scores/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requirements)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Apache%20%7C%20MySQL-lightgrey.svg)](#requirements)

**Linux Load, MySQL/MariaDB & Apache Top-Offenders Triage CLI.**

`scores.sh` provides an instant single-screen triage snapshot during high server load: it reads `/proc/loadavg`, `/proc/stat` (CPU `usr/ni/sys/iowait/id`), and `/proc/meminfo`, inspects MySQL/MariaDB CPU % & thread counts alongside Apache worker counts, parses `mod_status` directly over HTTP or from a saved file, and ranks **Top N VHosts with their unified Top URI and Top Client IP**.

> **Historical Inspiration:** Clean-room Bash + Python 3.6+ `v2.0.0` reimplementation inspired by `scores` (2011, ford / jshanley / escalf, HostGator.com, LLC). Eliminates silent `yum install bc/elinks -y` mutations, a broken `check_result()` bug (`$1` compared against `$1`), external dependencies on `lynx`/`iostat`/`bc`/`/root/bin/scoreboard`, predictable `/root/tmp` tempfiles, and mismatched `TOPURICOUNT` vs `TOPURI` calculations.

---

## Requirements

- Linux with Bash 4.0+ and Python 3.6+ (standard library only)

---

## Direct Execution

```bash
curl -fsSL https://raw.githubusercontent.com/sr00t3d/scores/main/scores.sh -o scores.sh
chmod +x scores.sh
./scores.sh --url http://127.0.0.1/server-status
```

---

## Usage

```bash
# 1. Instant system + MySQL + Apache Top-5 VHosts triage
./scores.sh

# 2. Show Top 10 VHosts from a custom server-status URL
./scores.sh --url http://127.0.0.1/server-status --top 10

# 3. Alert with exit code 2 when 1m load >= 8.0, or export JSON
./scores.sh --warn-load 8.0 --exit-code
./scores.sh --file /tmp/server-status.html -o json

# 4. Live refresh every 3 seconds
./scores.sh --watch 3
```

---

## License

Licensed under the [Apache License 2.0](LICENSE).
