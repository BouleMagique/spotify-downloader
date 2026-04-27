@echo off
setlocal
set "DIR=%~dp0"
set "PYTHON=%DIR%venv\Scripts\python.exe"

if not exist "%PYTHON%" (
    echo [ERROR] Venv introuvable. Lance d'abord :
    echo   python -m venv venv
    echo   venv\Scripts\pip install -r requirements.txt
    exit /b 1
)

"%PYTHON%" "%DIR%main.py" %*
