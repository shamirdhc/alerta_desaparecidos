@echo off
chcp 65001 >nul
echo ============================================================================
echo   SINCRONIZADOR OFICIAL PNP v5.0 - ALERTA DESAPARECIDOS
echo   Delta-Sync + Ubicacion Real + Comisarias + Storage (Plan Free 0 Costo)
echo ============================================================================
echo.

cd /d "%~dp0"

if not exist "serviceAccountKey.json" (
    echo [AVISO] No se encontro serviceAccountKey.json. Intentando con tools\sync_incremental_pnp.py...
    python tools\sync_incremental_pnp.py --origin=local_bat
    pause
    exit /b %ERRORLEVEL%
)

python scripts\sync_desaparecidos_pnp.py

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================================
    echo [EXITO] Base de datos y Panel SuperAdmin sincronizados al 100%%.
    echo ============================================================================
) else (
    echo.
    echo [ERROR] Hubo un problema al ejecutar la sincronizacion.
)

if "%1" NEQ "--silent" pause
