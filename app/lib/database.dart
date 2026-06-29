/// Capa de base de datos SQLite, compatible con movil nativo, escritorio y web/PWA.
library;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// Necesario en Android/iOS: provee el databaseFactory nativo en runtime.
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'seed_data.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// v2: los dias pasan de "DIA 1/2/3" a los 7 dias de la semana.
  static const int _version = 2;

  Database? _db;

  OpenDatabaseOptions get _options => OpenDatabaseOptions(
        version: _version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

  Future<Database> get database async {
    if (_db != null) return _db!;
    try {
      _db = await _open();
    } catch (e, st) {
      // ignore: avoid_print
      print('DB OPEN ERROR >>> $e');
      // ignore: avoid_print
      print('DB OPEN STACK >>> $st');
      rethrow;
    }
    return _db!;
  }

  Future<Database> _open() async {
    // Selecciona el motor segun la plataforma.
    if (kIsWeb) {
      // Sin web worker: carga sqlite3.wasm en el hilo principal. Mas fiable en
      // navegador/PWA (evita fallos del shared worker) y persiste en IndexedDB.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return databaseFactory.openDatabase(
        'plan_entrenamiento.db',
        options: _options,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // En Android/iOS se usa el databaseFactory nativo por defecto.

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'plan_entrenamiento.db');
    return databaseFactory.openDatabase(path, options: _options);
  }

  Future<void> _onConfigure(Database db) async {
    // Activa las claves foraneas (ON DELETE CASCADE).
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Migracion. Como el cambio de estructura de dias (3 -> 7) es incompatible
  /// con los datos previos, se recrea el esquema desde cero.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS set_entries');
    await db.execute('DROP TABLE IF EXISTS exercises');
    await db.execute('DROP TABLE IF EXISTS days');
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE days (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        position INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY,
        day_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        puesto TEXT,
        pauta TEXT,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL,
        FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE set_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        rpe REAL,
        note TEXT,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_entries_ex_date ON set_entries(exercise_id, date)');

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();
    var dayId = 1;
    var exId = 1;
    for (var d = 0; d < kSeedPlan.length; d++) {
      final day = kSeedPlan[d];
      batch.insert('days', {'id': dayId, 'name': day.name, 'position': d});
      for (var e = 0; e < day.exercises.length; e++) {
        final ex = day.exercises[e];
        batch.insert('exercises', {
          'id': exId,
          'day_id': dayId,
          'name': ex.name,
          'puesto': ex.puesto,
          'pauta': ex.pauta,
          'is_warmup': ex.isWarmup ? 1 : 0,
          'position': e,
        });
        exId++;
      }
      dayId++;
    }
    await batch.commit(noResult: true);
  }
}
