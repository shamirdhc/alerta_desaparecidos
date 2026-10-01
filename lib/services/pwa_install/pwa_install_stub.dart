// Stub para plataformas nativas (Android, iOS, Windows, macOS, Linux)

bool platformIsPWAInstalled() => true; // En plataformas nativas ya es una aplicación instalada

bool platformCanPromptPWAInstall() => false;

bool platformIsIOSDevice() => false;

Future<bool> platformTriggerPWAInstallPrompt() async => false;
