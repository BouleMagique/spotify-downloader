#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="$DIR/venv/bin/python"
PIP="$DIR/venv/bin/pip"

if [ "${1:-}" = "update" ]; then
    echo "[INFO] Mise a jour du code..."
    git -C "$DIR" pull origin
    echo "[INFO] Mise a jour des dependances..."
    "$PIP" install -r "$DIR/requirements.txt" --quiet
    echo "[OK] Mise a jour terminee."
    exit 0
fi

if [ ! -f "$PYTHON" ]; then
    echo "[ERROR] Venv introuvable. Lance d'abord :"
    echo "  python -m venv venv && venv/bin/pip install -r requirements.txt"
    exit 1
fi

"$PYTHON" "$DIR/main.py" "$@"
