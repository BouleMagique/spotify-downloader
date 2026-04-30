#!/usr/bin/env bash
# Spotify Downloader — Installation/Update script (Linux/macOS)
# Usage (one-liner, fresh install):
#   curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash
#
# Usage (local update):
#   bash install.sh

set -e

REPO="https://github.com/BouleMagique/spotify-downloader.git"
DIR="spotify-downloader"
BRANCH="master"

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
PYOK=$(python3 -c "import sys; print(1 if sys.version_info >= (3,10) else 0)")
if [ "$PYOK" != "1" ]; then
    echo "[ERROR] Python 3.10+ requis (detecte : $PYVER)." >&2
    exit 1
fi
echo "[OK] Python $PYVER"

# --- Git ---
if ! command -v git &>/dev/null; then
    echo "[ERROR] Git n'est pas installe." >&2
    exit 1
fi

# --- Clone ou mise a jour ---
if [ -d "$DIR/.git" ]; then
    echo "[INFO] Mise a jour du repo (branche $BRANCH)..."
    cd "$DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    echo "[OK] Code mis a jour"
elif [ -d "$DIR" ]; then
    echo "[WARN] Dossier '$DIR' present mais pas un repo git. Supprime-le et relance." >&2
    exit 1
else
    echo "[INFO] Clonage du repo (branche $BRANCH)..."
    git clone --branch "$BRANCH" "$REPO" "$DIR"
    cd "$DIR"
fi

# --- Venv ---
if [ ! -d "venv" ]; then
    echo "[INFO] Creation du venv..."
    python3 -m venv venv
fi
echo "[OK] Venv pret"

# --- Dependances pip ---
echo "[INFO] Installation/mise a jour des dependances pip..."
venv/bin/pip install -r requirements.txt --quiet
echo "[OK] Dependances installees"

# --- Permissions run.sh ---
chmod +x run.sh 2>/dev/null || true

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

# --- .env (Spotify, optionnel) ---
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ""
    echo "[INFO] YouTube et Deezer ne necessitent pas de credentials."
    echo "[INFO] Les credentials Spotify sont requis uniquement pour les playlists Spotify."
    printf "  Configurer les credentials Spotify maintenant ? (o/N) : "
    read -r ADD_SPOTIFY
    if [ "$ADD_SPOTIFY" = "o" ] || [ "$ADD_SPOTIFY" = "O" ]; then
        echo "  -> Cree une app sur https://developer.spotify.com/dashboard"
        echo "  -> Dans 'Redirect URIs', ajoute : http://127.0.0.1:8888/callback"
        read -rp "  SPOTIFY_CLIENT_ID     : " CLIENT_ID
        read -rp "  SPOTIFY_CLIENT_SECRET : " CLIENT_SECRET
        python3 - <<PYEOF
import pathlib
p = pathlib.Path('.env')
t = p.read_text()
t = t.replace('your_client_id_here', '$CLIENT_ID')
t = t.replace('your_client_secret_here', '$CLIENT_SECRET')
p.write_text(t)
PYEOF
        echo "[OK] .env configure"
    else
        echo "[OK] Credentials Spotify ignores (configurable plus tard dans la GUI ou dans .env)"
    fi
else
    echo "[OK] .env existant, rien a faire"
fi

echo ""
echo "=== Installation terminee ! ==="
echo ""
echo "Lancer en mode GUI (Spotify / YouTube / Deezer) :"
echo "  cd $DIR"
echo "  venv/bin/python gui.py"
echo ""
echo "Lancer en mode CLI (Spotify uniquement) :"
echo "  cd $DIR"
echo "  bash run.sh <URL_PLAYLIST_SPOTIFY>"
echo "  bash run.sh <URL_PLAYLIST_SPOTIFY> --flat    # structure plate playlist/titre.mp3"
echo ""
echo "Mettre a jour :"
echo "  bash run.sh update"
