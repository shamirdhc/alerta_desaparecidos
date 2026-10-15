@echo off
chcp 65001 >nul
echo ========================================================
echo   SINCRONIZADOR OFICIAL PNP - ALERTA DESAPARECIDOS
echo   Delta-Sync (Plan Free Firebase - 0 Costo)
echo ========================================================
echo.

cd /d "%~dp0"

if not exist "serviceAccountKey.json" (
    echo [ERROR] No se encontro serviceAccountKey.json en la raiz del proyecto.
    echo Asegurate de colocar las credenciales de Firebase aqui.
    pause
    exit /b 1
)

python scripts\sync_desaparecidos_pnp.py

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo [EXITO] Base de datos de Firestore sincronizada al 100%%.
    echo ========================================================
) else (
    echo.
    echo [ERROR] Hubo un problema al ejecutar la sincronizacion.
)

pause
