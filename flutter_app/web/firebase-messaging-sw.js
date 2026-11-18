// EVA Canteen — Firebase Cloud Messaging Web Service Worker.
// Degrades cleanly to a no-op when Firebase Web Push credentials are not configured.

try {
  importScripts('./firebase-config.js');
} catch (_) {
  // Missing config file is non-fatal; Web Push stays disabled.
}

function hasValidFirebaseWebConfig(cfg) {
  return Boolean(
    cfg &&
      typeof cfg === 'object' &&
      typeof cfg.apiKey === 'string' &&
      cfg.apiKey.trim().length > 0 &&
      typeof cfg.projectId === 'string' &&
      cfg.projectId.trim().length > 0 &&
      typeof cfg.messagingSenderId === 'string' &&
      cfg.messagingSenderId.trim().length > 0 &&
      typeof cfg.appId === 'string' &&
      cfg.appId.trim().length > 0
  );
}

function buildTargetPath(data) {
  const baseRoute =
    data && typeof data.route === 'string' && data.route.startsWith('/')
      ? data.route
      : '/orders';
  const orderId =
    data && typeof data.orderId === 'string' ? data.orderId.trim() : '';
  if (orderId) {
    return `${baseRoute}?orderId=${encodeURIComponent(orderId)}`;
  }
  return baseRoute;
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data =
    (event.notification && event.notification.data) ||
    (event.notification &&
      event.notification.data &&
      event.notification.data.FCM_MSG &&
      event.notification.data.FCM_MSG.data) ||
    {};
  const fcmData =
    data && data.FCM_MSG && typeof data.FCM_MSG.data === 'object'
      ? data.FCM_MSG.data
      : data;

  const targetUrl = new URL(buildTargetPath(fcmData), self.location.origin).href;

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if (client.url.startsWith(self.location.origin)) {
            if ('navigate' in client) {
              return client.navigate(targetUrl).then((navigated) => {
                if (navigated && 'focus' in navigated) {
                  return navigated.focus();
                }
                return client.focus();
              });
            }
            if ('focus' in client) {
              return client.focus();
            }
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(targetUrl);
        }
        return undefined;
      })
  );
});

const firebaseConfig = self.EVA_FIREBASE_WEB_CONFIG;
if (hasValidFirebaseWebConfig(firebaseConfig)) {
  try {
    importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
    importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }

    const messaging = firebase.messaging();
    messaging.onBackgroundMessage((payload) => {
      // When FCM delivers a top-level `notification` object, the browser displays
      // it automatically. Only render manually for data-only payloads.
      if (payload && payload.notification) {
        return;
      }

      const data = (payload && payload.data) || {};
      const pickupNumber = data.pickupNumber || '';
      const title = pickupNumber
        ? `Order ${pickupNumber} is ready!`
        : 'EVA Canteen';
      const body = 'Your order is ready for pickup at the EVA Canteen counter.';

      self.registration.showNotification(title, {
        body,
        icon: '/icons/Icon-192.png',
        tag: data.orderId || 'eva_order_ready',
        renotify: true,
        data,
      });
    });
  } catch (_) {
    // Offline or blocked CDN script must never crash the service worker.
  }
}
