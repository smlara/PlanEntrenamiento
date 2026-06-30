/// Utilidad para forzar la actualizacion de la PWA. Solo tiene efecto en web.
///
/// En iOS Safari el service worker de Flutter cachea los assets de forma muy
/// persistente y la PWA puede quedarse en una version antigua. Esta utilidad
/// borra esas caches y desregistra el service worker, de modo que al recargar
/// se descargue la ultima version. Los datos (IndexedDB) NO se tocan.
library;

import 'pwa_update_stub.dart'
    if (dart.library.html) 'pwa_update_web.dart' as impl;

/// `true` si la plataforma permite forzar la actualizacion (solo web/PWA).
bool get canForceUpdate => impl.canForceUpdate;

/// Borra la cache del service worker, lo desregistra y recarga la pagina.
Future<void> forceAppUpdate() => impl.forceAppUpdate();
