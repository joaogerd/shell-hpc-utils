# shell-hpc-utils
![HPC](https://img.shields.io/badge/HPC-Supercomputador-blue)
![CPTEC-INPE](https://img.shields.io/badge/CPTEC-INPE-brightgreen)

A modular, production-grade collection of Bash helpers for HPC environments.

This project originated from real-world operational scripts used on large
HPC systems (e.g. Cray XC50, EGEON), and was refactored into a clean,
auditable, and reusable helper library.

## Goals

- Clean separation of concerns (core / project / hpc / utils)
- Safe Bash practices (scoped strict mode, defensive sourcing)
- Centralized logging with color, verbosity, timestamps
- HPC-aware environment detection and toolchain hygiene
- Zero hidden side effects

## Layout

```

helpers/
├── core/      # Shell infrastructure (logging, fs, args, strict mode)
├── project/   # Project root discovery and bootstrap helpers
├── hpc/       # Cluster and scheduler specific helpers
├── utils/     # Pure utility helpers
└── **helpers**.sh  # Thin wrapper / façade

````

## Usage

Source the wrapper in your script:

```bash
#!/usr/bin/env bash
source /path/to/shell-hpc-utils/helpers/__helpers__.sh
````

All helpers become available in the current shell.

### Example

```bash
detect_hpc_system
disable_conda

_bootstrap_env_root SMG_ROOT ".smg_root" || exit 1

_log_info "Running on %s (%s)" "$hpc_name" "$hpc_system"
```

## Design Principles

* **Explicit is better than implicit**
* **Wrapper contains no logic**
* **Modules are auditable via diff**
* **HPC ≠ project ≠ shell core**

