/// Modelos de datos de la app de entrenamiento.
///
/// Estructura: Dia -> Ejercicio -> Series registradas (SetEntry) por fecha.
library;

class WorkoutDay {
  final int id;
  final String name; // p.ej. "DIA 1"
  final int position;

  const WorkoutDay({required this.id, required this.name, required this.position});

  factory WorkoutDay.fromMap(Map<String, Object?> m) => WorkoutDay(
        id: m['id'] as int,
        name: m['name'] as String,
        position: m['position'] as int,
      );
}

class Exercise {
  final int id;
  final int dayId;
  final String name; // p.ej. "MAQUINA PRESS PECHO"
  final String? puesto; // p.ej. "M 2 o 4" (numero de maquina)
  final String? pauta; // p.ej. "3X15" (series x reps prescritas)
  final bool isWarmup; // calentamiento (no se registran series)
  final int position;

  const Exercise({
    required this.id,
    required this.dayId,
    required this.name,
    this.puesto,
    this.pauta,
    this.isWarmup = false,
    required this.position,
  });

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
        id: m['id'] as int,
        dayId: m['day_id'] as int,
        name: m['name'] as String,
        puesto: m['puesto'] as String?,
        pauta: m['pauta'] as String?,
        isWarmup: (m['is_warmup'] as int? ?? 0) == 1,
        position: m['position'] as int,
      );
}

/// Una serie concreta registrada en una fecha: peso x reps y sensacion (RPE).
class SetEntry {
  final int? id;
  final int exerciseId;
  final String date; // 'yyyy-MM-dd'
  final int setIndex; // 1, 2, 3...
  final double? weight; // kg
  final int? reps;
  final double? rpe; // 1-10
  final String? note;

  const SetEntry({
    this.id,
    required this.exerciseId,
    required this.date,
    required this.setIndex,
    this.weight,
    this.reps,
    this.rpe,
    this.note,
  });

  SetEntry copyWith({
    int? id,
    double? weight,
    int? reps,
    double? rpe,
    String? note,
  }) =>
      SetEntry(
        id: id ?? this.id,
        exerciseId: exerciseId,
        date: date,
        setIndex: setIndex,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        rpe: rpe ?? this.rpe,
        note: note ?? this.note,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'exercise_id': exerciseId,
        'date': date,
        'set_index': setIndex,
        'weight': weight,
        'reps': reps,
        'rpe': rpe,
        'note': note,
      };

  factory SetEntry.fromMap(Map<String, Object?> m) => SetEntry(
        id: m['id'] as int?,
        exerciseId: m['exercise_id'] as int,
        date: m['date'] as String,
        setIndex: m['set_index'] as int,
        weight: (m['weight'] as num?)?.toDouble(),
        reps: m['reps'] as int?,
        rpe: (m['rpe'] as num?)?.toDouble(),
        note: m['note'] as String?,
      );
}

/// Resumen de una sesion (todas las series de un ejercicio en una fecha).
class SessionSummary {
  final String date;
  final List<SetEntry> sets;

  const SessionSummary({required this.date, required this.sets});

  double get maxWeight =>
      sets.map((s) => s.weight ?? 0).fold<double>(0, (a, b) => b > a ? b : a);

  double get totalVolume => sets.fold<double>(
      0, (a, s) => a + (s.weight ?? 0) * (s.reps ?? 0));
}
