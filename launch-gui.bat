@echo off
if not exist "%~dp0venv\Scripts\pythonw.exe" (
    echo [ERROR] Venv introuvable. Lance d'abord install.ps1
    pause
    exit /b 1
)
start "" "%~dp0venv\Scripts\pythonw.exe" "%~dp0gui.py"
