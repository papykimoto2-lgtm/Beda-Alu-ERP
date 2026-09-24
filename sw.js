/* Sanix AluExpert ERP — Service worker (mode hors ligne).
   Garde en cache l'application (index.html, config.js, bibliothèques CDN) pour qu'elle s'ouvre
   sans connexion. Les DONNÉES (Supabase) ne passent pas par ici : elles sont gérées dans
   index.html (cache de lecture + file d'attente des saisies, synchronisée au retour du réseau). */
const VERSION = 'aluexpert-v10';
const COQUILLE = ['./', './index.html', './config.js', './manifest.webmanifest', './icon.svg', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-maskable-192.png', './icons/icon-maskable-512.png', './icons/apple-touch-icon.png', './icons/favicon-32.png'];
const CDN = /^https:\/\/(cdn\.tailwindcss\.com|cdn\.jsdelivr\.net|cdnjs\.cloudflare\.com|fonts\.googleapis\.com|fonts\.gstatic\.com)\//;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => Promise.all(COQUILLE.map((u) => c.add(u).catch(() => {})))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((cles) => Promise.all(cles.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Pages et fichiers de l'application : réseau d'abord (dernière version), cache si hors ligne
  if (url.origin === self.location.origin) {
    e.respondWith(
      fetch(req).then((res) => {
        if (res.ok) { const copie = res.clone(); caches.open(VERSION).then((c) => c.put(req, copie)); }
        return res;
      }).catch(() => caches.match(req, { ignoreSearch: true })
        .then((r) => r || (req.mode === 'navigate' ? caches.match('./index.html') : Response.error())))
    );
    return;
  }
  // Bibliothèques CDN (Tailwind, Supabase JS, Chart.js, Leaflet…) : cache d'abord, mise à jour en arrière-plan
  if (CDN.test(req.url)) {
    e.respondWith(caches.open(VERSION).then((c) => c.match(req).then((enCache) => {
      const reseau = fetch(req).then((res) => { if (res.ok || res.type === 'opaque') c.put(req, res.clone()); return res; });
      return enCache || reseau;
    })));
  }
});
