#!/usr/bin/env bash
# Wrapper for the Python cleaning step (called by Hop Shell action).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 cleaning/clean.py
