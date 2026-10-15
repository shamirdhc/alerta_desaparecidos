@echo off
chcp 65001 >nul
echo ============================================================================
echo   INSTALADOR DE SINCRONIZACION AUTOMATICA DIARIA (WINDOWS TASK SCHEDULER)
echo   Ejecuta la sincronizacion PNP automaticamente en segundo plano (08:00, 14:00 y 20:00)
echo   desde tu IP de Peru sin bloqueos del firewall del MININTER/PNP.
echo ============================================================================
echo.

cd /d "%~dp0"
set "SCRIPT_PATH=%~dp0sincronizar_pnp_ahora.bat"

schtasks /create /tn "AlertaDesaparecidos_PNP_AutoSync_Manana" /tr "\"%SCRIPT_PATH%\" --silent" /sc daily /st 08:00 /f
schtasks /create /tn "AlertaDesaparecidos_PNP_AutoSync_Tarde" /tr "\"%SCRIPT_PATH%\" --silent" /sc daily /st 14:00 /f
schtasks /create /tn "AlertaDesaparecidos_PNP_AutoSync_Noche" /tr "\"%SCRIPT_PATH%\" --silent" /sc daily /st 20:00 /f

echo.
echo [EXITO] Se programaron las 3 sincronizaciones automaticas diarias (08:00, 14:00 y 20:00).
echo Tu PC actualizara Firestore automaticamente en segundo plano sin que tengas que abrir nada.
pause
