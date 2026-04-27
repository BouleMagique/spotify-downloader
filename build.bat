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
    --hidden-import spotipy ^
    --hidden-import spotipy.oauth2 ^
    --hidden-import yt_dlp ^
    --hidden-import mutagen ^
    --hidden-import mutagen.id3 ^
    --hidden-import truststore ^
    --hidden-import dotenv ^
    --hidden-import tkinter ^
    --hidden-import tkinter.ttk ^
    --hidden-import tkinter.scrolledtext ^
    "%DIR%gui.py"

echo.
echo [OK] Executable genere : dist\SpotifyDownloader.exe
echo.
echo IMPORTANT : avant de lancer l'exe, copier .env dans le meme dossier :
echo   copy .env dist\.env
echo   ffmpeg doit aussi etre installe et accessible dans le PATH.
