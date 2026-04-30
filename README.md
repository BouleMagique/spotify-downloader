# Spotify Downloader

Télécharge des playlists **Spotify**, **YouTube** et **Deezer** en MP3 320kbps.  
Recherche automatiquement les morceaux sur YouTube Music, les télécharge et les tague (titre, artiste, album, cover, année, numéro de piste).

---

## Installation (Windows)

> Nécessite [Python 3.10+](https://www.python.org/downloads/) — coche **"Add Python to PATH"** lors de l'installation.

1. Télécharge le ZIP : bouton **Code → Download ZIP** sur [github.com/BouleMagique/spotify-downloader](https://github.com/BouleMagique/spotify-downloader)
2. Extrais l'archive
3. Double-clique sur **`install.bat`**

Le script installe les dépendances, ffmpeg, et ouvre l'interface automatiquement.

---

## Utilisation — GUI

Lance **`launch-gui.bat`** pour ouvrir l'interface.

Supporte les playlists **Spotify**, **YouTube** et **Deezer**.  
Pour Spotify : renseigne ton Client ID et Client Secret dans le panneau "Configuration Spotify" (credentials à créer sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)).  
Pour YouTube et Deezer : aucun credential requis.

---

## Mise à jour

Re-télécharge le ZIP et relance `install.bat`.

---

## Installation avancée (CLI / développeurs)

### Via une commande (nécessite Git)

**Windows :**
```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.ps1 | iex"
```

**Linux / macOS :**
```bash
curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash
```

### Manuelle

```bash
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python -m venv venv
venv\Scripts\activate      # Windows
source venv/bin/activate   # Linux / macOS
pip install -r requirements.txt
```

**Installer ffmpeg :**  
Windows : `winget install --id Gyan.FFmpeg`  
Ubuntu/Debian : `sudo apt install ffmpeg`  
macOS : `brew install ffmpeg`

### Lancer le CLI (Spotify uniquement)

```bash
# Windows
run.bat <URL_PLAYLIST_SPOTIFY>

# Linux / macOS
bash run.sh <URL_PLAYLIST_SPOTIFY>

# Python direct (venv activé)
python main.py <URL>
```

**Options :**

| Option | Défaut | Description |
|--------|--------|-------------|
| `--output` / `-o` | `downloads/` | Dossier de sortie |
| `--workers` / `-w` | `3` | Téléchargements en parallèle (max 5) |
| `--flat` | off | Structure plate : `playlist/titre.mp3` |
| `--dry-run` | off | Liste les morceaux sans télécharger |
| `--skip-existing/--no-skip` | skip | Sauter les fichiers déjà présents |

### Mise à jour CLI

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
|---|---|
| `spotipy` | API Spotify (OAuth2) |
| `yt-dlp` | Recherche et téléchargement YouTube |
| `mutagen` | Tags ID3 / métadonnées MP3 |
| `typer` | Interface CLI |
| `rich` | Affichage terminal |
| `python-dotenv` | Chargement du `.env` |
| `requests` | Téléchargement des covers + API Deezer |
| `truststore` | Certificats SSL système (proxy corporate) |
