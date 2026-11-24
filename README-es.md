[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# scores

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/scores/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Apache%20%7C%20MySQL-lightgrey.svg)](#requisitos)

**CLI de Triaje Rápido de Carga Linux, MySQL/MariaDB y Top VHosts de Apache.**

`scores.sh` muestra al instante carga, CPU (`usr/ni/sys/iowait/id`), memoria, CPU/threads de MySQL/MariaDB y ranking de **Top N VHosts con su Top URI y Top IP**, sin depender de `lynx`, `elinks`, `bc` ni `iostat`.

> **Inspiración Histórica:** Reimplementación limpia en Bash + Python 3.6+ (`v2.0.0`) inspirada en `scores` (2011, ford / jshanley / escalf, HostGator.com, LLC).

---

## Ejecución Directa

```bash
curl -fsSL https://raw.githubusercontent.com/sr00t3d/scores/main/scores.sh -o scores.sh
chmod +x scores.sh
./scores.sh --url http://127.0.0.1/server-status
```

---

## Licencia

Licenciado bajo [Apache License 2.0](LICENSE).
