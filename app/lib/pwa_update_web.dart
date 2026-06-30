/// Implementacion web: limpia la cache del service worker y recarga la PWA.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get canForceUpdate => true;

Future<void> forceAppUpdate() async {
  // 1) Borra todas las caches del navegador (donde el service worker de Flutter
  //    guarda index.html, el JS, los assets...). Es la capa que se queda
  //    "pegada" en iOS Safari. NO afecta a IndexedDB (los datos de la app).
  final caches = web.window.caches;
  final keys = (await caches.keys().toDart).toDart;
  for (final key in keys) {
    await caches.delete(key.toDart).toDart;
  }

  // 2) Desregistra los service workers para que se vuelva a instalar el nuevo
  //    en la siguiente carga.
  final sw = web.window.navigator.serviceWorker;
  final regs = (await sw.getRegistrations().toDart).toDart;
  for (final reg in regs) {
    await reg.unregister().toDart;
  }

  // 3) Recarga la pagina: al no haber cache ni SW, va a la red y trae lo ultimo.
  web.window.location.reload();
}
