import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import '../settings_controller.dart';

/// Pestana de objetivos. Tres tipos:
/// - exercise: marca/PR de un ejercicio (progreso desde el historico).
/// - bodyweight: peso corporal objetivo (progreso desde Biometricos).
/// - frequency: entrenos por semana (semana actual, racha y mes).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late WorkoutRepository _repo;
  late Future<List<_GoalView>> _future;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkoutRepository>();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  Future<List<_GoalView>> _load() async {
    final weight = context.read<SettingsController>().weightKg;
    final goals = await _repo.getGoals();
    final exercises = {
      for (final e in await _repo.getAllExercises()) e.id: e,
    };
    final dates = await _repo.getAllTrainingDates();
    final views = <_GoalView>[];
    for (final g in goals) {
      views.add(switch (g.type) {
        GoalType.exercise =>
          await _exerciseView(g, exercises[g.exerciseId]),
        GoalType.bodyweight => _bodyweightView(g, weight),
        GoalType.frequency => _frequencyView(g, dates),
      });
    }
    return views;
  }

  Future<_GoalView> _exerciseView(Goal g, Exercise? ex) async {
    final metric = g.metric ?? 'weight';
    final unit = kMetricUnit[metric] ?? '';
    final best = ex == null ? 0.0 : await _repo.getBestMetric(ex.id, metric);
    final frac = g.target > 0 ? (best / g.target).clamp(0.0, 1.0) : 0.0;
    return _GoalView(
      goal: g,
      icon: Icons.fitness_center,
      title: ex?.name ?? 'Ejercicio',
      subtitle: '${_fmt(best)} / ${_fmt(g.target)} $unit',
      fraction: frac,
    );
  }

  _GoalView _bodyweightView(Goal g, double? weight) {
    final start = g.startValue;
    double frac = 0;
    String subtitle;
    if (weight == null) {
      subtitle = 'Define tu peso en Biometricos';
    } else if (start != null && start != g.target) {
      frac = ((start - weight) / (start - g.target)).clamp(0.0, 1.0);
      final faltan = (weight - g.target).abs();
      subtitle = 'Actual ${_fmt(weight)} kg · meta ${_fmt(g.target)} kg'
          '${faltan > 0 ? ' · faltan ${_fmt(faltan)} kg' : ' · ¡logrado!'}';
    } else {
      frac = (weight - g.target).abs() < 0.05 ? 1 : 0;
      subtitle = 'Actual ${_fmt(weight)} kg · meta ${_fmt(g.target)} kg';
    }
    final deadline = g.deadline != null
        ? ' · antes de ${DateFormat('d MMM y', 'es_ES').format(DateTime.parse(g.deadline!))}'
        : '';
    return _GoalView(
      goal: g,
      icon: Icons.monitor_weight_outlined,
      title: 'Peso corporal',
      subtitle: '$subtitle$deadline',
      fraction: frac,
    );
  }

  _GoalView _frequencyView(Goal g, List<String> dates) {
    final target = g.target.round();
    final now = DateTime.now();
    final thisWeekMonday = _mondayOf(now);

    final counts = <DateTime, int>{};
    var thisMonth = 0;
    for (final d in dates) {
      final date = DateTime.parse(d);
      counts.update(_mondayOf(date), (v) => v + 1, ifAbsent: () => 1);
      if (date.year == now.year && date.month == now.month) thisMonth++;
    }
    final thisWeek = counts[thisWeekMonday] ?? 0;

    // Racha: semanas consecutivas que cumplen el objetivo. La semana en curso
    // solo cuenta si ya lo cumple (no rompe la racha si aun va a medias).
    var streak = 0;
    var wk = thisWeekMonday;
    if ((counts[wk] ?? 0) < target) wk = wk.subtract(const Duration(days: 7));
    while ((counts[wk] ?? 0) >= target) {
      streak++;
      wk = wk.subtract(const Duration(days: 7));
    }

    final frac = target > 0 ? (thisWeek / target).clamp(0.0, 1.0) : 0.0;
    return _GoalView(
      goal: g,
      icon: Icons.event_repeat,
      title: 'Frecuencia · $target/semana',
      subtitle:
          'Esta semana $thisWeek/$target · racha $streak sem · mes $thisMonth',
      fraction: frac,
    );
  }

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<void> _addOrEdit([Goal? existing]) async {
    final exercises = await _repo.getAllExercises();
    if (!mounted) return;
    final weight = context.read<SettingsController>().weightKg;
    final result = await showDialog<Goal>(
      context: context,
      builder: (_) => _GoalDialog(
        existing: existing,
        exercises: exercises,
        currentWeight: weight,
      ),
    );
    if (result == null) return;
    if (result.id == null) {
      await _repo.addGoal(result);
    } else {
      await _repo.updateGoal(result);
    }
    _refresh();
  }

  Future<void> _delete(Goal g) async {
    await _repo.deleteGoal(g.id!);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Recalcula al cambiar el peso (objetivo de peso corporal).
    context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo objetivo'),
      ),
      body: FutureBuilder<List<_GoalView>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final views = snap.data ?? [];
          if (views.isEmpty) return const _EmptyGoals();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              for (final v in views)
                _GoalCard(
                  view: v,
                  onEdit: () => _addOrEdit(v.goal),
                  onDelete: () => _delete(v.goal),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalView {
  final Goal goal;
  final IconData icon;
  final String title;
  final String subtitle;
  final double fraction;
  const _GoalView({
    required this.goal,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fraction,
  });
}

class _GoalCard extends StatelessWidget {
  const _GoalCard(
      {required this.view, required this.onEdit, required this.onDelete});
  final _GoalView view;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (view.fraction * 100).round();
    final done = view.fraction >= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(view.icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(view.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (done)
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                            contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: scheme.error),
                            title: Text('Borrar',
                                style: TextStyle(color: scheme.error)),
                            contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: view.fraction,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(view.subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 12),
            const Text('Sin objetivos todavia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Crea metas de marca, peso o frecuencia.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Dialogo para crear o editar un objetivo.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    this.existing,
    required this.exercises,
    required this.currentWeight,
  });
  final Goal? existing;
  final List<Exercise> exercises;
  final double? currentWeight;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late GoalType _type;
  int? _exerciseId;
  String? _metric;
  DateTime? _deadline;
  final _target = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _type = g?.type ?? GoalType.exercise;
    _exerciseId = g?.exerciseId ?? widget.exercises.firstOrNull?.id;
    _metric = g?.metric;
    _deadline = g?.deadline != null ? DateTime.tryParse(g!.deadline!) : null;
    if (g != null) _target.text = _fmt(g.target);
    _syncMetric();
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Exercise? get _exercise =>
      widget.exercises.where((e) => e.id == _exerciseId).firstOrNull;

  /// Asegura que la metrica elegida es valida para el ejercicio seleccionado.
  void _syncMetric() {
    if (_type != GoalType.exercise) return;
    final opts = _exercise == null ? const ['weight'] : metricsForKind(_exercise!.kind);
    if (_metric == null || !opts.contains(_metric)) _metric = opts.first;
  }

  void _save() {
    final target = double.tryParse(_target.text.trim().replaceAll(',', '.'));
    if (target == null || target <= 0) {
      _snack('Pon un valor objetivo valido');
      return;
    }
    double? startValue = widget.existing?.startValue;
    if (_type == GoalType.bodyweight) {
      if (widget.currentWeight == null) {
        _snack('Primero define tu peso en Biometricos');
        return;
      }
      // Baseline para el progreso: el peso al crear el objetivo.
      startValue ??= widget.currentWeight;
    }
    if (_type == GoalType.exercise && _exerciseId == null) {
      _snack('Elige un ejercicio');
      return;
    }
    Navigator.pop(
      context,
      Goal(
        id: widget.existing?.id,
        type: _type,
        exerciseId: _type == GoalType.exercise ? _exerciseId : null,
        metric: _type == GoalType.exercise ? _metric : null,
        target: target,
        startValue: startValue,
        deadline: _type == GoalType.bodyweight && _deadline != null
            ? DateFormat('yyyy-MM-dd').format(_deadline!)
            : null,
        createdAt: widget.existing?.createdAt,
      ),
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo objetivo' : 'Editar objetivo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<GoalType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                    value: GoalType.exercise, child: Text('Marca de ejercicio')),
                DropdownMenuItem(
                    value: GoalType.bodyweight, child: Text('Peso corporal')),
                DropdownMenuItem(
                    value: GoalType.frequency, child: Text('Frecuencia')),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? GoalType.exercise;
                _syncMetric();
              }),
            ),
            const SizedBox(height: 12),
            ..._fieldsForType(),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  List<Widget> _fieldsForType() {
    switch (_type) {
      case GoalType.exercise:
        final opts =
            _exercise == null ? const ['weight'] : metricsForKind(_exercise!.kind);
        final unit = kMetricUnit[_metric] ?? '';
        return [
          if (widget.exercises.isEmpty)
            const Text('No hay ejercicios. Crea alguno primero.')
          else
            DropdownButtonFormField<int>(
              initialValue: _exerciseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ejercicio'),
              items: [
                for (final e in widget.exercises)
                  DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _exerciseId = v;
                _syncMetric();
              }),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Metrica'),
            items: [
              for (final m in opts)
                DropdownMenuItem(value: m, child: Text(metricLabel(m))),
            ],
            onChanged: (v) => setState(() => _metric = v),
          ),
          const SizedBox(height: 12),
          _targetField(suffix: unit),
        ];
      case GoalType.bodyweight:
        return [
          _targetField(label: 'Peso objetivo', suffix: 'kg'),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(_deadline == null
                ? 'Sin fecha limite'
                : 'Antes de ${DateFormat('d MMM y', 'es_ES').format(_deadline!)}'),
            trailing: _deadline == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _deadline = null),
                  ),
            onTap: _pickDeadline,
          ),
        ];
      case GoalType.frequency:
        return [_targetField(label: 'Entrenos por semana', suffix: 'd/sem')];
    }
  }

  Widget _targetField({String label = 'Objetivo', String suffix = ''}) {
    return TextField(
      controller: _target,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) setState(() => _deadline = picked);
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}
