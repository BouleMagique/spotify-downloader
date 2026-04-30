@echo off
setlocal
set "DIR=%~dp0"

echo [INFO] Installation de PyInstaller...
"%DIR%venv\Scripts\pip.exe" install pyinstaller --quiet ^
    --trusted-host pypi.org --trusted-host files.pythonhosted.org

echo [INFO] Build en cours (peut prendre 1-2 minutes)...
"%DIR%venv\Scripts\pyinstaller.exe" ^
    --onefile ^
    --windowed ^
    --name "SpotifyDownloader" ^
    --collect-all yt_dlp ^
    --collect-all spotipy ^
    --hidden-import mutagen ^
    --hidden-import mutagen.id3 ^
    --hidden-import truststore ^
    --hidden-import dotenv ^
    --hidden-import requests ^
    --hidden-import tkinter ^
    --hidden-import tkinter.ttk ^
    --hidden-import tkinter.scrolledtext ^
    "%DIR%gui.py"

echo.
echo [OK] Executable genere : dist\SpotifyDownloader.exe
echo.
echo Copie le .env dans le meme dossier que l'exe avant de lancer :
echo   copy .env dist\.env
echo ffmpeg doit etre installe et dans le PATH.
