#!/usr/bin/env bash
# Spotify Downloader — Installation script (Linux/macOS)
# Usage (one-liner):
#   curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash

set -e

REPO="https://github.com/BouleMagique/spotify-downloader.git"
DIR="spotify-downloader"

echo ""
echo "=== Spotify Downloader — Setup ==="

# --- Python ---
if ! command -v python3 &>/dev/null; then
    echo "[ERROR] Python3 n'est pas installe." >&2
    echo "  Ubuntu/Debian : sudo apt install python3 python3-venv" >&2
    echo "  macOS         : brew install python" >&2
    exit 1
fi
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "[OK] Python $PYVER"

# --- Git ---
if ! command -v git &>/dev/null; then
    echo "[ERROR] Git n'est pas installe." >&2
    exit 1
fi

# --- Clone ou pull ---
if [ -d "$DIR" ]; then
    echo "[INFO] Dossier '$DIR' existant, mise a jour..."
    cd "$DIR" && git pull
else
    echo "[INFO] Clonage du repo..."
    git clone "$REPO" "$DIR"
    cd "$DIR"
fi

# --- Venv ---
if [ ! -d "venv" ]; then
    echo "[INFO] Creation du venv..."
    python3 -m venv venv
fi
echo "[OK] Venv pret"

# --- Dependances pip ---
echo "[INFO] Installation des dependances pip..."
venv/bin/pip install -r requirements.txt --quiet
echo "[OK] Dependances installees"

# --- ffmpeg ---
if command -v ffmpeg &>/dev/null; then
    echo "[OK] ffmpeg present"
else
    echo "[INFO] Installation de ffmpeg..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y ffmpeg -qq
    elif command -v brew &>/dev/null; then
        brew install ffmpeg
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ffmpeg
    else
        echo "[WARN] Impossible d'installer ffmpeg automatiquement."
        echo "       Installe-le manuellement : https://ffmpeg.org/download.html"
    fi
    command -v ffmpeg &>/dev/null && echo "[OK] ffmpeg installe"
fi

# --- .env ---
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ""
    echo "[CONFIG] Renseigne tes credentials Spotify dans le fichier .env"
    echo "  -> Cree une app sur https://developer.spotify.com/dashboard"
    read -rp "  SPOTIFY_CLIENT_ID     : " CLIENT_ID
    read -rp "  SPOTIFY_CLIENT_SECRET : " CLIENT_SECRET
    sed -i "s/your_client_id_here/$CLIENT_ID/" .env
    sed -i "s/your_client_secret_here/$CLIENT_SECRET/" .env
    echo "[OK] .env configure"
else
    echo "[OK] .env existant, rien a faire"
fi

echo ""
echo "=== Installation terminee ! ==="
echo "Lance l'outil avec :"
echo "  cd $DIR"
echo "  venv/bin/python main.py download <URL_PLAYLIST>"
