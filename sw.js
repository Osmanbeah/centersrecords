// Service Worker for Centers Record (Offline PWA)
const CACHE_NAME = 'centers-record-v15';

const STATIC_ASSETS = [
    './',
    './index.html',
    './admin.html',
    './schedule.html',
    './generate_cards.html',
    './kelany_new_portrait.png',
    './qrcode.min.js',
    './supabase.min.js',
    './html5-qrcode.min.js',
    './manifest.json',
    './icon.svg'
];

// Precache static shell on install
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            return cache.addAll(STATIC_ASSETS).catch((err) => {
                console.warn('[SW] Precache non-critical warning:', err);
            });
        }).then(() => self.skipWaiting())
    );
});

// Clean up old caches on activate
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => {
            return Promise.all(
                keys.map((key) => {
                    if (key !== CACHE_NAME) {
                        console.log('[SW] Deleting old cache:', key);
                        return caches.delete(key);
                    }
                })
            );
        }).then(() => self.clients.claim())
    );
});

// Intercept fetch requests
self.addEventListener('fetch', (event) => {
    const request = event.request;
    const url = new URL(request.url);

    // Bypass non-GET requests (e.g. POST to Supabase)
    if (request.method !== 'GET') {
        return;
    }

    // Bypass Supabase Realtime WebSocket connections
    if (url.pathname.includes('/realtime/') || url.protocol === 'ws:' || url.protocol === 'wss:') {
        return;
    }

    // For Supabase REST endpoints: try network first; if offline, return offline synthetic response or let client handle
    if (url.hostname.includes('supabase.co')) {
        event.respondWith(
            fetch(request).catch(() => {
                return new Response(JSON.stringify({ offline: true, message: 'Offline mode active' }), {
                    status: 503,
                    headers: { 'Content-Type': 'application/json' }
                });
            })
        );
        return;
    }

    // For HTML navigation and page loads: Network First with offline fallback
    const isHtml = request.mode === 'navigate' || 
                   url.pathname.endsWith('.html') || 
                   url.pathname === '/' || 
                   (request.headers.get('accept') && request.headers.get('accept').includes('text/html'));

    if (isHtml) {
        event.respondWith(
            fetch(request).then((networkResponse) => {
                if (networkResponse && networkResponse.status === 200) {
                    const responseClone = networkResponse.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(request, responseClone);
                    });
                }
                return networkResponse;
            }).catch(() => {
                return caches.match(request).then((cached) => {
                    if (cached) return cached;
                    if (url.pathname.includes('schedule')) return caches.match('./schedule.html');
                    if (url.pathname.includes('admin')) return caches.match('./admin.html');
                    return caches.match('./index.html');
                });
            })
        );
        return;
    }

    // For static assets, Google fonts, and scripts: Stale-While-Revalidate
    event.respondWith(
        caches.match(request).then((cachedResponse) => {
            const fetchPromise = fetch(request).then((networkResponse) => {
                if (networkResponse && networkResponse.status === 200) {
                    const responseClone = networkResponse.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(request, responseClone);
                    });
                }
                return networkResponse;
            }).catch(() => null);

            return cachedResponse || fetchPromise;
        })
    );
});
