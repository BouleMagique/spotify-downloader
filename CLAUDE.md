# spotify-downloader

CLI Python qui télécharge une playlist Spotify complète en MP3 320kbps avec métadonnées ID3 automatiques. Pour chaque piste, il cherche la meilleure correspondance sur YouTube Music (puis YouTube en fallback), convertit via ffmpeg, et organise les fichiers.

## Stack

- **Python 3.10+** — typer (CLI), rich (terminal UI), python-dotenv
- **spotipy** — Spotify Web API (OAuth2 PKCE)
- **yt-dlp** — recherche YouTube + téléchargement + conversion MP3
- **mutagen** — écriture des tags ID3v2.3
- **truststore** — injection des certificats système (Windows/macOS/Linux) dans le ssl module Python
- **requests** — téléchargement de la pochette album
- **ffmpeg** — binaire système requis pour la conversion audio

## Architecture

```
main.py            CLI Typer + orchestration + ThreadPoolExecutor (max 5 workers)
spotify_client.py  Fetch métadonnées playlist (pagination, ISRC, pochette, durée) + cache client
matcher.py         Scoring YouTube : durée ±15s, bonus "Artist - Topic", malus noise words
downloader.py      yt-dlp → MP3 320kbps, chemin artiste/album/titre ou flat playlist/titre
metadata.py        Mutagen ID3 : TIT2 TPE1 TALB TRCK TPOS TDRC TSRC APIC
utils.py           sanitize_filename(), load_state()/save_state() JSON
```

## Pipeline d'exécution

```
Spotify URL → extract_playlist_id() → get_playlist_info() + get_playlist_tracks()
  → pour chaque piste : find_youtube_url() [YouTube Music → YouTube fallback]
  → download_track() [yt-dlp + ffmpeg → MP3 320kbps]
  → embed_tags() [mutagen ID3]
  → save_state() [{playlist_id}.state.json]
```

## Configuration

Fichier `.env` requis (non versionné) :
```env
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
SPOTIFY_REDIRECT_URI=http://127.0.0.1:8888/callback
```

Credentials : https://developer.spotify.com/dashboard  
Cache OAuth Spotify : `.spotify_cache` (non versionné)

## Commandes

```bash
# Setup (une seule fois)
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt

# Lancement sans activer le venv (Windows)
run.bat download <SPOTIFY_URL>

# Lancement sans activer le venv (Linux/macOS)
bash run.sh download <SPOTIFY_URL>

# Avec python direct (venv activé)
python main.py download <SPOTIFY_URL>
python main.py download <SPOTIFY_URL> --output ./music --workers 4
python main.py download <SPOTIFY_URL> --dry-run          # aperçu sans télécharger
python main.py download <SPOTIFY_URL> --flat             # structure: playlist/titre.mp3
python main.py download <SPOTIFY_URL> --no-skip          # re-télécharger même les existants
```

## Options CLI

| Option | Défaut | Description |
|--------|--------|-------------|
| `--output` / `-o` | `downloads/` | Répertoire de sortie |
| `--workers` / `-w` | `3` | Téléchargements parallèles (max 5) |
| `--skip-existing/--no-skip` | skip | Sauter les fichiers déjà présents |
| `--dry-run` | off | Afficher la playlist sans télécharger |
| `--flat` | off | Structure plate : `playlist/titre.mp3` au lieu de `artiste/album/titre.mp3` |

## Structure de sortie

Sans `--flat` (défaut) :
```
downloads/
  Daft Punk/
    Random Access Memories/
      01 - Give Life Back to Music.mp3
```

Avec `--flat` :
```
downloads/
  Ma Playlist/
    Give Life Back to Music.mp3
```

## Points d'attention

- **SSL système** : `truststore.inject_into_ssl()` s'exécute au démarrage — injecte les certificats système (Windows Store, macOS Keychain, Linux system store) dans le module ssl Python. Couvre requests, yt-dlp et spotipy.
- **Client Spotify** : `_get_client()` dans `spotify_client.py` met le client en cache module-level — un seul OAuth pour toute l'exécution.
- **Reprise** : l'état est persisté dans `{playlist_id}.state.json` (gitignored). Relancer la même commande reprend où ça s'est arrêté.
- **Scoring matcher** (`matcher.py:_score()`) : la durée est le signal principal. Un écart > 15s disqualifie la piste. Les chaînes "Artist - Topic" reçoivent +5 pts. Les mots "live/cover/remix/acoustic" sont pénalisés sauf si présents dans le titre original. Score calculé une seule fois par candidat.
- **Pagination Spotify** : `get_playlist_tracks()` gère les playlists > 100 pistes via offset.
- **Encodage ID3** : UTF-8 (encoding=3) partout dans `metadata.py` pour supporter les caractères internationaux.
- **Sanitization** : les caractères `\/:*?"<>|` sont retirés des noms de fichiers via `utils.sanitize_filename()`.

## Branches git

```
master          code stable / production
dev             intégration — toutes les features finies convergent ici avant master
feature/*       une branche par feature, créée depuis dev
```

Voir `git-workflow.txt` pour le détail des commandes.

## Ce qui manque

- Aucune suite de tests (pas de `tests/`)
- Pas de CI/CD
- Pas de gestion des rate limits Spotify explicite (spotipy gère basiquement)
- La reprise d'état ne détecte pas les changements de playlist entre deux runs

## Fichiers non versionnés (gitignore)

```
.env              # credentials Spotify
downloads/        # MP3 téléchargés
venv/ / .venv/    # environnement virtuel
*.state.json      # état de reprise
.spotify_cache    # token OAuth Spotify
__pycache__/
```
