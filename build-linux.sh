#!/usr/bin/env bash
# =============================================================================
# Spotify Downloader — Build Linux (AppImage)
# =============================================================================
# Produit un VRAI livrable Linux : dist/SpotifyDownloader-x86_64.AppImage
# Un seul fichier, chmod +x -> ça tourne. Pas de Python, pas de venv chez
# l'utilisateur final (tout est bundlé, tkinter/tk inclus).
#
# Usage :
#   bash build-linux.sh
#
# Le build se fait dans un dossier LOCAL (hors CIFS/Samba, ou PyInstaller casse)
# et le .env / .spotify_cache (secrets) ne sont JAMAIS copiés dans le bundle.
# =============================================================================
set -euo pipefail

APP="SpotifyDownloader"
ENTRY="gui.py"                      # cible = GUI (comme build.bat sous Windows)
ARCH="x86_64"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/spotify-downloader-build"
TOOLS="$BUILD/tools"
APPDIR="$BUILD/AppDir"
OUT="$SRC/dist"

echo ""
echo "=== Spotify Downloader — Build Linux (AppImage) ==="
echo "Source : $SRC"
echo "Build  : $BUILD  (local, hors CIFS)"
echo ""

# --- Python -----------------------------------------------------------------
if ! command -v python3 &>/dev/null; then
    echo "[ERREUR] python3 introuvable." >&2; exit 1
fi
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
python3 -c "import sys; exit(0 if sys.version_info >= (3,10) else 1)" \
    || { echo "[ERREUR] Python 3.10+ requis (detecte : $PYVER)." >&2; exit 1; }
echo "[OK] Python $PYVER"

# --- tkinter (requis pour builder la GUI ; PyInstaller bundle ensuite tk) ----
if ! python3 -c "import tkinter" &>/dev/null; then
    echo "[ERREUR] tkinter indisponible sur cette machine de BUILD." >&2
    echo "         Installe le paquet tk puis relance :" >&2
    echo "           Arch/CachyOS : sudo pacman -S --needed tk" >&2
    echo "           Debian/Ubuntu: sudo apt install python3-tk" >&2
    echo "           Fedora       : sudo dnf install python3-tkinter" >&2
    exit 1
fi
echo "[OK] tkinter present"

# --- Copie source hors CIFS, SANS les secrets ni artefacts -------------------
echo "[..] Copie des sources (secrets exclus)..."
mkdir -p "$BUILD"
rsync -a --delete \
    --exclude venv --exclude .git --exclude __pycache__ \
    --exclude '.env' --exclude '.spotify_cache' \
    --exclude dist --exclude build --exclude '*.state.json' \
    --exclude AppDir --exclude tools \
    "$SRC"/ "$BUILD/src"/
cd "$BUILD/src"

# --- Venv + dependances + PyInstaller ---------------------------------------
if [ ! -d venv ]; then
    echo "[..] Creation du venv..."
    python3 -m venv venv
fi
echo "[..] Installation des dependances + PyInstaller..."
venv/bin/pip install --upgrade pip -q
# truststore exige Python >=3.10 ; il est optionnel (le code a un fallback certifi).
# On l'isole pour ne pas faire echouer tout requirements.txt sur un vieux Python.
grep -iv '^truststore' requirements.txt > .req-build.txt
venv/bin/pip install -r .req-build.txt -q
venv/bin/pip install truststore -q 2>/dev/null \
    && echo "[OK] truststore installe" \
    || echo "[INFO] truststore ignore (Python <3.10) -> SSL via certifi"
venv/bin/pip install pyinstaller -q
echo "[OK] Environnement de build pret"

# --- PyInstaller : bundle onedir --------------------------------------------
echo "[..] PyInstaller (peut prendre 1-2 min)..."
rm -rf dist build
venv/bin/pyinstaller --onedir --windowed --name "$APP" \
    --collect-all yt_dlp --collect-all spotipy \
    --hidden-import mutagen --hidden-import mutagen.id3 \
    --hidden-import truststore --hidden-import dotenv --hidden-import requests \
    --hidden-import tkinter --hidden-import tkinter.ttk --hidden-import tkinter.scrolledtext \
    "$ENTRY"
echo "[OK] Bundle genere : dist/$APP/"

# --- appimagetool (telecharge si absent) ------------------------------------
mkdir -p "$TOOLS"
if [ ! -x "$TOOLS/appimagetool" ]; then
    echo "[..] Telechargement d'appimagetool..."
    curl -sSL -o "$TOOLS/appimagetool" \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
    chmod +x "$TOOLS/appimagetool"
fi

# --- Assemblage de l'AppDir --------------------------------------------------
echo "[..] Assemblage de l'AppDir..."
rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin"
cp -r "dist/$APP" "$APPDIR/usr/bin/$APP"

# Icone 256x256 (disque vinyle vert Spotify) — generee, pur Python, sans dep
venv/bin/python - "$APPDIR/spotify-downloader.png" <<'PY'
import sys, zlib, struct, math
W=H=256
def px(x,y):
    cx=cy=127.5; d=math.hypot(x-cx,y-cy)
    if d>124: return (0,0,0,0)
    if d<20:  return (29,185,84,255)
    if d<26:  return (10,10,10,255)
    base=18 if (int(d)//10)%2 else 30
    return (base,base,base,255)
raw=bytearray()
for y in range(H):
    raw.append(0)
    for x in range(W): raw+=bytes(px(x,y))
def chunk(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"
png+=chunk(b"IHDR",struct.pack(">IIBBBBB",W,H,8,6,0,0,0))
png+=chunk(b"IDAT",zlib.compress(bytes(raw),9))
png+=chunk(b"IEND",b"")
open(sys.argv[1],"wb").write(png)
PY

cat > "$APPDIR/$APP.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Spotify Downloader
Comment=Telecharge des playlists Spotify/Deezer/YouTube en MP3
Exec=SpotifyDownloader
Icon=spotify-downloader
Categories=AudioVideo;Audio;
Terminal=false
EOF

cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/$APP/$APP" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

# --- Build de l'AppImage -----------------------------------------------------
echo "[..] Build de l'AppImage..."
mkdir -p "$OUT"
ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 \
    "$TOOLS/appimagetool" "$APPDIR" "$OUT/$APP-$ARCH.AppImage"

echo ""
echo "=== TERMINE ==="
echo "Livrable : $OUT/$APP-$ARCH.AppImage"
echo "Test     : chmod +x '$OUT/$APP-$ARCH.AppImage' && '$OUT/$APP-$ARCH.AppImage'"
echo ""
echo "Note : ffmpeg doit etre present sur la machine de l'utilisateur (PATH)."
