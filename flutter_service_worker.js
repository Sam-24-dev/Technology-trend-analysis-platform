'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"version.json": "2b521e10dfa0f067561de489a19d6620",
"main.dart.js_1.part.js": "cf3b8484cbf5de148129543fa57dc75b",
"main.dart.js_7.part.js": "4a95ee276e0768ad8195ff03df0bb1e8",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"index.html": "3327b057a7ad2184707c5dea1af3b288",
"/": "3327b057a7ad2184707c5dea1af3b288",
"main.dart.js_14.part.js": "c8d84232d252193f63938ad9cdf5f4e3",
"main.dart.js_10.part.js": "59521b321c7a7f18130dbf2a8e07b642",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"main.dart.js_13.part.js": "f07c290ec9a476b4464e8cbcd330a051",
"robots.txt": "21d682146f41ccd993a046cb6159a572",
"main.dart.mjs": "9d97899a200a81c1835dfbebe10cabd7",
"main.dart.js_12.part.js": "d3874d679dc37f27ff48fb8aa495770d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"main.dart.js_5.part.js": "0f4103bb9249637898135d60fa80d75b",
"main.dart.js_15.part.js": "b50fe2624a43304b6047728971e1304b",
"main.dart.js_4.part.js": "89750f85cfb09be84d8d45714265c713",
"sitemap.xml": "b8a97d73641c41e2f154b12b006b47e2",
"main.dart.js_11.part.js": "e804f52dec1bd4d5e42137e977d56553",
"main.dart.wasm": "b44329f0c96d3544979dce16aece2439",
"main.dart.js_6.part.js": "7bb851e34f913144fcb68345c6e3c012",
"assets/AssetManifest.bin.json": "374fc4a733778920c8128311b0d8970b",
"assets/NOTICES": "fd13f333ad01922655dd10096165ae16",
"assets/fonts/MaterialIcons-Regular.otf": "5f1775ffcd57f2d2d0844a74d9d3a7b9",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin": "f70aaf0272e526304a89b2febd8739f2",
"assets/assets/images/csharp-logo.png": "f4b7ac91a9510255ab54e7dd7e39026e",
"assets/assets/images/JavaScript-logo.png": "246b02016c7ff2d3400eb8f4f884e7a5",
"assets/assets/images/angular_logo.png": "15653e1cbdd7e25ff7e9754a98c6fafd",
"assets/assets/images/Go-logo.png": "be58bda8dfeee8a622ba49e4b3e64ad7",
"assets/assets/images/Laravel-logo.png": "76234882fcf6c5f148c102eda3703f06",
"assets/assets/images/python_logo.png": "cc177c25264e532d947ec8f4d5a2e740",
"assets/assets/images/deepseek_logo.png": "10b98f81c4d7aa228eafe15f636f55b7",
"assets/assets/images/django-logo.png": "82a03371931d0649de809847f839d41d",
"assets/assets/images/svelte-logo.png": "ba9b1e00b5e9307cdc50a30ddfec33d2",
"assets/assets/images/FastAPI-logo.png": "57a1091211dd2fd65b9387d026f81145",
"assets/assets/images/Vue-logo.png": "321dcf336ec56f6e8f48e45bf480d545",
"assets/assets/images/brand/logo-tech-trends.png": "adecc20cd408ddf69694d71555c62de6",
"assets/assets/images/cpp-logo.png": "d8c6efc0dced4d5c642a7b2329b34f9c",
"assets/assets/images/Kotlin-logo.png": "c66281251163d1c4b5f6a68b78ae5b54",
"assets/assets/images/Spring-logo.png": "f8b57c34e0293d5ef3ccffabf8e20020",
"assets/assets/images/chatgpt-logo.png": "1096f5623e992e09a5b25127e769926f",
"assets/assets/images/PHP-logo.png": "a1b506b18b108e0cd167e21fab03e2b0",
"assets/assets/images/Express-logo.jpeg": "7d5239586cea249870dee64802e87bdd",
"assets/assets/images/React-logo.png": "1d3c6131372dc45f3e4ce71a687022af",
"assets/assets/images/Java-logo.png": "a41ac8c68b5c0a693474e886e3e5eadd",
"assets/assets/images/nextjs-logo.png": "9ce6a3a40c8b999ca2e295d922521141",
"assets/assets/images/Rust-logo.png": "be4800529cbac91be586f5cd5f462136",
"assets/assets/images/TypeScript-logo.png": "5c1d5f3aecec92f3db825d0f89c30499",
"assets/assets/data/run_manifest.json": "26f83a73c52912b40a36513a92820886",
"assets/assets/data/so_volumen_preguntas.csv": "9cb5436753bacfbf7c829885c82d3a8f",
"assets/assets/data/history_index.json": "1be9084fede914d9a2b49e829cbba867",
"assets/assets/data/github_frameworks_history.json": "01e6fa0b4885d9a366de4ee5d8d11ebf",
"assets/assets/data/so_tendencias_history.json": "0f97fe6e1b506e4f5100bb7c911fcd58",
"assets/assets/data/reddit_interseccion_history.json": "ddb810ccbf7b25b421a6ac6223fbcd3e",
"assets/assets/data/reddit_temas_emergentes.csv": "1704341cf0c3937e5a45f5687719a37e",
"assets/assets/data/github_lenguajes_public.json": "e5c8248eb4ca526877b432e3f51bb62b",
"assets/assets/data/github_lenguajes.csv": "a540e68bf153364edffc5e50cb7190f0",
"assets/assets/data/so_tendencias_mensuales.csv": "bd534c538c78b6adc590ec40b4d268e2",
"assets/assets/data/reddit_sentimiento_public.json": "cb715215599661e41989dc83e799cdeb",
"assets/assets/data/so_volumen_history.json": "bc1ea09b782f90fc7af9330e26592bbb",
"assets/assets/data/so_tasa_aceptacion.csv": "523e7cb3d3fc04643d37e4ee8ab3f26a",
"assets/assets/data/trend_score_history.json": "ef79f744a99a9e28a7fcda3cd02d5949",
"assets/assets/data/technology_profiles.json": "acdf3aaa22b78caed938d9f936a70551",
"assets/assets/data/interseccion_github_reddit.csv": "df0e98d855121eebe885d449d0d308cc",
"assets/assets/data/home_highlights.json": "4d369e23c58bb9d315e59797db9ce2c5",
"assets/assets/data/reddit_sentimiento_frameworks.csv": "e7e3c05bbd83c813a19e216f593e5fe4",
"assets/assets/data/github_commits_frameworks.csv": "03ddb22f80bf6413a5d8f8cf4ff82442",
"assets/assets/data/reddit_temas_history.json": "bf8de540b6dda27b4bd5377c8f48ad5a",
"assets/assets/data/github_correlacion.csv": "05b468b045adb1ca73203c5de9f54b7c",
"assets/assets/data/trend_score.csv": "413403f8d93bf19ac080fc842c667750",
"assets/assets/data/github_correlacion_history.json": "2698f9f0d729b257b8356e472f259d74",
"assets/assets/data/so_aceptacion_history.json": "6747c025eecb8cd379d8424405c9a6fa",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"main.dart.js": "0c0eae4e3c486b0de0cac9c6ca621660",
"404.html": "f1d0a658185caf17bf3913fa934fe155",
"main.dart.js_3.part.js": "3f0902b0d0095d56cffd547f7ba41a55",
"main.dart.js_9.part.js": "d6cca60cea1002567cda2061b3676618",
"flutter_bootstrap.js": "b8fed420ce683cfd571d2bd70dce592d",
"main.dart.js_2.part.js": "60caa643ea983b34332a09b1e3e964f6",
"main.dart.js_8.part.js": "d0fc46a97116a9536173adf3c5ada391",
"manifest.json": "e77a3e97e8b9e5d4d7f3b52840e7dbc8"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"main.dart.wasm",
"main.dart.mjs",
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
