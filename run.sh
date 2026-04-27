#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="$DIR/venv/bin/python"

if [ ! -f "$PYTHON" ]; then
    echo "[ERROR] Venv introuvable. Lance d'abord :"
    echo "  python -m venv venv && venv/bin/pip install -r requirements.txt"
    exit 1
fi

"$PYTHON" "$DIR/main.py" "$@"
