// Implementación para navegadores web utilizando dart:js_interop

import 'dart:js_interop';

@JS('window.showWebNotification')
external void _showWebNotification(JSString title, JSString body, JSString? iconUrl, JSString? caseId);

void platformShowDesktopNotification({
  required String title,
  required String body,
  String? iconUrl,
  String? caseId,
}) {
  try {
    _showWebNotification(
      title.toJS,
      body.toJS,
      iconUrl?.toJS,
      caseId?.toJS,
    );
  } catch (e) {
    // Tolerancia a fallos si la API de notificaciones no está habilitada
  }
}
