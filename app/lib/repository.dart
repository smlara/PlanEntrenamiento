/// Acceso a datos: dias, ejercicios y registro de series.
library;

import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

class WorkoutRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<WorkoutDay>> getDays() async {
    final db = await _db;
    final rows = await db.query('days', orderBy: 'position ASC');
    return rows.map(WorkoutDay.fromMap).toList();
  }

  /// Marca un dia como de entrenamiento (true) o descanso (false).
  Future<void> setDayActive(int dayId, bool active) async {
    final db = await _db;
    await db.update('days', {'active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [dayId]);
  }

  // ---- Preferencias (settings clave/valor) ----

  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getExercises(int dayId) async {
    final db = await _db;
    final rows = await db.query('exercises',
        where: 'day_id = ?', whereArgs: [dayId], orderBy: 'position ASC');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise> getExercise(int id) async {
    final db = await _db;
    final rows = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    return Exercise.fromMap(rows.first);
  }

  /// Anade un ejercicio al final del dia indicado. Devuelve su id.
  Future<int> addExercise(
    int dayId, {
    required String name,
    String? puesto,
    String? pauta,
    bool isWarmup = false,
    ExerciseKind kind = ExerciseKind.strength,
  }) async {
    final db = await _db;
    final maxRow = await db.rawQuery(
        'SELECT COALESCE(MAX(position), -1) AS m FROM exercises WHERE day_id = ?',
        [dayId]);
    final nextPos = (maxRow.first['m'] as int) + 1;
    return db.insert('exercises', {
      'day_id': dayId,
      'name': name,
      'puesto': (puesto != null && puesto.trim().isEmpty) ? null : puesto?.trim(),
      'pauta': (pauta != null && pauta.trim().isEmpty) ? null : pauta?.trim(),
      'is_warmup': isWarmup ? 1 : 0,
      'position': nextPos,
      'kind': kind.dbValue,
    });
  }

  Future<void> updateExercise(
    int id, {
    required String name,
    String? puesto,
    String? pauta,
    bool isWarmup = false,
    ExerciseKind kind = ExerciseKind.strength,
  }) async {
    final db = await _db;
    await db.update(
      'exercises',
      {
        'name': name,
        'puesto':
            (puesto != null && puesto.trim().isEmpty) ? null : puesto?.trim(),
        'pauta':
            (pauta != null && pauta.trim().isEmpty) ? null : pauta?.trim(),
        'is_warmup': isWarmup ? 1 : 0,
        'kind': kind.dbValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reordena los ejercicios: guarda la posicion de cada id segun su orden
  /// en la lista (0, 1, 2...).
  Future<void> reorderExercises(List<int> orderedIds) async {
    final db = await _db;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update('exercises', {'position': i},
          where: 'id = ?', whereArgs: [orderedIds[i]]);
    }
    await batch.commit(noResult: true);
  }

  /// Duplica un ejercicio dentro de su mismo dia (al final). No copia el
  /// historial de series; solo la "plantilla" (nombre, puesto, pauta...).
  Future<int> duplicateExercise(int id) async {
    final ex = await getExercise(id);
    return addExercise(
      ex.dayId,
      name: ex.name,
      puesto: ex.puesto,
      pauta: ex.pauta,
      isWarmup: ex.isWarmup,
      kind: ex.kind,
    );
  }

  /// Copia todos los ejercicios de [fromDayId] al final de [toDayId].
  /// No copia el historial de series. Devuelve cuantos ejercicios copio.
  Future<int> copyExercisesToDay(int fromDayId, int toDayId) async {
    final list = await getExercises(fromDayId);
    for (final ex in list) {
      await addExercise(
        toDayId,
        name: ex.name,
        puesto: ex.puesto,
        pauta: ex.pauta,
        isWarmup: ex.isWarmup,
        kind: ex.kind,
      );
    }
    return list.length;
  }

  /// Borra un ejercicio y todo su historial de series.
  Future<void> deleteExercise(int id) async {
    final db = await _db;
    await db.delete('set_entries', where: 'exercise_id = ?', whereArgs: [id]);
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  /// Series de un ejercicio en una fecha concreta, ordenadas por numero de serie.
  Future<List<SetEntry>> getSetsForDate(int exerciseId, String date) async {
    final db = await _db;
    final rows = await db.query('set_entries',
        where: 'exercise_id = ? AND date = ?',
        whereArgs: [exerciseId, date],
        orderBy: 'set_index ASC');
    return rows.map(SetEntry.fromMap).toList();
  }

  /// Todas las sesiones (fechas) de un ejercicio, mas reciente primero.
  Future<List<SessionSummary>> getSessions(int exerciseId) async {
    final db = await _db;
    final rows = await db.query('set_entries',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
        orderBy: 'date DESC, set_index ASC');
    final entries = rows.map(SetEntry.fromMap).toList();
    final byDate = <String, List<SetEntry>>{};
    for (final e in entries) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    return byDate.entries
        .map((e) => SessionSummary(date: e.key, sets: e.value))
        .toList();
  }

  /// Ultima fecha registrada para precargar valores (sugerencia de peso).
  Future<List<SetEntry>?> getLastSession(int exerciseId, {String? before}) async {
    final db = await _db;
    final where = before == null
        ? 'exercise_id = ?'
        : 'exercise_id = ? AND date < ?';
    final args = before == null ? [exerciseId] : [exerciseId, before];
    final last = await db.query('set_entries',
        columns: ['date'],
        where: where,
        whereArgs: args,
        orderBy: 'date DESC',
        limit: 1);
    if (last.isEmpty) return null;
    return getSetsForDate(exerciseId, last.first['date'] as String);
  }

  Future<int> upsertSet(SetEntry entry) async {
    final db = await _db;
    if (entry.id != null) {
      await db.update('set_entries', entry.toMap(),
          where: 'id = ?', whereArgs: [entry.id]);
      return entry.id!;
    }
    return db.insert('set_entries', entry.toMap());
  }

  Future<void> deleteSet(int id) async {
    final db = await _db;
    await db.delete('set_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(int exerciseId, String date) async {
    final db = await _db;
    await db.delete('set_entries',
        where: 'exercise_id = ? AND date = ?', whereArgs: [exerciseId, date]);
  }

  // ---- Copia de seguridad (exportar / importar) ----

  /// Exporta TODA la configuracion y los datos: dias (con su estado activo),
  /// ejercicios, series registradas y preferencias.
  Future<Map<String, Object?>> exportData() async {
    final db = await _db;
    return {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'days': await db.query('days'),
      'exercises': await db.query('exercises'),
      'set_entries': await db.query('set_entries'),
      'settings': await db.query('settings'),
    };
  }

  /// Restaura una copia de seguridad. Si el backup es del formato completo
  /// (incluye `days`), REEMPLAZA todos los datos actuales. Si es del formato
  /// antiguo (solo `set_entries`), los anade.
  Future<void> importData(Map<String, Object?> data) async {
    final db = await _db;
    final days = (data['days'] as List?)?.cast<Map<String, Object?>>();

    if (days != null) {
      final exercises =
          (data['exercises'] as List? ?? []).cast<Map<String, Object?>>();
      final entries =
          (data['set_entries'] as List? ?? []).cast<Map<String, Object?>>();
      final settings =
          (data['settings'] as List? ?? []).cast<Map<String, Object?>>();
      await db.transaction((txn) async {
        await txn.delete('set_entries');
        await txn.delete('exercises');
        await txn.delete('days');
        await txn.delete('settings');
        final batch = txn.batch();
        for (final r in days) {
          batch.insert('days', r);
        }
        for (final r in exercises) {
          batch.insert('exercises', r);
        }
        for (final r in entries) {
          batch.insert('set_entries', r);
        }
        for (final r in settings) {
          batch.insert('settings', r);
        }
        await batch.commit(noResult: true);
      });
      return;
    }

    // Formato antiguo: solo series, se anaden.
    final entries = (data['set_entries'] as List).cast<Map<String, Object?>>();
    final batch = db.batch();
    for (final e in entries) {
      final m = Map<String, Object?>.from(e)..remove('id');
      batch.insert('set_entries', m);
    }
    await batch.commit(noResult: true);
  }
}
