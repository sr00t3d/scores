[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# scores

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

## Licença

Distribuído sob a licença [Apache License 2.0](LICENSE).
