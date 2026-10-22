#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root/riscv-opcodes"
PYTHONPATH=src python3 -m riscv_opcodes 'rv*'
