/// Controlador de preferencias de la app (de momento, el modo de tema).
///
/// Es un [ChangeNotifier] que se provee por encima del [MaterialApp] para que
/// el cambio de tema (claro/oscuro/sistema) se aplique al instante y se
/// persista en la tabla `settings` de SQLite.
library;

import 'package:flutter/material.dart';

import 'repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo);

  final WorkoutRepository _repo;

  static const _kThemeMode = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Carga las preferencias guardadas. Si falla (p.ej. BD aun no lista),
  /// mantiene los valores por defecto sin romper el arranque.
  Future<void> load() async {
    try {
      _themeMode = _parseMode(await _repo.getSetting(_kThemeMode));
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _repo.setSetting(_kThemeMode, _serializeMode(mode));
  }

  static ThemeMode _parseMode(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
