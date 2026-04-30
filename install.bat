@echo off
chcp 65001 >nul
title Spotify Downloader - Installation

echo.
echo  ============================================
echo   Spotify Downloader - Installation
echo  ============================================
echo.

REM --- Python ---
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERREUR] Python n'est pas installe.
    echo.
    echo  Telecharge Python sur : https://www.python.org/downloads/
    echo  Important : coche "Add Python to PATH" lors de l'installation.
    echo.
    pause
    exit /b 1
)
python -c "import sys; exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERREUR] Python 3.10 ou superieur est requis.
    echo  Telecharge la derniere version sur : https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)
echo  [OK] Python detecte

REM --- Environnement virtuel ---
if not exist "%~dp0venv\" (
    echo  [..] Creation de l'environnement Python...
    python -m venv "%~dp0venv"
    if %errorlevel% neq 0 (
        echo  [ERREUR] Impossible de creer l'environnement Python.
        pause
        exit /b 1
    )
)
echo  [OK] Environnement Python pret

REM --- Dependances ---
echo  [..] Installation des dependances (peut prendre quelques minutes)...
"%~dp0venv\Scripts\pip.exe" install -r "%~dp0requirements.txt" --quiet ^
    --trusted-host pypi.org --trusted-host files.pythonhosted.org
if %errorlevel% neq 0 (
    echo  [ERREUR] Echec de l'installation des dependances.
    pause
    exit /b 1
)
echo  [OK] Dependances installees

REM --- ffmpeg ---
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [..] Installation de ffmpeg...
    winget install --id Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
    if %errorlevel% neq 0 (
        echo  [AVERT] ffmpeg n'a pas pu etre installe automatiquement.
        echo          Telecharge-le sur https://ffmpeg.org/download.html
        echo          et ajoute-le au PATH Windows, puis relance ce script.
    ) else (
        echo  [OK] ffmpeg installe
    )
) else (
    echo  [OK] ffmpeg detecte
)

echo.
echo  ============================================
echo   Installation terminee - Lancement...
echo  ============================================
echo.

start "" "%~dp0venv\Scripts\pythonw.exe" "%~dp0gui.py"
