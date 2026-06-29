/// Plan de entrenamiento inicial (datos por defecto).
///
/// Generado a partir de una copia de seguridad real del usuario
/// (plan_entrenamiento_20260629_1940.json). Hay un dia por cada dia de la
/// semana (Lunes..Domingo); las rutinas estan en Lunes, Miercoles y Viernes,
/// y el resto quedan vacios (descanso).
library;

class SeedExercise {
  final String name;
  final String? puesto;
  final String? pauta;
  final bool isWarmup;
  const SeedExercise(this.name, this.puesto, this.pauta, {this.isWarmup = false});
}

class SeedDay {
  final String name;
  final List<SeedExercise> exercises;
  const SeedDay(this.name, this.exercises);
}

const List<SeedExercise> _rutinaLunes = [
  SeedExercise('15 Minutos Bici', null, null, isWarmup: true),
  SeedExercise('EXTENSION DE TRICEPS EN POLEA', 'P6 / P11', '3X15'),
  SeedExercise('ELEVACION FRONTAL', 'P', '3X15'),
  SeedExercise('REMO GIRONDA', 'P 7 o 12', '3X15'),
  SeedExercise('CURL DE BICEPS', 'M 10', '3X15'),
  SeedExercise('ELEVACION LATERAL MANCUERNAS', null, '3X15'),
  SeedExercise('MAQUINA ABS', 'M 27', '3X20S'),
  SeedExercise('MAQUINA PRESS PECHO', 'M 2 o 4', '3X15'),
];

const List<SeedExercise> _rutinaMiercoles = [
  SeedExercise('15 Minutos Cinta', null, null, isWarmup: true),
  SeedExercise('PRENSA HORIZONTAL', 'M 22', '3X15'),
  SeedExercise('EXTENSION DE CUADRICEPS', 'M 25', '3X15'),
  SeedExercise('ISQUIOS SENTADO', 'M 14', '3X15'),
  SeedExercise('ABDUCTORES EN MAQUINA', 'M 15', '3X15'),
  SeedExercise('GEMELO CON MANCUERNA', null, '3X15'),
  SeedExercise('PLANCHAS', null, '3 FALLO'),
];

const List<SeedExercise> _rutinaViernes = [
  SeedExercise('15 Minutos Bici', null, null, isWarmup: true),
  SeedExercise('MAQUINA PRESS PECHO', 'M 2 o 4', '3X15'),
  SeedExercise('REMO GIRONDA', 'P 7 o 12', '3X15'),
  SeedExercise('ELEVACION FRONTAL', 'P', '3X15'),
  SeedExercise('CURL DE BICEPS', null, '3X15'),
  SeedExercise('EXTENSION DE TRICEPS EN POLEA', 'P', '3X15'),
  SeedExercise('PRENSA HORIZONTAL', 'M 22', '3X15'),
  SeedExercise('ABDUCTORES EN MAQUINA', 'M 15', '3X15'),
  SeedExercise('GEMELO CON MANCUERNA', null, '3X15'),
];

/// Un dia por cada dia de la semana, en orden (position 0 = Lunes).
const List<SeedDay> kSeedPlan = [
  SeedDay('Lunes', _rutinaLunes),
  SeedDay('Martes', []),
  SeedDay('Miercoles', _rutinaMiercoles),
  SeedDay('Jueves', []),
  SeedDay('Viernes', _rutinaViernes),
  SeedDay('Sabado', []),
  SeedDay('Domingo', []),
];
