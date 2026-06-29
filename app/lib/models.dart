/// Modelos de datos de la app de entrenamiento.
///
/// Estructura: Dia -> Ejercicio -> Series registradas (SetEntry) por fecha.
library;

/// Tipo de ejercicio. `strength` es fuerza clasica (peso x reps x RPE); el resto
/// son cardio, cada uno con sus propias metricas (ver [SetEntry]).
enum ExerciseKind {
  strength, // fuerza: peso, reps, RPE
  bike, // bici estatica: tiempo, nivel, distancia
  swim, // natacion: largos, estilo, tiempo
  treadmill, // cinta: tiempo, distancia, velocidad, inclinacion
}

extension ExerciseKindX on ExerciseKind {
  /// Valor que se guarda en la columna `kind` de la BD.
  String get dbValue => name;

  bool get isCardio => this != ExerciseKind.strength;

  /// Etiqueta legible en espanol para la UI.
  String get label => switch (this) {
        ExerciseKind.strength => 'Fuerza',
        ExerciseKind.bike => 'Bici estatica',
        ExerciseKind.swim => 'Natacion',
        ExerciseKind.treadmill => 'Cinta',
      };
}

/// Parsea el valor guardado en BD a [ExerciseKind]. Por defecto, fuerza.
ExerciseKind kindFromString(String? v) {
  return switch (v) {
    'bike' => ExerciseKind.bike,
    'swim' => ExerciseKind.swim,
    'treadmill' => ExerciseKind.treadmill,
    _ => ExerciseKind.strength,
  };
}

/// Metricas registrables y su unidad legible. Se usan como clave de objetivo
/// (`goals.metric`) y para leer el valor de cada [SessionSummary].
const Map<String, String> kMetricUnit = {
  'weight': 'kg',
  'distance': 'km',
  'duration': 'min',
  'laps': 'largos',
  'speed': 'km/h',
};

/// Metricas que tienen sentido como objetivo (PR) segun el tipo de ejercicio.
List<String> metricsForKind(ExerciseKind kind) => switch (kind) {
      ExerciseKind.strength => const ['weight'],
      ExerciseKind.bike => const ['distance', 'duration'],
      ExerciseKind.swim => const ['laps', 'duration'],
      ExerciseKind.treadmill => const ['distance', 'duration', 'speed'],
    };

/// Etiqueta legible de una metrica (p.ej. 'distance' -> 'Distancia (km)').
String metricLabel(String metric) => switch (metric) {
      'weight' => 'Peso (kg)',
      'distance' => 'Distancia (km)',
      'duration' => 'Tiempo (min)',
      'laps' => 'Largos',
      'speed' => 'Velocidad (km/h)',
      _ => metric,
    };

class WorkoutDay {
  final int id;
  final String name; // p.ej. "Lunes"
  final int position;
  final bool active; // true = dia de entrenamiento; false = descanso

  const WorkoutDay({
    required this.id,
    required this.name,
    required this.position,
    this.active = true,
  });

  factory WorkoutDay.fromMap(Map<String, Object?> m) => WorkoutDay(
        id: m['id'] as int,
        name: m['name'] as String,
        position: m['position'] as int,
        active: (m['active'] as int? ?? 1) == 1,
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
  final ExerciseKind kind; // fuerza (por defecto) o un tipo de cardio

  const Exercise({
    required this.id,
    required this.dayId,
    required this.name,
    this.puesto,
    this.pauta,
    this.isWarmup = false,
    required this.position,
    this.kind = ExerciseKind.strength,
  });

  bool get isCardio => kind.isCardio;

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
        id: m['id'] as int,
        dayId: m['day_id'] as int,
        name: m['name'] as String,
        puesto: m['puesto'] as String?,
        pauta: m['pauta'] as String?,
        isWarmup: (m['is_warmup'] as int? ?? 0) == 1,
        position: m['position'] as int,
        kind: kindFromString(m['kind'] as String?),
      );
}

/// Una entrada registrada en una fecha. En fuerza es una serie (peso x reps x
/// RPE); en cardio es una sesion con metricas propias del tipo (tiempo, nivel,
/// distancia, largos, estilo...). Los campos que no aplican quedan a null.
class SetEntry {
  final int? id;
  final int exerciseId;
  final String date; // 'yyyy-MM-dd'
  final int setIndex; // 1, 2, 3... (en cardio siempre 1)
  // --- Fuerza ---
  final double? weight; // kg
  final int? reps;
  final double? rpe; // 1-10 (tambien esfuerzo percibido en cardio)
  final String? note;
  // --- Cardio ---
  final double? durationMin; // tiempo en minutos (bici, cinta, natacion opc.)
  final double? distance; // km (bici opc., cinta)
  final int? level; // nivel/dificultad (bici)
  final double? speed; // km/h (cinta)
  final double? incline; // % inclinacion (cinta)
  final int? laps; // largos (natacion)
  final String? style; // estilo (natacion)

  const SetEntry({
    this.id,
    required this.exerciseId,
    required this.date,
    required this.setIndex,
    this.weight,
    this.reps,
    this.rpe,
    this.note,
    this.durationMin,
    this.distance,
    this.level,
    this.speed,
    this.incline,
    this.laps,
    this.style,
  });

  SetEntry copyWith({
    int? id,
    double? weight,
    int? reps,
    double? rpe,
    String? note,
    double? durationMin,
    double? distance,
    int? level,
    double? speed,
    double? incline,
    int? laps,
    String? style,
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
        durationMin: durationMin ?? this.durationMin,
        distance: distance ?? this.distance,
        level: level ?? this.level,
        speed: speed ?? this.speed,
        incline: incline ?? this.incline,
        laps: laps ?? this.laps,
        style: style ?? this.style,
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
        'duration_min': durationMin,
        'distance': distance,
        'level': level,
        'speed': speed,
        'incline': incline,
        'laps': laps,
        'style': style,
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
        durationMin: (m['duration_min'] as num?)?.toDouble(),
        distance: (m['distance'] as num?)?.toDouble(),
        level: (m['level'] as num?)?.toInt(),
        speed: (m['speed'] as num?)?.toDouble(),
        incline: (m['incline'] as num?)?.toDouble(),
        laps: (m['laps'] as num?)?.toInt(),
        style: m['style'] as String?,
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

  // ---- Cardio (en cardio una sesion suele tener una sola entrada) ----

  double get totalDistance =>
      sets.fold<double>(0, (a, s) => a + (s.distance ?? 0));

  double get totalDurationMin =>
      sets.fold<double>(0, (a, s) => a + (s.durationMin ?? 0));

  int get totalLaps => sets.fold<int>(0, (a, s) => a + (s.laps ?? 0));

  double get maxSpeed =>
      sets.map((s) => s.speed ?? 0).fold<double>(0, (a, b) => b > a ? b : a);

  /// Valor de la sesion para una metrica concreta (ver [kMetricUnit]).
  double metricValue(String metric) => switch (metric) {
        'weight' => maxWeight,
        'distance' => totalDistance,
        'duration' => totalDurationMin,
        'laps' => totalLaps.toDouble(),
        'speed' => maxSpeed,
        _ => 0,
      };

  /// Valor a representar en la grafica de progresion segun el tipo:
  /// bici -> distancia (o tiempo si no hay distancia), natacion -> largos,
  /// cinta -> distancia. Devuelve 0 si no hay dato.
  double metricFor(ExerciseKind kind) => switch (kind) {
        ExerciseKind.bike =>
          totalDistance > 0 ? totalDistance : totalDurationMin,
        ExerciseKind.swim => totalLaps.toDouble(),
        ExerciseKind.treadmill => totalDistance,
        ExerciseKind.strength => maxWeight,
      };
}

/// Tipo de objetivo de la pestana Objetivos.
enum GoalType {
  exercise, // marca/PR de un ejercicio concreto
  bodyweight, // peso corporal objetivo
  frequency, // entrenos por semana
}

GoalType goalTypeFromString(String? v) => switch (v) {
      'bodyweight' => GoalType.bodyweight,
      'frequency' => GoalType.frequency,
      _ => GoalType.exercise,
    };

/// Un objetivo del usuario. Segun [type] usa unos campos u otros:
/// - exercise: [exerciseId] + [metric] + [target].
/// - bodyweight: [target] (kg), [startValue] (peso al crear) y [deadline] opc.
/// - frequency: [target] = entrenos por semana.
class Goal {
  final int? id;
  final GoalType type;
  final int? exerciseId;
  final String? metric;
  final double target;
  final double? startValue;
  final String? deadline; // 'yyyy-MM-dd'
  final String? createdAt;

  const Goal({
    this.id,
    required this.type,
    this.exerciseId,
    this.metric,
    required this.target,
    this.startValue,
    this.deadline,
    this.createdAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'exercise_id': exerciseId,
        'metric': metric,
        'target': target,
        'start_value': startValue,
        'deadline': deadline,
        'created_at': createdAt,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int?,
        type: goalTypeFromString(m['type'] as String?),
        exerciseId: m['exercise_id'] as int?,
        metric: m['metric'] as String?,
        target: (m['target'] as num).toDouble(),
        startValue: (m['start_value'] as num?)?.toDouble(),
        deadline: m['deadline'] as String?,
        createdAt: m['created_at'] as String?,
      );
}
