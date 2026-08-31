const CACHE_NAME = 'pos-cache-v1';
const OFFLINE_URL = '/offline.html';

const APP_SHELL = [
  '/',
  '/pos-terminal',
  '/css/pos.css',
  '/js/idb-manager.js',
  '/js/pos-sync.js',
  '/js/escpos.js',
  '/js/pos-hardware.js',
  '/images/logo.png',
  OFFLINE_URL
];

// Helper functions
const isApiCall = (url) => url.includes('/ords/');
const isStaticAsset = (url) => {
  const staticExtensions = ['.css', '.js', '.png', '.jpg', '.jpeg', '.gif', '.woff', '.woff2', '.ttf', '.svg'];
  return staticExtensions.some(ext => url.toLowerCase().endsWith(ext));
};

self.addEventListener('install', (event) => {
  console.log('[Service Worker] Install Event');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Pre-caching App Shell');
      return cache.addAll(APP_SHELL);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activate Event');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log(`[Service Worker] Deleting old cache: ${cacheName}`);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = request.url;

  // Background Sync for POST requests to /ords/pos/sync/
  if (request.method === 'POST' && url.includes('/ords/pos/sync/')) {
    // Relying on network first, assuming main thread handled IDB queueing if offline
    event.respondWith(fetch(request).catch(error => {
      console.error('[Service Worker] Sync endpoint fetch failed:', error);
      throw error;
    }));
    return;
  }

  if (isStaticAsset(url)) {
    // Cache-First strategy
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        return fetch(request).then((networkResponse) => {
          return caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, networkResponse.clone());
            return networkResponse;
          });
        });
      })
    );
  } else if (isApiCall(url) && request.method === 'GET') {
    // Network-First strategy for GET API calls
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          return caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, networkResponse.clone());
            return networkResponse;
          });
        })
        .catch(() => {
          return caches.match(request);
        })
    );
  } else {
    // Network-First with offline fallback for other navigation requests
    event.respondWith(
      fetch(request)
        .catch(() => {
          return caches.match(request).then((cachedResponse) => {
            if (cachedResponse) {
              return cachedResponse;
            }
            if (request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }
            return new Response('Network error happened', { status: 408, headers: { 'Content-Type': 'text/plain' } });
          });
        })
    );
  }
});

self.addEventListener('sync', (event) => {
  if (event.tag === 'pos-offline-sync') {
    console.log('[Service Worker] Sync event triggered: pos-offline-sync');
    event.waitUntil(replayOfflineQueue());
  }
});

async function replayOfflineQueue() {
  try {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('POS_OFFLINE_DB', 1);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });

    const tx = db.transaction('offlineQueue', 'readwrite');
    const store = tx.objectStore('offlineQueue');
    const allReq = store.getAll();

    const items = await new Promise((resolve, reject) => {
      allReq.onsuccess = () => resolve(allReq.result);
      allReq.onerror = () => reject(allReq.error);
    });

    let successCount = 0;

    for (const item of items) {
      if (item.status === 'PENDING') {
        try {
          const response = await fetch('/ords/pos/sync/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(item.payload)
          });

          if (response.ok) {
            successCount++;
            const deleteTx = db.transaction('offlineQueue', 'readwrite');
            deleteTx.objectStore('offlineQueue').delete(item.queue_id);
          }
        } catch (error) {
          console.error('[Service Worker] Failed to replay queue item:', error);
        }
      }
    }

    if (successCount > 0) {
      self.registration.showNotification('POS Sync Complete', {
        body: `Successfully synced ${successCount} offline action(s).`,
        icon: '/images/logo.png',
        tag: 'sync-complete'
      });
    }

  } catch (error) {
    console.error('[Service Worker] Error during background sync replay:', error);
  }
}

self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push event received', event.data?.text());
  let data = { title: 'POS Sync', body: 'Sync operation finished.', icon: '/images/logo.png' };
  try {
    if (event.data) {
      data = Object.assign(data, event.data.json());
    }
  } catch (e) {
    console.error('[Service Worker] Error parsing push data', e);
  }

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: data.icon,
      tag: 'pos-sync-notification'
    })
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            console.log(`[Service Worker] Clearing cache via message: ${cacheName}`);
            return caches.delete(cacheName);
          })
        );
      })
    );
  }
});
