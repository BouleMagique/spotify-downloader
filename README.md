# Spotify Downloader

Télécharge des playlists **Spotify**, **YouTube** et **Deezer** en MP3 320kbps.  
Recherche automatiquement les morceaux sur YouTube Music, les télécharge et les tague (titre, artiste, album, cover, année, numéro de piste).

Deux modes :
- **GUI** — interface graphique tkinter (Spotify / YouTube / Deezer)
- **CLI** — terminal (Spotify uniquement)

---

## Prérequis

- Python 3.10+
- ffmpeg (installé automatiquement par le script si possible)
- Un compte [Spotify Developer](https://developer.spotify.com/dashboard) **uniquement pour les playlists Spotify**

---

## Installation

### Option 1 — Via une commande (recommandée)

Nécessite Git installé sur la machine.

**Windows :**
```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.ps1 | iex"
```

**Linux / macOS :**
```bash
curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash
```

---

### Option 2 — Téléchargement depuis GitHub

1. Va sur [github.com/BouleMagique/spotify-downloader](https://github.com/BouleMagique/spotify-downloader)
2. Clique **Code** → **Download ZIP**
3. Extrais l'archive
4. Ouvre un terminal dans le dossier extrait
5. Lance le script d'installation :

**Windows :**
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Linux / macOS :**
```bash
bash install.sh
```

---

### Option 3 — Installation manuelle (clone + pip)

```bash
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python -m venv venv

# Windows
venv\Scripts\activate
# Linux / macOS
source venv/bin/activate

pip install -r requirements.txt
```

**Installer ffmpeg :**

**Windows :** `winget install --id Gyan.FFmpeg` ou [télécharger manuellement](https://ffmpeg.org/download.html) et ajouter au PATH  
**Ubuntu/Debian :** `sudo apt install ffmpeg`  
**macOS :** `brew install ffmpeg`

---

Le script d'installation fait tout :
1. Crée un environnement virtuel Python
2. Installe les dépendances
3. Installe ffmpeg si absent
4. Propose de configurer les credentials Spotify (optionnel — pas nécessaire pour YouTube/Deezer)

---

## Lancer la GUI

Supporte les playlists **Spotify**, **YouTube** et **Deezer**. Aucun credential requis pour YouTube et Deezer.

**Windows :**
```powershell
venv\Scripts\python gui.py
```

**Linux / macOS :**
```bash
venv/bin/python gui.py
```

Pour les playlists Spotify : renseigne et enregistre tes credentials directement dans le panneau "Configuration Spotify" de l'interface.

---

## Mise à jour

```bash
# Windows
run.bat update

# Linux / macOS
bash run.sh update
```

---

## Lancer en mode CLI (Spotify uniquement)

```bash
# Windows (sans activer le venv)
run.bat <URL_PLAYLIST_SPOTIFY>

# Linux / macOS
bash run.sh <URL_PLAYLIST_SPOTIFY>

# Ou avec Python directement (venv activé)
python main.py <URL>
```

### Options

| Option | Défaut | Description |
|--------|--------|-------------|
| `--output` / `-o` | `downloads/` | Dossier de sortie |
| `--workers` / `-w` | `3` | Téléchargements en parallèle (max 5) |
| `--flat` | off | Structure plate : `playlist/titre.mp3` |
| `--dry-run` | off | Liste les morceaux sans télécharger |
| `--skip-existing/--no-skip` | skip | Sauter les fichiers déjà présents |

### Exemples

```bash
# Structure par défaut : artiste/album/titre.mp3
run.bat <URL>

# Structure plate : NomPlaylist/titre.mp3
run.bat <URL> --flat

# Dossier spécifique, 5 workers
run.bat <URL> --output D:\Musique --workers 5

# Aperçu sans télécharger
run.bat <URL> --dry-run
```

---

## Configuration Spotify

Nécessaire uniquement pour les playlists Spotify. Crée un fichier `.env` à la racine du projet :

```env
SPOTIFY_CLIENT_ID=<ton_client_id>
SPOTIFY_CLIENT_SECRET=<ton_client_secret>
SPOTIFY_REDIRECT_URI=http://127.0.0.1:8888/callback
```

### Obtenir les credentials Spotify

1. Rends-toi sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Clique **Create App**
3. Renseigne un nom et une description (peu importe)
4. Dans **Redirect URIs**, ajoute exactement `http://127.0.0.1:8888/callback`
5. Copie le **Client ID** et le **Client Secret** dans ton `.env`

> Lors du premier lancement, une fenêtre de navigateur s'ouvre pour autoriser l'accès à ton compte Spotify. Le token est ensuite mis en cache localement (`.spotify_cache`).

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
5. Sauvegarde l'état dans un fichier `.state.json` pour reprendre automatiquement en cas d'interruption
6. Les certificats SSL système sont injectés au démarrage — fonctionne en environnement corporate/proxy

---

## Dépendances

| Package | Rôle |
|---|---|
| `spotipy` | API Spotify (OAuth2) |
| `yt-dlp` | Recherche et téléchargement YouTube |
| `mutagen` | Tags ID3 / métadonnées MP3 |
| `typer` | Interface CLI |
| `rich` | Affichage terminal (progress bar, tableaux) |
| `python-dotenv` | Chargement du `.env` |
| `requests` | Téléchargement des covers + API Deezer |
| `truststore` | Certificats SSL système (proxy corporate) |
