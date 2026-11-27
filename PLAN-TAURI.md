# Plan — réécriture Rust + Tauri 2

Branche : `feat/tauri-rewrite` (depuis `dev`). L'app Python reste sur `dev`/`master`
jusqu'à ce que la version Tauri fasse tout ce qu'elle fait.

## Objectifs

- Une app **plus belle** que la GUI Tkinter actuelle.
- **Plus aucun environnement Python** à gérer (venv, PyInstaller, bugs de bundling).
- **Mêmes fonctions** que l'app actuelle, puis **Apple Music** en option.
- Builds **Linux / Windows / macOS (arm64 + x86_64)** par une seule CI.

Hors objectifs : nouvelles fonctions au-delà d'Apple Music. L'app est quasi finie,
on vise la stabilité.

## Fonctions à reprendre (référence : l'app Python, ~940 lignes)

| Fonction | Fichier Python | Équivalent Rust |
|---|---|---|
| Playlist Spotify (pagination, ISRC, pochette, durée) | `spotify_client.py` | crate `rspotify` |
| Playlist Deezer (API publique) | `deezer_client.py` | `reqwest` + `serde` |
| Playlist YouTube | `gui.py` (`extract_flat`) | `yt-dlp --flat-playlist -J` |
| Recherche YouTube Music → YouTube, score (durée ±15 s, bonus « - Topic », malus « live/remix… ») | `matcher.py` | `yt-dlp "ytsearchN:…" -J` + score porté en Rust |
| Téléchargement MP3 320 kbps | `downloader.py` | yt-dlp en sidecar + ffmpeg |
| Tags ID3 (titre, artiste, album, n° piste/disque, date, ISRC, pochette) | `metadata.py` | crate `lofty` |
| Rangement Artiste/Album ou « flat » playlist/titre | `downloader.py` | idem |
| Reprise (ignorer les pistes déjà faites) | `utils.py` (`.state.json`) | même format JSON |
| Téléchargements parallèles (max 5), annulation | `gui.py` | `tokio` + `Semaphore` + jeton d'annulation |
| Identifiants Spotify enregistrés | `.env` dans `~/.config/spotify-downloader` | fichier de config dans le dossier config de l'OS |

## Architecture

```
src-tauri/                 Rust
  src/
    main.rs                démarrage Tauri, enregistrement des commandes
    config.rs              réglages + identifiants (dossier config de l'OS)
    sources/
      mod.rs               trait Source -> (nom playlist, Vec<Track>)
      spotify.rs
      deezer.rs
      youtube.rs
      apple_music.rs       (phase 5)
    matcher.rs             recherche + score YouTube
    download.rs            appel yt-dlp/ffmpeg, file de tâches, annulation
    tags.rs                tags via lofty
    state.rs               reprise (.state.json)
    tools.rs               trouver/mettre à jour yt-dlp et ffmpeg
  binaries/                sidecars yt-dlp + ffmpeg par plateforme
src/                       interface (Svelte + Vite)
```

- **Rust → interface** : événements Tauri (`track-progress`, `track-done`, `log`)
  pour la progression en direct.
- **Interface → Rust** : commandes (`load_playlist`, `start_download`, `cancel`,
  `save_settings`).
- **Règle d'or** : tout ce qui s'écrit (config, cache OAuth, état) va dans le
  dossier config/données de l'OS, jamais à côté de l'exécutable.

## Phases

1. **Squelette.** `create-tauri-app` (Svelte + TS). Fenêtre vide qui se lance sur
   les 4 cibles. CI `tauri-action` qui produit AppImage, .exe/.msi et .dmg.
   *Fini quand* : la CI publie un brouillon de release avec les 4 builds.
2. **Outils externes.** yt-dlp et ffmpeg livrés en sidecar ; au lancement,
   `yt-dlp -U` (mise à jour en tâche de fond). Téléchargement d'une URL YouTube
   en dur → MP3.
   *Fini quand* : un MP3 sort sur les 4 OS sans rien installer.
3. **Cœur.** Sources Deezer + YouTube (sans identifiants), matcher, tags,
   rangement, reprise, parallélisme, annulation.
   *Fini quand* : une playlist Deezer se télécharge entièrement avec les bons tags,
   et une relance ignore les pistes déjà faites.
4. **Spotify + interface finale.** OAuth Spotify, écran réglages, vraie UI : liste
   des pistes avec pochette et état par piste, barre globale, thème sombre.
   *Fini quand* : même usage que l'app Python, en plus joli.
5. **Apple Music (optionnel).** Playlists publiques en lisant la page
   `music.apple.com`.
6. **Bascule.** Merge dans `dev` puis `master`, release v1.0.0, l'app Python
   est archivée (tag `python-final`).

## Risques et points à trancher

- **yt-dlp casse quand YouTube change.** D'où la mise à jour auto au lancement
  plutôt qu'une version figée dans le build.
- **AppImage + WebKitGTK** : parfois capricieux selon les distribs. À tester tôt,
  dès la phase 1.
- **ffmpeg dans le bundle** : ~80 Mo par plateforme. Alternative : utiliser
  celui du système s'il existe, sinon le télécharger au premier lancement.
- **Spotify** : chaque utilisateur doit créer sa propre app sur le dashboard
  Spotify (comme aujourd'hui). À vérifier : les règles actuelles de Spotify
  pour les apps en « development mode ».
- **macOS non signé** : même contournement qu'aujourd'hui (clic droit > Ouvrir).
  Signature possible plus tard avec un compte développeur Apple.
- **Apple Music** : extraction de page = fragile, à garder optionnelle.

## Décisions prises

- Framework : **Tauri 2** (2026-11-27).
- Interface : **SvelteKit (Svelte 5) + TypeScript**, polices embarquées (Inter, Space Grotesk).
- Le code Tauri vit dans **`app/`** (l'app Python reste à la racine jusqu'à la bascule).
- Nom provisoire : **Playlist DL**, identifiant `com.boulemagique.playlistdl`.
- **Outils téléchargés au premier lancement** (rien dans le bundle), dans
  `<données de l'app>/bin` : yt-dlp (mis à jour par `-U` à chaque lancement),
  ffmpeg + ffprobe (sauf s'ils sont dans le PATH), **deno** (moteur JS exigé par
  yt-dlp pour YouTube depuis fin 2026 ; sinon avertissement et formats
  manquants). Sources : releases GitHub yt-dlp et deno ; ffmpeg =
  yt-dlp/FFmpeg-Builds (Linux), gyan.dev essentials (Windows),
  ffmpeg.martin-riedl.de (macOS). Environ 500 Mo sur disque au total si rien
  n'est installé (ffmpeg statique ≈ 180 Mo par binaire).
- Maquettes de référence : https://claude.ai/artifact/72sAwhQ7eyE5Vy2zzEAfcg
- CI : `.github/workflows/build-tauri.yml`, tags **`app-v*`** (les tags `v*`
  restent ceux de l'app Python), release en brouillon.

## Développer

```bash
cd app
npm install
npm run tauri dev                          # fenêtre avec rechargement à chaud
npm run tauri build -- --bundles appimage  # AppImage locale
```

Travailler hors du partage Samba (`/mnt/dev`) : cargo et node_modules y sont
très lents. Worktree local utilisé : `~/dev/playlist-dl`.

## Questions ouvertes

- Garder la CLI (`main.py`) ? Une CLI Rust serait facile à ajouter sur le même
  cœur si besoin.
