#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo " ============================================"
echo "  Spotify Downloader - Installation"
echo " ============================================"
echo ""

# --- Python ---
if ! command -v python3 &>/dev/null; then
    echo " [ERREUR] Python n'est pas installe."
    echo ""
    echo " Installe Python via Homebrew :"
    echo "   brew install python"
    echo " Ou telecharge-le sur : https://www.python.org/downloads/"
    echo ""
    exit 1
fi

if ! python3 -c "import sys; exit(0 if sys.version_info >= (3,10) else 1)" &>/dev/null; then
    echo " [ERREUR] Python 3.10 ou superieur est requis."
    echo " Telecharge la derniere version sur : https://www.python.org/downloads/"
    echo ""
    exit 1
fi
echo " [OK] Python detecte"

# --- Environnement virtuel ---
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo " [..] Creation de l'environnement Python..."
    python3 -m venv "$SCRIPT_DIR/venv"
fi
echo " [OK] Environnement Python pret"

# --- Dependances ---
echo " [..] Installation des dependances (peut prendre quelques minutes)..."
"$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" --quiet \
    --trusted-host pypi.org --trusted-host files.pythonhosted.org
echo " [OK] Dependances installees"

# --- ffmpeg ---
if ! command -v ffmpeg &>/dev/null; then
    echo " [..] Installation de ffmpeg..."
    if command -v brew &>/dev/null; then
        brew install ffmpeg --quiet
        echo " [OK] ffmpeg installe"
    else
        echo " [AVERT] ffmpeg n'a pas pu etre installe automatiquement."
        echo "         Homebrew n'est pas disponible."
        echo "         Installe Homebrew (https://brew.sh) puis relance ce script,"
        echo "         ou installe ffmpeg manuellement et ajoute-le au PATH."
    fi
else
    echo " [OK] ffmpeg detecte"
fi

echo ""
echo " ============================================"
echo "  Installation terminee - Lancement..."
echo " ============================================"
echo ""

"$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/gui.py"
