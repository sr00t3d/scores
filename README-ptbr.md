[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# scores

![scores cover](scores-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/scores/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Apache%20%7C%20MySQL-lightgrey.svg)](#requisitos)

**CLI de Triagem Rápida de Load Linux, MySQL/MariaDB e Top VHosts do Apache.**

O `scores.sh` entrega um raio-X instantâneo em picos de carga: lê `/proc/loadavg`, `/proc/stat` (`usr/ni/sys/iowait/id`) e `/proc/meminfo`, contabiliza CPU % e threads do MySQL/MariaDB e processos Apache, analisa o `mod_status` diretamente sem `lynx`/`elinks`/`bc`/`iostat` e ranqueia os **Top N VHosts com sua Top URI e Top IP unificados**.

> **Inspiração Histórica:** Reimplementação limpa em Bash + Python 3.6+ (`v2.0.0`) inspirada no clássico `scores` (2011, ford / jshanley / escalf, HostGator.com, LLC).

---

## Execução Direta

```bash
curl -fsSL https://raw.githubusercontent.com/sr00t3d/scores/main/scores.sh -o scores.sh
chmod +x scores.sh
./scores.sh --url http://127.0.0.1/server-status
```

---

## Exemplo de Saída Real

```text
================================================================================================
 scores.sh v2.0.0 | System & Apache Triage | 2026-11-24T03:24:14Z
================================================================================================
Load:    2.12, 2.12, 2.16 (16 CPUs)  |  Memory: 9876/15586 MiB (63.4%)
CPU%:    8.9/usr  0.0/ni  1.3/sys  0.0/wa  89.6/id
MySQL:   3.3% CPU  (45 threads)  |  Apache procs: 0
Apache:  85.2 req/s  |  Busy=12 Idle=8  |  Uptime: 7 days 3 hours 20 minutes
------------------------------------------------------------------------------------------------
RANK  HITS   VHOST                        TOP_URI (HITS)                         TOP_IP
----- ------ ---------------------------- -------------------------------------- ---------------
1     2      alpha.com                    POST /xmlrpc.php (2)                   198.51.100.10
2     1      beta.org                     GET /wp-cron.php (1)                   203.0.113.55
```

---

## Licença

Distribuído sob a licença [Apache License 2.0](LICENSE).
