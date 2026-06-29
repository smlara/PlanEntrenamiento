import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import 'cardio_log_screen.dart';
import 'exercise_log_screen.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.day});
  final WorkoutDay day;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late WorkoutRepository _repo;
  List<Exercise> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkoutRepository>();
    _reload();
  }

  Future<void> _reload() async {
    final items = await _repo.getExercises(widget.day.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  // onReorderItem ya entrega newIndex ajustado (tras quitar el elemento movido).
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    await _repo.reorderExercises(_items.map((e) => e.id).toList());
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
      kind: result.kind,
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
      kind: result.kind,
    );
    _reload();
  }

  Future<void> _duplicateExercise(Exercise ex) async {
    await _repo.duplicateExercise(ex.id);
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicado "${ex.name}"')),
    );
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

  /// Copia todos los ejercicios de este dia al dia que elija el usuario.
  Future<void> _copyExercisesToAnotherDay() async {
    final exercises = _items;
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este dia no tiene ejercicios que copiar')),
      );
      return;
    }
    final days = await _repo.getDays();
    if (!mounted) return;
    final targets = days.where((d) => d.id != widget.day.id).toList();

    final target = await showDialog<WorkoutDay>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Copiar ${exercises.length} ejercicios a...'),
        children: [
          for (final d in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(d.active
                        ? Icons.fitness_center
                        : Icons.weekend_outlined),
                    const SizedBox(width: 12),
                    Text(d.name, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (target == null) return;

    final count = await _repo.copyExercisesToDay(widget.day.id, target.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copiados $count ejercicios a ${target.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.day.name),
        actions: [
          IconButton(
            tooltip: 'Copiar ejercicios a otro dia',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _copyExercisesToAnotherDay,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Anadir ejercicio'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyDay(onAdd: _addExercise)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: _items.length,
                  buildDefaultDragHandles: false,
                  onReorderItem: _onReorder,
                  itemBuilder: (context, i) {
                    final ex = _items[i];
                    return _ExerciseTile(
                      key: ValueKey(ex.id),
                      exercise: ex,
                      dragHandle: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                      onDuplicate: () => _duplicateExercise(ex),
                      onEdit: () => _editExercise(ex),
                      onDelete: () => _deleteExercise(ex),
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
  const _ExerciseTile({
    super.key,
    required this.exercise,
    required this.dragHandle,
    required this.onDuplicate,
    required this.onEdit,
    required this.onDelete,
  });
  final Exercise exercise;
  final Widget dragHandle;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget _actions(ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
        PopupMenuButton<String>(
          tooltip: 'Mas opciones',
          onSelected: (value) {
            switch (value) {
              case 'duplicate':
                onDuplicate();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: Icon(Icons.content_copy_outlined),
                title: Text('Duplicar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text('Borrar', style: TextStyle(color: scheme.error)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (exercise.isWarmup) {
      return Card(
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 8, right: 4),
          leading: dragHandle,
          title: Text(exercise.name),
          subtitle: Row(
            children: [
              Icon(Icons.directions_run, size: 16, color: scheme.primary),
              const SizedBox(width: 4),
              const Text('Calentamiento'),
            ],
          ),
          trailing: _actions(scheme),
        ),
      );
    }

    final chips = <Widget>[
      if (!exercise.isCardio &&
          exercise.puesto != null &&
          exercise.puesto!.isNotEmpty)
        _InfoChip(icon: Icons.place, label: exercise.puesto!),
      if (exercise.pauta != null && exercise.pauta!.isNotEmpty)
        _InfoChip(
          icon: exercise.isCardio ? Icons.flag_outlined : Icons.repeat,
          label: exercise.pauta!,
        ),
    ];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: dragHandle,
        title: Text(exercise.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: chips.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 4, children: chips),
              ),
        trailing: _actions(scheme),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => exercise.isCardio
                ? CardioLogScreen(exercise: exercise)
                : ExerciseLogScreen(exercise: exercise),
          ));
        },
      ),
    );
  }
}

/// Icono representativo de cada tipo de ejercicio.
IconData kindIcon(ExerciseKind kind) => switch (kind) {
      ExerciseKind.strength => Icons.fitness_center,
      ExerciseKind.bike => Icons.directions_bike,
      ExerciseKind.swim => Icons.pool,
      ExerciseKind.treadmill => Icons.directions_run,
    };

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
  final ExerciseKind kind;
  const ExerciseFormResult(
      this.name, this.puesto, this.pauta, this.isWarmup, this.kind);
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
  late ExerciseKind _kind;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _puesto = TextEditingController(text: e?.puesto ?? '');
    _pauta = TextEditingController(text: e?.pauta ?? '');
    _isWarmup = e?.isWarmup ?? false;
    _kind = e?.kind ?? ExerciseKind.strength;
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
    final cardio = _kind.isCardio;
    Navigator.pop(
      context,
      ExerciseFormResult(
        // En cardio el nombre es el propio tipo; no hay puesto ni calentamiento.
        cardio ? _kind.label : _name.text.trim(),
        cardio ? '' : _puesto.text,
        // En cardio, `pauta` guarda el objetivo (p.ej. "40 largos", "30 min").
        _pauta.text,
        cardio ? false : _isWarmup,
        _kind,
      ),
    );
  }

  /// Pista del campo objetivo segun el tipo de cardio.
  String get _objetivoHint => switch (_kind) {
        ExerciseKind.swim => 'p.ej. 40 largos',
        _ => 'p.ej. 30 min',
      };

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
            DropdownButtonFormField<ExerciseKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final k in ExerciseKind.values)
                  DropdownMenuItem(
                    value: k,
                    child: Row(
                      children: [
                        Icon(kindIcon(k), size: 18),
                        const SizedBox(width: 8),
                        Text(k.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) =>
                  setState(() => _kind = v ?? ExerciseKind.strength),
            ),
            const SizedBox(height: 8),
            // En cardio el ejercicio es el propio tipo: solo objetivo opcional.
            if (_kind.isCardio)
              TextFormField(
                controller: _pauta,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Objetivo (opcional)',
                  hintText: _objetivoHint,
                ),
              )
            else ...[
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
