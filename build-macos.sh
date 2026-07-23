#!/usr/bin/env bash
# =============================================================================
# Spotify Downloader — Build macOS (.app)
# =============================================================================
# Produit un VRAI livrable macOS : dist/SpotifyDownloader.app (+ un .zip a partager)
# Bundle autonome : Python + deps + tkinter inclus. A lancer SUR un Mac.
#
# Usage (sur le Mac) :
#   bash build-macos.sh
#
# Prerequis : python3 (Command Line Tools suffisent, tkinter inclus).
# Pas besoin de Homebrew.
#
# NB : sur Apple Silicon le .app est arm64 (ne tournera pas sur Mac Intel).
#      Le .app n'est PAS notarise -> au 1er lancement chez un tiers, Gatekeeper
#      demandera clic-droit > Ouvrir (ou : xattr -dr com.apple.quarantine App).
# =============================================================================
set -euo pipefail

APP="SpotifyDownloader"
ENTRY="gui.py"
BUNDLE_ID="com.boulemagique.spotifydownloader"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${HOME}/.cache/spotify-downloader-build"
OUT="$SRC/dist"

echo ""
echo "=== Spotify Downloader — Build macOS (.app) ==="
echo "Source : $SRC"
echo "Build  : $BUILD"
echo ""

# --- Python + tkinter -------------------------------------------------------
command -v python3 >/dev/null || { echo "[ERREUR] python3 introuvable." >&2; exit 1; }
PYVER=$(python3 -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "[OK] Python $PYVER"
python3 -c 'import tkinter' 2>/dev/null \
    || { echo "[ERREUR] tkinter indisponible (installe un Python avec Tk)." >&2; exit 1; }
echo "[OK] tkinter present"

# --- Copie source SANS secrets ----------------------------------------------
echo "[..] Copie des sources (secrets exclus)..."
mkdir -p "$BUILD/src"
rsync -a --delete \
    --exclude venv --exclude .git --exclude __pycache__ \
    --exclude '.env' --exclude '.spotify_cache' \
    --exclude dist --exclude build --exclude '*.state.json' \
    "$SRC"/ "$BUILD/src"/
cd "$BUILD/src"

# --- Venv + deps + PyInstaller ----------------------------------------------
[ -d venv ] || python3 -m venv venv
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

# --- Icone .icns (via sips/iconutil natifs — optionnel) ---------------------
ICON_ARG=()
if command -v sips >/dev/null && command -v iconutil >/dev/null; then
    echo "[..] Generation de l'icone .icns..."
    venv/bin/python - icon_1024.png <<'PY'
import sys, zlib, struct, math
W=H=1024
def px(x,y):
    c=511.5; d=math.hypot(x-c,y-c)
    if d>500: return (0,0,0,0)
    if d<80:  return (29,185,84,255)
    if d<104: return (10,10,10,255)
    base=18 if (int(d)//40)%2 else 30
    return (base,base,base,255)
raw=bytearray()
for y in range(H):
    raw.append(0)
    for x in range(W): raw+=bytes(px(x,y))
def ch(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"+ch(b"IHDR",struct.pack(">IIBBBBB",W,H,8,6,0,0,0))+ch(b"IDAT",zlib.compress(bytes(raw),9))+ch(b"IEND",b"")
open(sys.argv[1],"wb").write(png)
PY
    rm -rf icon.iconset; mkdir icon.iconset
    for s in 16 32 64 128 256 512; do
        sips -z $s $s icon_1024.png --out "icon.iconset/icon_${s}x${s}.png" >/dev/null
        d=$((s*2)); sips -z $d $d icon_1024.png --out "icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    cp icon_1024.png icon.iconset/icon_512x512@2x.png
    iconutil -c icns icon.iconset -o icon.icns && ICON_ARG=(--icon icon.icns)
    echo "[OK] icone prete"
fi

# --- PyInstaller : --windowed => .app ---------------------------------------
echo "[..] PyInstaller (peut prendre 1-2 min)..."
rm -rf dist build
venv/bin/pyinstaller --windowed --name "$APP" \
    --osx-bundle-identifier "$BUNDLE_ID" \
    "${ICON_ARG[@]}" \
    --collect-all yt_dlp --collect-all spotipy \
    --hidden-import mutagen --hidden-import mutagen.id3 \
    --hidden-import truststore --hidden-import dotenv --hidden-import requests \
    --hidden-import tkinter --hidden-import tkinter.ttk --hidden-import tkinter.scrolledtext \
    "$ENTRY"

[ -d "dist/$APP.app" ] || { echo "[ERREUR] .app non genere." >&2; exit 1; }

# --- Livraison : copie le .app + zip a partager -----------------------------
ARCH=$(uname -m)
mkdir -p "$OUT"
rm -rf "$OUT/$APP.app"
cp -R "dist/$APP.app" "$OUT/$APP.app"
( cd "$OUT" && ditto -c -k --keepParent "$APP.app" "$APP-macos-$ARCH.zip" )

echo ""
echo "=== TERMINE ==="
echo "App : $OUT/$APP.app"
echo "Zip : $OUT/$APP-macos-$ARCH.zip  (a partager)"
echo "Test : open '$OUT/$APP.app'"
echo ""
echo "Note : ffmpeg doit etre dans le PATH de l'utilisateur (yt-dlp en a besoin)."
