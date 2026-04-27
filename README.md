# Spotify Downloader

Télécharge une playlist Spotify complète en MP3 320kbps.  
Recherche automatiquement les morceaux sur YouTube Music, les télécharge et les tague (titre, artiste, album, cover, année, numéro de piste).

---

## Prérequis

- Python 3.10+
- Git
- ffmpeg (installé automatiquement par le script si possible)
- Un compte [Spotify Developer](https://developer.spotify.com/dashboard) pour les credentials API

---

## Installation automatique (recommandée)

### Windows

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.ps1 | iex"
```

### Linux / macOS

```bash
curl -sSL https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.sh | bash
```

Le script fait tout :
1. Clone le repo (ou met à jour si déjà présent)
2. Crée un environnement virtuel Python
3. Installe les dépendances
4. Installe ffmpeg si absent
5. Crée le fichier `.env` et demande tes credentials Spotify

---

## Mise à jour

Pour récupérer la dernière version du code et mettre à jour les dépendances :

```bash
# Windows
run.bat update

# Linux / macOS
bash run.sh update
```

---

## Installation manuelle

```bash
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader
python -m venv venv

# Activer le venv (une seule fois par session si tu utilises python directement)
# Windows :
venv\Scripts\activate
# Linux/macOS :
source venv/bin/activate

pip install -r requirements.txt
```

### Installer ffmpeg

**Windows :** `winget install --id Gyan.FFmpeg` ou [télécharger manuellement](https://ffmpeg.org/download.html) et ajouter au PATH  
**Ubuntu/Debian :** `sudo apt install ffmpeg`  
**macOS :** `brew install ffmpeg`

---

## Configuration

Copie le fichier d'exemple et renseigne tes credentials :

```bash
cp .env.example .env
```

Édite `.env` :

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

## Utilisation

```bash
# Windows (pas besoin d'activer le venv)
run.bat download https://open.spotify.com/playlist/XXXXXXXXXXXXXXXX

# Linux / macOS
bash run.sh download https://open.spotify.com/playlist/XXXXXXXXXXXXXXXX

# Ou avec python directement (venv activé)
python main.py download <URL>
```

### Options disponibles

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
run.bat download <URL>

# Structure plate : NomPlaylist/titre.mp3 (pratique pour les playlists mixtes)
run.bat download <URL> --flat

# Télécharger dans un dossier spécifique avec 5 workers
run.bat download <URL> --output D:\Musique --workers 5

# Aperçu de la playlist sans télécharger
run.bat download <URL> --dry-run
```

### Structure de sortie

**Sans `--flat` (défaut) :**
```
downloads/
└── Daft Punk/
    └── Random Access Memories/
        ├── 01 - Give Life Back to Music.mp3
        └── 02 - The Game of Love.mp3
```

**Avec `--flat` :**
```
downloads/
└── Ma Playlist/
    ├── Give Life Back to Music.mp3
    └── The Game of Love.mp3
```

---

## Fonctionnement

1. Récupère les métadonnées de la playlist via l'API Spotify (titre, artistes, album, ISRC, cover, durée)
2. Pour chaque morceau, cherche la meilleure correspondance sur YouTube Music (fallback YouTube) via un score basé sur la durée, la chaîne officielle et les mots-clés parasites (live, cover, remix…)
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
| `requests` | Téléchargement des covers album |
| `truststore` | Certificats SSL système (proxy corporate) |
