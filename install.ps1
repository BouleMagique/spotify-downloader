# Spotify Downloader — Installation/Update script (Windows)
# Usage (one-liner, fresh install):
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.ps1 | iex"
#
# Usage (local update):
#   .\install.ps1

$ErrorActionPreference = "Stop"
$REPO   = "https://github.com/BouleMagique/spotify-downloader.git"
$DIR    = "spotify-downloader"
$BRANCH = "master"

Write-Host "`n=== Spotify Downloader — Setup ===" -ForegroundColor Cyan

# --- Python ---
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Python n'est pas installe. Installe-le depuis https://python.org puis relance ce script." -ForegroundColor Red
    exit 1
}
$pyver = python -c "import sys; v=sys.version_info; exit(0) if v.major==3 and v.minor>=10 else exit(1)" 2>$null
if ($LASTEXITCODE -ne 0) {
    $pyver = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    Write-Host "[ERROR] Python 3.10+ requis (detecte : $pyver)." -ForegroundColor Red
    exit 1
}
$pyver = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
Write-Host "[OK] Python $pyver" -ForegroundColor Green

# --- Git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git n'est pas installe. Installe-le depuis https://git-scm.com puis relance ce script." -ForegroundColor Red
    exit 1
}

# --- Clone ou mise a jour ---
if (Test-Path "$DIR\.git") {
    Write-Host "[INFO] Mise a jour du repo (branche $BRANCH)..." -ForegroundColor Yellow
    Set-Location $DIR
    git fetch origin
    git checkout $BRANCH
    git pull origin $BRANCH
    Write-Host "[OK] Code mis a jour" -ForegroundColor Green
} elseif (Test-Path $DIR) {
    Write-Host "[WARN] Dossier '$DIR' present mais pas un repo git. Supprime-le et relance." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "[INFO] Clonage du repo (branche $BRANCH)..." -ForegroundColor Yellow
    git clone --branch $BRANCH $REPO $DIR
    Set-Location $DIR
}

# --- Venv ---
if (-not (Test-Path "venv")) {
    Write-Host "[INFO] Creation du venv..." -ForegroundColor Yellow
    python -m venv venv
}
Write-Host "[OK] Venv pret" -ForegroundColor Green

# --- Dependances pip ---
Write-Host "[INFO] Installation/mise a jour des dependances pip..." -ForegroundColor Yellow
& "venv\Scripts\pip.exe" install -r requirements.txt --quiet `
    --trusted-host pypi.org --trusted-host files.pythonhosted.org
Write-Host "[OK] Dependances installees" -ForegroundColor Green

# --- ffmpeg ---
$ffmpegOk = $false
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    $ffmpegOk = $true
} elseif (Test-Path "venv\Scripts\ffmpeg.exe") {
    $ffmpegOk = $true
}

if (-not $ffmpegOk) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "[INFO] Installation de ffmpeg via winget..." -ForegroundColor Yellow
        winget install --id Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements | Out-Null
        Write-Host "[OK] ffmpeg installe (redemarrez votre terminal pour l'activer dans le PATH)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] ffmpeg introuvable et winget non disponible." -ForegroundColor Yellow
        Write-Host "       Telecharge-le manuellement : https://ffmpeg.org/download.html" -ForegroundColor Yellow
        Write-Host "       Ajoute le dossier 'bin' au PATH systeme." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] ffmpeg present" -ForegroundColor Green
}

# --- .env (Spotify, optionnel) ---
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "`n[INFO] YouTube et Deezer ne necessitent pas de credentials." -ForegroundColor Cyan
    Write-Host "[INFO] Les credentials Spotify sont requis uniquement pour les playlists Spotify." -ForegroundColor Cyan
    $addSpotify = Read-Host "  Configurer les credentials Spotify maintenant ? (o/N)"
    if ($addSpotify -eq "o" -or $addSpotify -eq "O") {
        Write-Host "  -> Cree une app sur https://developer.spotify.com/dashboard" -ForegroundColor White
        Write-Host "  -> Dans 'Redirect URIs', ajoute : http://127.0.0.1:8888/callback" -ForegroundColor White
        $id     = Read-Host "  SPOTIFY_CLIENT_ID"
        $secret = Read-Host "  SPOTIFY_CLIENT_SECRET"
        (Get-Content ".env") -replace "your_client_id_here", $id `
                             -replace "your_client_secret_here", $secret | Set-Content ".env"
        Write-Host "[OK] .env configure" -ForegroundColor Green
    } else {
        Write-Host "[OK] Credentials Spotify ignores (configurable plus tard dans la GUI ou dans .env)" -ForegroundColor Green
    }
} else {
    Write-Host "[OK] .env existant, rien a faire" -ForegroundColor Green
}

Write-Host "`n=== Installation terminee ! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Lancer en mode GUI (Spotify / YouTube / Deezer) :" -ForegroundColor White
Write-Host "  cd $DIR" -ForegroundColor Yellow
Write-Host "  venv\Scripts\python gui.py" -ForegroundColor Yellow
Write-Host ""
Write-Host "Lancer en mode CLI (Spotify uniquement) :" -ForegroundColor White
Write-Host "  cd $DIR" -ForegroundColor Yellow
Write-Host "  run.bat <URL_PLAYLIST_SPOTIFY>" -ForegroundColor Yellow
Write-Host "  run.bat <URL_PLAYLIST_SPOTIFY> --flat    # structure plate playlist/titre.mp3" -ForegroundColor Yellow
Write-Host ""
Write-Host "Mettre a jour plus tard :" -ForegroundColor White
Write-Host "  run.bat update" -ForegroundColor Yellow
