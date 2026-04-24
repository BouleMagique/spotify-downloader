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
1. Clone le repo
2. Crée un environnement virtuel Python
3. Installe les dépendances
4. Installe ffmpeg si absent
5. Crée le fichier `.env` et demande tes credentials Spotify

---

## Installation manuelle

```bash
git clone https://github.com/BouleMagique/spotify-downloader.git
cd spotify-downloader

# Créer le venv
python -m venv venv

# Activer le venv
# Windows :
venv\Scripts\activate
# Linux/macOS :
source venv/bin/activate

# Installer les dépendances
pip install -r requirements.txt
```

### Installer ffmpeg

**Windows :** [Télécharger ffmpeg](https://ffmpeg.org/download.html) et l'ajouter au PATH  
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
```

### Obtenir les credentials Spotify

1. Rends-toi sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Clique **Create App**
3. Renseigne un nom et une description (peu importe)
4. Dans **Redirect URIs**, ajoute `http://localhost` (requis par Spotify)
5. Copie le **Client ID** et le **Client Secret** dans ton `.env`

---

## Utilisation

```bash
# Activer le venv si pas encore fait
# Windows :
venv\Scripts\activate
# Linux/macOS :
source venv/bin/activate

# Télécharger une playlist
python main.py download https://open.spotify.com/playlist/XXXXXXXXXXXXXXXX

# Options disponibles
python main.py download <URL> --output ./ma_musique   # dossier de sortie
python main.py download <URL> --workers 5             # téléchargements parallèles (max 5)
python main.py download <URL> --dry-run               # liste les morceaux sans télécharger
python main.py download <URL> --no-skip               # re-télécharge même les fichiers existants
```

Les fichiers sont organisés automatiquement :

```
downloads/
└── Artiste/
    └── Album/
        ├── 01 - Titre.mp3
        ├── 02 - Titre.mp3
        └── ...
```

---

## Fonctionnement

1. Récupère les métadonnées de la playlist via l'API Spotify
2. Pour chaque morceau, cherche la meilleure correspondance sur YouTube Music (fallback YouTube)
3. Télécharge l'audio et le convertit en MP3 320kbps via ffmpeg
4. Embarque les tags ID3 (titre, artiste, album, année, numéro de piste, cover)
5. Sauvegarde l'état pour reprendre en cas d'interruption

---

## Dépendances

| Package | Rôle |
|---|---|
| `spotipy` | API Spotify |
| `yt-dlp` | Recherche et téléchargement YouTube |
| `mutagen` | Tags ID3 / métadonnées MP3 |
| `typer` | Interface CLI |
| `rich` | Affichage terminal |
| `python-dotenv` | Chargement du `.env` |
| `requests` | Téléchargement des covers |
