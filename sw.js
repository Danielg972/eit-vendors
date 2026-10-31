// D-69 (31 Oct 2026): phone notifications for job alerts (web push). This file does only that.
// It has no fetch handler and caches nothing, so the page is always loaded from the network as before and the app's own
// "keep itself up to date" check (D-48, in index.html) works exactly as it did. Scope: the app's folder ("./").
// A notification carries {title, body, url, tag}. Tapping it opens the app at that address (#job=<id>, or #jobs=group
// for Eretz Israel Tours' list for the jobs WhatsApp group): an open copy of the app is brought forward and told where
// to go; otherwise a new window opens.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (x) { d = { body: e.data ? e.data.text() : '' }; }
  const title = d.title || 'The Inner Circle';
  e.waitUntil(self.registration.showNotification(title, {
    body: d.body || '', tag: d.tag || undefined, renotify: !!d.tag,
    icon: 'icon-192.png', badge: 'icon-192.png', lang: 'en', data: { url: d.url || './' }
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || './', self.registration.scope).href;
  e.waitUntil((async () => {
    const scope = self.registration.scope;
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const c = all.find((w) => w.url.startsWith(scope) && !/\/(b|f|next[^/]*)\//.test(w.url.slice(scope.length - 1)));
    if (c) { try { await c.focus(); } catch (x) {} c.postMessage({ type: 'eitv-open', url }); return; }
    await self.clients.openWindow(url);
  })());
});
