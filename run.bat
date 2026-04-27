@echo off
setlocal
set "DIR=%~dp0"
set "PYTHON=%DIR%venv\Scripts\python.exe"
set "PIP=%DIR%venv\Scripts\pip.exe"

if "%~1"=="update" (
    echo [INFO] Mise a jour du code...
    git -C "%DIR%" pull origin
    echo [INFO] Mise a jour des dependances...
    "%PIP%" install -r "%DIR%requirements.txt" --quiet ^
        --trusted-host pypi.org --trusted-host files.pythonhosted.org
    echo [OK] Mise a jour terminee.
    exit /b 0
)

if not exist "%PYTHON%" (
    echo [ERROR] Venv introuvable. Lance d'abord :
    echo   python -m venv venv
    echo   venv\Scripts\pip install -r requirements.txt
    exit /b 1
)

"%PYTHON%" "%DIR%main.py" %*
