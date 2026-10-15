@echo off
chcp 65001 >nul
echo ============================================================================
echo   DESPLIEGUE AUTOMATICO - ALERTA DESAPARECIDOS PNP v4.0 PRO
echo ============================================================================
echo.
echo [1/5] Sincronizando casos recientes del portal PNP desde tu IP en Peru...
python tools/sync_incremental_pnp.py --origin=windows_deploy

echo.
echo [2/5] Obteniendo dependencias y compilando version Web optimizada (iPhone + Android + PC)...
call flutter pub get
call flutter build web --release

echo.
echo [3/5] Desplegando indices y reglas de seguridad en Firebase...
call firebase deploy --only firestore:indexes,firestore:rules,storage

echo.
echo [4/5] Publicando aplicacion Web en produccion (pnpalerta.web.app)...
call firebase deploy --only hosting

echo.
echo [5/5] Subiendo codigo actualizado y automatizador diario a GitHub...
git add .
git commit -m "feat(v4-pro): fix login iPhone Safari ITP, mejoras UX/UI y sync diario automatico"
git push

echo.
echo ============================================================================
echo   PROCESO COMPLETADO EXITOSAMENTE
echo ============================================================================
pause
