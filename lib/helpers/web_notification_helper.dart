// Dispatcher de notificaciones de escritorio con soporte condicional de plataforma

import 'web_notification_stub.dart'
    if (dart.library.js_interop) 'web_notification_web.dart';

class WebNotificationHelper {
  static void showDesktopNotification({
    required String title,
    required String body,
    String? iconUrl,
    String? caseId,
  }) {
    platformShowDesktopNotification(
      title: title,
      body: body,
      iconUrl: iconUrl,
      caseId: caseId,
    );
  }
}
