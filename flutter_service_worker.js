'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/assets/images/python_logo.png": "cc177c25264e532d947ec8f4d5a2e740",
"assets/assets/images/nextjs-logo.png": "9ce6a3a40c8b999ca2e295d922521141",
"assets/assets/images/Kotlin-logo.png": "c66281251163d1c4b5f6a68b78ae5b54",
"assets/assets/images/PHP-logo.png": "a1b506b18b108e0cd167e21fab03e2b0",
"assets/assets/images/Java-logo.png": "a41ac8c68b5c0a693474e886e3e5eadd",
"assets/assets/images/FastAPI-logo.png": "57a1091211dd2fd65b9387d026f81145",
"assets/assets/images/csharp-logo.png": "f4b7ac91a9510255ab54e7dd7e39026e",
"assets/assets/images/django-logo.png": "82a03371931d0649de809847f839d41d",
"assets/assets/images/React-logo.png": "1d3c6131372dc45f3e4ce71a687022af",
"assets/assets/images/deepseek_logo.png": "10b98f81c4d7aa228eafe15f636f55b7",
"assets/assets/images/JavaScript-logo.png": "246b02016c7ff2d3400eb8f4f884e7a5",
"assets/assets/images/svelte-logo.png": "ba9b1e00b5e9307cdc50a30ddfec33d2",
"assets/assets/images/TypeScript-logo.png": "5c1d5f3aecec92f3db825d0f89c30499",
"assets/assets/images/Vue-logo.png": "321dcf336ec56f6e8f48e45bf480d545",
"assets/assets/images/brand/logo-tech-trends.png": "6f0244dfede79defb92f72914eb63b91",
"assets/assets/images/Laravel-logo.png": "76234882fcf6c5f148c102eda3703f06",
"assets/assets/images/cpp-logo.png": "d8c6efc0dced4d5c642a7b2329b34f9c",
"assets/assets/images/chatgpt-logo.png": "1096f5623e992e09a5b25127e769926f",
"assets/assets/images/Rust-logo.png": "be4800529cbac91be586f5cd5f462136",
"assets/assets/images/Go-logo.png": "be58bda8dfeee8a622ba49e4b3e64ad7",
"assets/assets/images/Spring-logo.png": "f8b57c34e0293d5ef3ccffabf8e20020",
"assets/assets/images/Express-logo.jpeg": "7d5239586cea249870dee64802e87bdd",
"assets/assets/images/angular_logo.png": "15653e1cbdd7e25ff7e9754a98c6fafd",
"assets/assets/data/reddit_temas_emergentes.csv": "7bbfa3de1a4090928978ee848efc95ef",
"assets/assets/data/so_tendencias_mensuales.csv": "bbd3be91002e5a85c4692c11347988c1",
"assets/assets/data/history_index.json": "d32dc6ae793ff7f3d739d2ded7c1f7d0",
"assets/assets/data/so_tasa_aceptacion.csv": "f776eb78f85fc5bec59be688dfe92df2",
"assets/assets/data/home_highlights.json": "0f593b2f849ffacd5133d6719f79c9f9",
"assets/assets/data/so_aceptacion_history.json": "daa008fa10b8d42bef68015a3fdfdb87",
"assets/assets/data/so_volumen_history.json": "e8ad7bcb894af30b9a40b6d99bb447c0",
"assets/assets/data/trend_score.csv": "c063013149619566251159af4ea41e5d",
"assets/assets/data/reddit_interseccion_history.json": "f3cba470303a46bbb6e6109ff2bfa148",
"assets/assets/data/github_commits_frameworks.csv": "67f58851a050a9a6964813cf52226445",
"assets/assets/data/so_volumen_preguntas.csv": "064faf0d275322b589b336084c088bf1",
"assets/assets/data/github_lenguajes_public.json": "5fbf6846f7fbc4e316a4bba94084b3a2",
"assets/assets/data/interseccion_github_reddit.csv": "1144ca02018fa06e333d2fe2dcc28b80",
"assets/assets/data/trend_score_history.json": "8a0ebb9dcf1f9431c2da18133d913c28",
"assets/assets/data/so_tendencias_history.json": "ee5b4db7109e1008651311a0b737e3d9",
"assets/assets/data/github_correlacion_history.json": "64c8d9b56efdd7b8cf4186753e7f82cd",
"assets/assets/data/run_manifest.json": "c98b91406e26a93f6ab7639293d1459f",
"assets/assets/data/reddit_temas_history.json": "ef0a60e8d7725a19dbfa97427d25bc1b",
"assets/assets/data/github_correlacion.csv": "39d42b5b2b18ca9720ccb24f995d207a",
"assets/assets/data/reddit_sentimiento_frameworks.csv": "28d565db350674f22a4e714b32914081",
"assets/assets/data/github_frameworks_history.json": "d63658d3da0962c40d8504099efecc87",
"assets/assets/data/github_lenguajes.csv": "ab740058acb84d734538928518dbd9a5",
"assets/assets/data/reddit_sentimiento_public.json": "fb227f2850b5f687d3bec069840657e2",
"assets/assets/data/technology_profiles.json": "1ee22167abdcf300c7085e09fd1a672d",
"assets/fonts/MaterialIcons-Regular.otf": "63472aa7bd1595925126acf0423f1a24",
"assets/AssetManifest.bin": "fac317ac5bd6d37c6c3bb1448e2e956e",
"assets/FontManifest.json": "c75f7af11fb9919e042ad2ee704db319",
"assets/AssetManifest.bin.json": "9ff5c1095c4eddc6fe26b2044c2f5559",
"assets/NOTICES": "81285ff321e7cc0e9b7555720c9609a6",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "48e3f3b679e316c8e9f76f1aa19424cc",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "48b92e8451309fdcb73d294f0f6e9830",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "46be639d952abe98effde36da35e7701",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"version.json": "2b521e10dfa0f067561de489a19d6620",
"index.html": "bf33e248ff0e4942c0cea36226347aad",
"/": "bf33e248ff0e4942c0cea36226347aad",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"sitemap.xml": "b076d85ca60b6ad6b7fd833ccee86fd7",
"robots.txt": "21d682146f41ccd993a046cb6159a572",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"flutter_bootstrap.js": "810222ce356e0f958fa1dceb5763593c",
"manifest.json": "e77a3e97e8b9e5d4d7f3b52840e7dbc8",
"404.html": "f1d0a658185caf17bf3913fa934fe155",
"main.dart.js": "e71708c09174349a484d853d610bcff9"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
