# Spotify Downloader — Installation script (Windows)
# Usage (one-liner):
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/BouleMagique/spotify-downloader/master/install.ps1 | iex"

$ErrorActionPreference = "Stop"
$REPO = "https://github.com/BouleMagique/spotify-downloader.git"
$DIR  = "spotify-downloader"

Write-Host "`n=== Spotify Downloader — Setup ===" -ForegroundColor Cyan

# --- Python ---
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Python n'est pas installe. Installe-le depuis https://python.org puis relance ce script." -ForegroundColor Red
    exit 1
}
$pyver = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
Write-Host "[OK] Python $pyver" -ForegroundColor Green

# --- Git clone ou pull ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git n'est pas installe. Installe-le depuis https://git-scm.com puis relance ce script." -ForegroundColor Red
    exit 1
}

if (Test-Path $DIR) {
    Write-Host "[INFO] Dossier '$DIR' existant, mise a jour..." -ForegroundColor Yellow
    Set-Location $DIR
    git pull
} else {
    Write-Host "[INFO] Clonage du repo..." -ForegroundColor Yellow
    git clone $REPO $DIR
    Set-Location $DIR
}

# --- Venv ---
if (-not (Test-Path "venv")) {
    Write-Host "[INFO] Creation du venv..." -ForegroundColor Yellow
    python -m venv venv
}
Write-Host "[OK] Venv pret" -ForegroundColor Green

# --- Dependances pip ---
Write-Host "[INFO] Installation des dependances pip..." -ForegroundColor Yellow
& "venv\Scripts\pip.exe" install -r requirements.txt --quiet
Write-Host "[OK] Dependances installees" -ForegroundColor Green

# --- ffmpeg ---
$ffmpegOk = $false
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    $ffmpegOk = $true
} elseif (Test-Path "venv\Scripts\ffmpeg.exe") {
    $ffmpegOk = $true
}

if (-not $ffmpegOk) {
    Write-Host "[INFO] ffmpeg non trouve, installation via pip (ffmpeg-python + binaire)..." -ForegroundColor Yellow
    & "venv\Scripts\pip.exe" install ffmpeg-downloader --quiet
    & "venv\Scripts\ffmpeg-downloader" install --quiet 2>$null
    if (-not $?) {
        Write-Host "[WARN] Impossible d'installer ffmpeg automatiquement." -ForegroundColor Yellow
        Write-Host "       Telecharge-le manuellement : https://ffmpeg.org/download.html" -ForegroundColor Yellow
        Write-Host "       et ajoute-le au PATH." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] ffmpeg installe" -ForegroundColor Green
    }
} else {
    Write-Host "[OK] ffmpeg present" -ForegroundColor Green
}

# --- .env ---
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "`n[CONFIG] Renseigne tes credentials Spotify dans le fichier .env" -ForegroundColor Cyan
    Write-Host "  -> Cree une app sur https://developer.spotify.com/dashboard" -ForegroundColor White
    $id     = Read-Host "  SPOTIFY_CLIENT_ID"
    $secret = Read-Host "  SPOTIFY_CLIENT_SECRET"
    (Get-Content ".env") -replace "your_client_id_here", $id `
                         -replace "your_client_secret_here", $secret | Set-Content ".env"
    Write-Host "[OK] .env configure" -ForegroundColor Green
} else {
    Write-Host "[OK] .env existant, rien a faire" -ForegroundColor Green
}

Write-Host "`n=== Installation terminee ! ===" -ForegroundColor Cyan
Write-Host "Lance l'outil avec :" -ForegroundColor White
Write-Host "  cd $DIR" -ForegroundColor Yellow
Write-Host "  venv\Scripts\python main.py download <URL_PLAYLIST>" -ForegroundColor Yellow
