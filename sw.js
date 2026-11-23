/* خدمة العمل دون إنترنت: الملفات الثابتة من الذاكرة، وطلبات Supabase دائما من الشبكة */
var CACHE = 'sq-v21';
var FILES = ['./', 'index.html', 'styles.css', 'data.js', 'db.js', 'icons.js', 'theme.css', 'common.js', 'app.js', 'manifest.webmanifest', 'icon.svg', 'icon-192.png'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(FILES); }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});
self.addEventListener('fetch', function (e) {
  var r = e.request;
  if (r.method !== 'GET' || new URL(r.url).origin !== location.origin) return;
  // الشبكة أولا ثم الذاكرة: يحصل المستخدم على آخر نسخة ويعمل دون إنترنت
  e.respondWith(fetch(r, { cache: 'no-cache' }).then(function (res) {
    var copy = res.clone();
    caches.open(CACHE).then(function (c) { c.put(r, copy); });
    return res;
  }).catch(function () { return caches.match(r).then(function (m) { return m || caches.match('index.html'); }); }));
});
