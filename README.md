# Spotify Downloader

Télécharge des playlists **Spotify**, **YouTube** et **Deezer** en MP3 320kbps.  
Pour chaque morceau : recherche automatique sur YouTube Music, téléchargement via yt-dlp/ffmpeg, tags ID3 complets (titre, artiste, album, cover, année, numéro de piste, ISRC).

---

## Installation

### ⭐ Le plus simple — application packagée (un seul fichier)

Un livrable autonome par OS : **Python et toutes les dépendances sont déjà dedans** (interface graphique incluse). Rien à installer côté utilisateur — sauf `ffmpeg` (voir note plus bas).

| OS | Fichier | Lancer |
|----|---------|--------|
| **Linux** | `SpotifyDownloader-x86_64.AppImage` | `chmod +x SpotifyDownloader-x86_64.AppImage` puis double-clic ou `./SpotifyDownloader-x86_64.AppImage` |
| **macOS** (Apple Silicon) | `SpotifyDownloader.app` | double-clic (voir *Gatekeeper* ci-dessous) |
| **Windows** | `SpotifyDownloader.exe` | double-clic |

Ces fichiers se trouvent sur la page **[Releases](https://github.com/BouleMagique/spotify-downloader/releases)**, ou tu peux les **générer toi-même** (section *Générer le package* ci-dessous).

> **⚠️ ffmpeg requis.** Le convertisseur audio n'est pas embarqué. Installe-le une fois :
> - Linux : `sudo pacman -S ffmpeg` / `sudo apt install ffmpeg`
> - macOS : `brew install ffmpeg`
> - Windows : `winget install Gyan.FFmpeg`

> **🍎 macOS — Gatekeeper.** L'app n'est pas notarisée (pas de compte développeur Apple). Au 1er lancement : **clic-droit → Ouvrir**, ou en terminal `xattr -dr com.apple.quarantine SpotifyDownloader.app`.

> **🪟 Windows — SmartScreen.** L'exe n'est pas signé : *« More info » → « Run anyway »*.

---

### 🔨 Générer le package (build)

Chaque script crée le livrable de son OS dans `dist/`. **PyInstaller ne cross-compile pas** : il faut builder sur l'OS cible.

| OS | Commande | Sortie | Prérequis build |
|----|----------|--------|-----------------|
| **Linux** | `bash build-linux.sh` | `dist/SpotifyDownloader-x86_64.AppImage` | Python 3.10+, `tk` (`sudo pacman -S tk` / `apt install python3-tk`) |
| **macOS** | `bash build-macos.sh` | `dist/SpotifyDownloader.app` (+ `.zip`) | Python 3 avec Tk (Command Line Tools suffisent) |
| **Windows** | `build.bat` | `dist\SpotifyDownloader.exe` | Python 3.10+ |

Les scripts créent un venv isolé, installent les dépendances + PyInstaller, et empaquettent tout (les secrets `.env` / `.spotify_cache` sont **exclus** du bundle). `appimagetool` est téléchargé automatiquement au 1er build Linux.

---

### 🐍 Depuis les sources (mode développeur)

Sans packaging, en lançant directement le Python :

**Arch / CachyOS**
```bash
sudo pacman -S python python-pip git ffmpeg tk
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

**Ubuntu / Debian**
```bash
sudo apt install python3 python3-venv python3-pip git ffmpeg python3-tk
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

**macOS**
```bash
brew install python git ffmpeg python-tk
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

**Script d'install auto (Arch, Debian, Fedora, macOS)** — détecte le gestionnaire de paquets, installe ffmpeg + tkinter, configure le `.env` :
```bash
curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash
```

---

## Utilisation — GUI

- **Application packagée** : lance simplement le fichier (AppImage / .app / .exe).
- **Depuis les sources** : `venv/bin/python gui.py` (Linux/macOS) ou `launch-gui.bat` (Windows).

L'interface supporte **Spotify**, **YouTube** et **Deezer** :

- **Spotify** : renseigne Client ID + Client Secret dans le panneau "Configuration Spotify" (à créer sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard))
- **YouTube** et **Deezer** : aucun credential requis — colle l'URL et lance

---

## Utilisation — CLI (Spotify uniquement)

```bash
# Windows
run.bat <URL_PLAYLIST_SPOTIFY>

# Linux / macOS
bash run.sh <URL_PLAYLIST_SPOTIFY>

# Python direct (venv activé)
python main.py <URL>
python main.py <URL> --output ~/Music --workers 4
python main.py <URL> --dry-run   # liste les morceaux sans télécharger
python main.py <URL> --flat      # structure plate : playlist/titre.mp3
```

**Options :**

| Option | Défaut | Description |
|--------|--------|-------------|
| `--output` / `-o` | `downloads/` | Dossier de sortie |
| `--workers` / `-w` | `3` | Téléchargements en parallèle (max 5) |
| `--flat` | off | Structure plate : `playlist/titre.mp3` |
| `--dry-run` | off | Liste les morceaux sans télécharger |
| `--skip-existing/--no-skip` | skip | Sauter les fichiers déjà présents |

**Mise à jour :**
```bash
run.bat update      # Windows
bash run.sh update  # Linux / macOS
```

---

## Structure de sortie

**Mode artiste (défaut) :**
```
downloads/
└── Daft Punk/
    └── Random Access Memories/
        ├── 01 - Give Life Back to Music.mp3
        └── 02 - The Game of Love.mp3
```

**Mode flat :**
```
downloads/
└── Ma Playlist/
    ├── Give Life Back to Music.mp3
    └── The Game of Love.mp3
```

---

## Fonctionnement

1. Récupère les métadonnées de la playlist (Spotify API / Deezer API / yt-dlp selon la source)
2. Pour chaque morceau, cherche la meilleure correspondance sur YouTube Music (fallback YouTube) via un score basé sur la durée, la chaîne officielle et les mots-clés parasites (live, cover, remix…)  
   *Exception : les playlists YouTube utilisent directement l'URL de la vidéo, sans étape de recherche.*
3. Télécharge l'audio et le convertit en MP3 320kbps via ffmpeg
4. Embarque les tags ID3 (titre, artiste, album, année, numéro de piste, ISRC, cover)
5. Sauvegarde l'état dans un fichier `.state.json` — relancer reprend où ça s'est arrêté

---

## Dépendances

| Package | Rôle |
|---------|------|
| `spotipy` | API Spotify (OAuth2) |
| `yt-dlp` | Recherche et téléchargement YouTube |
| `mutagen` | Tags ID3 / métadonnées MP3 |
| `typer` | Interface CLI |
| `rich` | Affichage terminal |
| `python-dotenv` | Chargement du `.env` |
| `requests` | Téléchargement des covers + API Deezer |
| `truststore` | Certificats SSL système (optionnel, Python 3.10+) |

**Dépendances système :** `ffmpeg` (conversion audio), `tk` / `python3-tk` (GUI, uniquement pour builder ou lancer depuis les sources)
