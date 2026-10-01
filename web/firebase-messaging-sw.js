// Service Worker para Firebase Cloud Messaging en Segundo Plano
// Alerta Desaparecidos - Policía Nacional del Perú

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// Configuración oficial de Firebase Web
const firebaseConfig = {
  apiKey: "AIzaSyD0hbcfgvjzAKyNw0k81_-3y1wGbX3rogM",
  appId: "1:75698715605:web:a77a01a49471b69d151b5c",
  messagingSenderId: "75698715605",
  projectId: "alerta-desaparecidos-pnp",
  authDomain: "alerta-desaparecidos-pnp.firebaseapp.com",
  storageBucket: "alerta-desaparecidos-pnp.firebasestorage.app"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// Manejador de notificaciones push en segundo plano (pestaña minimizada o cerrada)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Notificación push recibida en segundo plano:', payload);

  const title = payload.notification?.title || payload.data?.title || '🚨 ALERTA PNP - DESAPARECIDOS';
  const body = payload.notification?.body || payload.data?.body || 'Nueva alerta o información registrada en el sistema.';
  const photoUrl = payload.notification?.imageUrl || payload.data?.photoUrl || payload.data?.imageUrl || '/icons/Icon-192.png';
  const missingPersonId = payload.data?.missingPersonId || payload.data?.desaparecidoId || '';

  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    image: photoUrl !== '/icons/Icon-192.png' ? photoUrl : undefined,
    vibrate: [200, 100, 200, 100, 200],
    tag: missingPersonId ? `case_${missingPersonId}` : 'pnp_alert',
    renotify: true,
    requireInteraction: true,
    data: {
      url: '/',
      missingPersonId: missingPersonId,
      tipo: payload.data?.type || 'alerta_general'
    },
    actions: [
      { action: 'open_case', title: '🚨 Ver Caso' },
      { action: 'close', title: 'Cerrar' }
    ]
  };

  return self.registration.showNotification(title, notificationOptions);
});

// Manejo de clic sobre la notificación del navegador
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'close') {
    return;
  }

  const targetUrl = new URL('/', self.location.origin).href;

  const promiseChain = clients.matchAll({
    type: 'window',
    includeUncontrolled: true
  }).then((windowClients) => {
    // Si ya hay una pestaña abierta de la app, enfocarla
    for (let i = 0; i < windowClients.length; i++) {
      const client = windowClients[i];
      if (client.url.startsWith(self.location.origin) && 'focus' in client) {
        return client.focus();
      }
    }
    // Si la app estaba cerrada, abrir una nueva ventana
    if (clients.openWindow) {
      return clients.openWindow(targetUrl);
    }
  });

  event.waitUntil(promiseChain);
});
