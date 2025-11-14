// UCASH Service Worker - Cache Intelligent Online/Offline
// Version 1.0.0

const CACHE_NAME = 'ucash-v1.0.0';
const DATA_CACHE_NAME = 'ucash-data-v1.0.0';

// Ressources à mettre en cache immédiatement
const STATIC_CACHE_URLS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter_service_worker.js',
  '/manifest.json',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
  '/assets/fonts/MaterialIcons-Regular.otf',
  '/canvaskit/canvaskit.js',
  '/canvaskit/canvaskit.wasm',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/favicon.png'
];

// URLs des API à mettre en cache
const API_CACHE_URLS = [
  '/api/auth/',
  '/api/operations/',
  '/api/clients/',
  '/api/shops/',
  '/api/agents/',
  '/api/sync/'
];

// Stratégies de cache
const CACHE_STRATEGIES = {
  CACHE_FIRST: 'cache-first',
  NETWORK_FIRST: 'network-first',
  STALE_WHILE_REVALIDATE: 'stale-while-revalidate',
  NETWORK_ONLY: 'network-only',
  CACHE_ONLY: 'cache-only'
};

// Installation du Service Worker
self.addEventListener('install', event => {
  console.log('[SW] Installation en cours...');
  
  event.waitUntil(
    Promise.all([
      // Cache des ressources statiques
      caches.open(CACHE_NAME).then(cache => {
        console.log('[SW] Mise en cache des ressources statiques');
        return cache.addAll(STATIC_CACHE_URLS);
      }),
      
      // Préparation du cache de données
      caches.open(DATA_CACHE_NAME).then(cache => {
        console.log('[SW] Préparation du cache de données');
        return Promise.resolve();
      })
    ]).then(() => {
      console.log('[SW] Installation terminée');
      // Forcer l'activation immédiate
      return self.skipWaiting();
    })
  );
});

// Activation du Service Worker
self.addEventListener('activate', event => {
  console.log('[SW] Activation en cours...');
  
  event.waitUntil(
    Promise.all([
      // Nettoyage des anciens caches
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== CACHE_NAME && cacheName !== DATA_CACHE_NAME) {
              console.log('[SW] Suppression de l\'ancien cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      
      // Prise de contrôle immédiate
      self.clients.claim()
    ]).then(() => {
      console.log('[SW] Activation terminée');
    })
  );
});

// Interception des requêtes
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Ignorer les requêtes non-HTTP
  if (!request.url.startsWith('http')) {
    return;
  }
  
  // Stratégie selon le type de ressource
  if (isStaticResource(url)) {
    event.respondWith(handleStaticResource(request));
  } else if (isAPIRequest(url)) {
    event.respondWith(handleAPIRequest(request));
  } else if (isNavigationRequest(request)) {
    event.respondWith(handleNavigationRequest(request));
  } else {
    event.respondWith(handleOtherRequest(request));
  }
});

// Gestion des ressources statiques (Cache First)
async function handleStaticResource(request) {
  try {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    console.log('[SW] Erreur ressource statique:', error);
    return caches.match(request);
  }
}

// Gestion des requêtes API (Network First avec fallback)
async function handleAPIRequest(request) {
  try {
    // Tentative réseau en premier
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      // Mise en cache de la réponse réussie
      if (request.method === 'GET') {
        const cache = await caches.open(DATA_CACHE_NAME);
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    }
    
    throw new Error('Réponse réseau non OK');
  } catch (error) {
    console.log('[SW] Erreur réseau API, tentative cache:', error);
    
    // Fallback vers le cache pour les requêtes GET
    if (request.method === 'GET') {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        // Ajouter un header pour indiquer que c'est du cache
        const response = cachedResponse.clone();
        response.headers.set('X-Served-By', 'sw-cache');
        return response;
      }
    }
    
    // Retourner une réponse d'erreur offline
    return createOfflineResponse(request);
  }
}

// Gestion de la navigation (SPA)
async function handleNavigationRequest(request) {
  try {
    const networkResponse = await fetch(request);
    return networkResponse;
  } catch (error) {
    console.log('[SW] Navigation offline, retour vers index.html');
    const cachedResponse = await caches.match('/index.html');
    return cachedResponse || createOfflineResponse(request);
  }
}

// Gestion des autres requêtes
async function handleOtherRequest(request) {
  try {
    return await fetch(request);
  } catch (error) {
    const cachedResponse = await caches.match(request);
    return cachedResponse || createOfflineResponse(request);
  }
}

// Vérifications de type de ressource
function isStaticResource(url) {
  const staticExtensions = ['.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.woff', '.woff2', '.ttf', '.otf'];
  const pathname = url.pathname.toLowerCase();
  
  return staticExtensions.some(ext => pathname.endsWith(ext)) ||
         pathname.includes('/assets/') ||
         pathname.includes('/canvaskit/') ||
         pathname.includes('/icons/');
}

function isAPIRequest(url) {
  return url.pathname.startsWith('/api/') || 
         url.pathname.startsWith('/server/') ||
         API_CACHE_URLS.some(apiUrl => url.pathname.startsWith(apiUrl));
}

function isNavigationRequest(request) {
  return request.mode === 'navigate' || 
         (request.method === 'GET' && request.headers.get('accept').includes('text/html'));
}

// Création d'une réponse offline
function createOfflineResponse(request) {
  if (request.headers.get('accept').includes('application/json')) {
    // Réponse JSON pour les API
    return new Response(
      JSON.stringify({
        error: 'offline',
        message: 'Application en mode hors ligne',
        timestamp: new Date().toISOString()
      }),
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'application/json',
          'X-Served-By': 'sw-offline'
        }
      }
    );
  } else {
    // Page HTML offline
    return new Response(
      `<!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>UCASH - Mode Hors Ligne</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #DC2626 0%, #B91C1C 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            text-align: center;
          }
          .container {
            max-width: 400px;
            padding: 40px;
            background: rgba(255,255,255,0.1);
            border-radius: 16px;
            backdrop-filter: blur(10px);
          }
          .icon {
            font-size: 64px;
            margin-bottom: 20px;
          }
          h1 {
            margin: 0 0 16px 0;
            font-size: 24px;
            font-weight: 600;
          }
          p {
            margin: 0 0 24px 0;
            opacity: 0.9;
            line-height: 1.5;
          }
          .retry-btn {
            background: white;
            color: #DC2626;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
          }
          .retry-btn:hover {
            transform: translateY(-2px);
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">📱</div>
          <h1>Mode Hors Ligne</h1>
          <p>UCASH fonctionne en mode hors ligne. Vos données seront synchronisées dès que la connexion sera rétablie.</p>
          <button class="retry-btn" onclick="window.location.reload()">
            Réessayer
          </button>
        </div>
      </body>
      </html>`,
      {
        status: 200,
        headers: {
          'Content-Type': 'text/html',
          'X-Served-By': 'sw-offline'
        }
      }
    );
  }
}

// Gestion des messages du client
self.addEventListener('message', event => {
  const { type, payload } = event.data;
  
  switch (type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;
      
    case 'GET_VERSION':
      event.ports[0].postMessage({
        type: 'VERSION',
        payload: { version: CACHE_NAME }
      });
      break;
      
    case 'CLEAR_CACHE':
      clearAllCaches().then(() => {
        event.ports[0].postMessage({
          type: 'CACHE_CLEARED',
          payload: { success: true }
        });
      });
      break;
      
    case 'CACHE_URLS':
      if (payload && payload.urls) {
        cacheUrls(payload.urls).then(() => {
          event.ports[0].postMessage({
            type: 'URLS_CACHED',
            payload: { success: true }
          });
        });
      }
      break;
  }
});

// Fonctions utilitaires
async function clearAllCaches() {
  const cacheNames = await caches.keys();
  return Promise.all(
    cacheNames.map(cacheName => caches.delete(cacheName))
  );
}

async function cacheUrls(urls) {
  const cache = await caches.open(CACHE_NAME);
  return cache.addAll(urls);
}

// Synchronisation en arrière-plan
self.addEventListener('sync', event => {
  console.log('[SW] Synchronisation en arrière-plan:', event.tag);
  
  if (event.tag === 'ucash-sync') {
    event.waitUntil(performBackgroundSync());
  }
});

async function performBackgroundSync() {
  try {
    console.log('[SW] Début de la synchronisation...');
    
    // Ici, vous pouvez ajouter la logique de synchronisation
    // Par exemple, envoyer les données en attente vers le serveur
    
    console.log('[SW] Synchronisation terminée');
  } catch (error) {
    console.log('[SW] Erreur de synchronisation:', error);
  }
}

// Notifications push (si nécessaire)
self.addEventListener('push', event => {
  if (!event.data) return;
  
  const data = event.data.json();
  const options = {
    body: data.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-72.png',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: [
      {
        action: 'open',
        title: 'Ouvrir UCASH'
      },
      {
        action: 'close',
        title: 'Fermer'
      }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title || 'UCASH', options)
  );
});

// Gestion des clics sur les notifications
self.addEventListener('notificationclick', event => {
  event.notification.close();
  
  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

console.log('[SW] Service Worker UCASH chargé - Version:', CACHE_NAME);
