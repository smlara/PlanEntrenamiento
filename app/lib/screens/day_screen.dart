import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import 'exercise_log_screen.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.day});
  final WorkoutDay day;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late WorkoutRepository _repo;
  late Future<List<Exercise>> _exercises;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkoutRepository>();
    _reload();
  }

  void _reload() {
    setState(() {
      _exercises = _repo.getExercises(widget.day.id);
    });
  }

  Future<void> _addExercise() async {
    final result = await showExerciseForm(context);
    if (result == null) return;
    await _repo.addExercise(
      widget.day.id,
      name: result.name,
      puesto: result.puesto,
      pauta: result.pauta,
      isWarmup: result.isWarmup,
    );
    _reload();
  }

  Future<void> _editExercise(Exercise ex) async {
    final result = await showExerciseForm(context, existing: ex);
    if (result == null) return;
    await _repo.updateExercise(
      ex.id,
      name: result.name,
      puesto: result.puesto,
      pauta: result.pauta,
      isWarmup: result.isWarmup,
    );
    _reload();
  }

  Future<void> _deleteExercise(Exercise ex) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar ejercicio'),
        content: Text(
            'Se eliminara "${ex.name}" y todo su historial de series. Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteExercise(ex.id);
    _reload();
  }

  void _showOptions(Exercise ex) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(ctx);
                _editExercise(ex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Borrar'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteExercise(ex);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.day.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Anadir ejercicio'),
      ),
      body: FutureBuilder<List<Exercise>>(
        future: _exercises,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final exercises = snap.data ?? [];
          if (exercises.isEmpty) {
            return _EmptyDay(onAdd: _addExercise);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: exercises.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, i) => _ExerciseTile(
              exercise: exercises[i],
              onOptions: () => _showOptions(exercises[i]),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('Dia de descanso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('No hay ejercicios. Anade los que quieras.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Anadir ejercicio'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onOptions});
  final Exercise exercise;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (exercise.isWarmup) {
      return Card(
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(Icons.directions_run, color: scheme.primary),
          title: Text(exercise.name),
          subtitle: const Text('Calentamiento'),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: onOptions,
          ),
        ),
      );
    }

    final chips = <Widget>[
      if (exercise.puesto != null && exercise.puesto!.isNotEmpty)
        _InfoChip(icon: Icons.place, label: exercise.puesto!),
      if (exercise.pauta != null && exercise.pauta!.isNotEmpty)
        _InfoChip(icon: Icons.repeat, label: exercise.pauta!),
    ];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(exercise.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: chips.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 4, children: chips),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onOptions,
        ),
        onLongPress: onOptions,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseLogScreen(exercise: exercise),
          ));
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}

/// Resultado del formulario de ejercicio.
class ExerciseFormResult {
  final String name;
  final String? puesto;
  final String? pauta;
  final bool isWarmup;
  const ExerciseFormResult(this.name, this.puesto, this.pauta, this.isWarmup);
}

/// Muestra el formulario para crear o editar un ejercicio.
Future<ExerciseFormResult?> showExerciseForm(BuildContext context,
    {Exercise? existing}) {
  return showDialog<ExerciseFormResult>(
    context: context,
    builder: (ctx) => _ExerciseFormDialog(existing: existing),
  );
}

class _ExerciseFormDialog extends StatefulWidget {
  const _ExerciseFormDialog({this.existing});
  final Exercise? existing;

  @override
  State<_ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<_ExerciseFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _puesto;
  late final TextEditingController _pauta;
  late bool _isWarmup;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _puesto = TextEditingController(text: e?.puesto ?? '');
    _pauta = TextEditingController(text: e?.pauta ?? '');
    _isWarmup = e?.isWarmup ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _puesto.dispose();
    _pauta.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ExerciseFormResult(
        _name.text.trim(),
        _puesto.text,
        _pauta.text,
        _isWarmup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Nuevo ejercicio'
          : 'Editar ejercicio'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'p.ej. PRESS BANCA',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pon un nombre' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _puesto,
              decoration: const InputDecoration(
                labelText: 'Puesto / maquina',
                hintText: 'p.ej. M 22',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pauta,
              decoration: const InputDecoration(
                labelText: 'Pauta',
                hintText: 'p.ej. 3X15',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Es calentamiento'),
              subtitle: const Text('No se registran series'),
              value: _isWarmup,
              onChanged: (v) => setState(() => _isWarmup = v),
            ),
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
}
