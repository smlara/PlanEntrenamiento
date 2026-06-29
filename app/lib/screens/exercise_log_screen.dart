import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';

class ExerciseLogScreen extends StatefulWidget {
  const ExerciseLogScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<ExerciseLogScreen> createState() => _ExerciseLogScreenState();
}

class _ExerciseLogScreenState extends State<ExerciseLogScreen> {
  late WorkoutRepository _repo;
  DateTime _date = DateTime.now();
  final List<_SetRow> _rows = [];
  List<SessionSummary> _sessions = [];
  bool _loading = true;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkoutRepository>();
    _reload();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final sets = await _repo.getSetsForDate(widget.exercise.id, _dateKey);
    final sessions = await _repo.getSessions(widget.exercise.id);
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(sets.map((s) => _SetRow.fromEntry(s)));
    if (_rows.isEmpty) {
      _rows.add(_SetRow.empty(1));
    }
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _saveRow(_SetRow row) async {
    final entry = SetEntry(
      id: row.id,
      exerciseId: widget.exercise.id,
      date: _dateKey,
      setIndex: row.setIndex,
      weight: row.weight,
      reps: row.reps,
      rpe: row.rpe,
    );
    final id = await _repo.upsertSet(entry);
    row.id = id;
    final sessions = await _repo.getSessions(widget.exercise.id);
    if (mounted) setState(() => _sessions = sessions);
  }

  void _addRow() {
    final lastWeight = _rows.isNotEmpty ? _rows.last.weight : null;
    final lastReps = _rows.isNotEmpty ? _rows.last.reps : null;
    setState(() {
      final row = _SetRow.empty(_rows.length + 1);
      if (lastWeight != null) row.weightCtrl.text = _fmt(lastWeight);
      if (lastReps != null) row.repsCtrl.text = '$lastReps';
      _rows.add(row);
    });
  }

  Future<void> _copyLastSession() async {
    final last = await _repo.getLastSession(widget.exercise.id, before: _dateKey);
    if (last == null || last.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sesiones anteriores')),
        );
      }
      return;
    }
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    for (var i = 0; i < last.length; i++) {
      final src = last[i];
      final row = _SetRow.empty(i + 1);
      if (src.weight != null) row.weightCtrl.text = _fmt(src.weight!);
      if (src.reps != null) row.repsCtrl.text = '${src.reps}';
      row.rpe = src.rpe;
      _rows.add(row);
    }
    setState(() {});
    for (final r in _rows) {
      await _saveRow(r);
    }
  }

  Future<void> _deleteRow(int index) async {
    final row = _rows[index];
    if (row.id != null) await _repo.deleteSet(row.id!);
    row.dispose();
    setState(() => _rows.removeAt(index));
    // Reordena los set_index visibles.
    for (var i = 0; i < _rows.length; i++) {
      _rows[i].setIndex = i + 1;
    }
    final sessions = await _repo.getSessions(widget.exercise.id);
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      _date = picked;
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(ex.name, style: const TextStyle(fontSize: 18))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _infoBar(ex),
                const SizedBox(height: 12),
                _dateBar(),
                const SizedBox(height: 8),
                _setsHeader(),
                for (var i = 0; i < _rows.length; i++)
                  _setRowWidget(i, _rows[i]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Anadir serie'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyLastSession,
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copiar anterior'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _progressSection(),
                const SizedBox(height: 16),
                _historySection(),
              ],
            ),
    );
  }

  Widget _infoBar(Exercise ex) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (ex.puesto != null && ex.puesto!.isNotEmpty) 'Puesto: ${ex.puesto}',
      if (ex.pauta != null && ex.pauta!.isNotEmpty) 'Pauta: ${ex.pauta}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(parts.join('    •    '),
            style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
    );
  }

  Widget _dateBar() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 18),
        const SizedBox(width: 8),
        Text(DateFormat("EEEE d 'de' MMMM y", 'es_ES').format(_date),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
      ],
    );
  }

  Widget _setsHeader() {
    final style = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#', style: style)),
          Expanded(child: Text('Peso (kg)', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('Reps', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('RPE', style: style)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _setRowWidget(int index, _SetRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${row.setIndex}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: TextField(
              controller: row.weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _dense('kg'),
              onChanged: (_) => _saveRow(row),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.repsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dense('reps'),
              onChanged: (_) => _saveRow(row),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<double?>(
              initialValue: row.rpe,
              isExpanded: true,
              decoration: _dense('RPE'),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final v in const [6.0, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10])
                  DropdownMenuItem(value: v.toDouble(), child: Text(_fmt(v.toDouble()))),
              ],
              onChanged: (v) {
                row.rpe = v;
                _saveRow(row);
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _deleteRow(index),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dense(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: const OutlineInputBorder(),
      );

  Widget _progressSection() {
    // Sesiones ordenadas de antigua a reciente para la grafica.
    final ordered = [..._sessions]..sort((a, b) => a.date.compareTo(b.date));
    final withWeight =
        ordered.where((s) => s.maxWeight > 0).toList();
    if (withWeight.length < 2) {
      return _sectionCard(
        'Progresion',
        const Text('Registra al menos 2 sesiones con peso para ver la grafica.'),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < withWeight.length; i++)
        FlSpot(i.toDouble(), withWeight[i].maxWeight),
    ];
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      'Progresion (peso maximo por sesion)',
      SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36, interval: null),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (withWeight.length / 4).ceilToDouble().clamp(1, 999),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= withWeight.length) {
                      return const SizedBox.shrink();
                    }
                    final d = DateTime.parse(withWeight[i].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('d/M').format(d),
                          style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: scheme.primary,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                    show: true, color: scheme.primary.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historySection() {
    if (_sessions.isEmpty) {
      return _sectionCard('Historial', const Text('Aun no hay registros.'));
    }
    return _sectionCard(
      'Historial',
      Column(
        children: [
          for (final s in _sessions) _historyTile(s),
        ],
      ),
    );
  }

  Widget _historyTile(SessionSummary s) {
    final d = DateTime.parse(s.date);
    final detail = s.sets
        .map((e) =>
            '${e.weight != null ? _fmt(e.weight!) : '-'}kg x ${e.reps ?? '-'}${e.rpe != null ? ' @${_fmt(e.rpe!)}' : ''}')
        .join('   ');
    final isCurrent = s.date == _dateKey;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event,
          color: isCurrent ? Theme.of(context).colorScheme.primary : null),
      title: Text(DateFormat('EEE d MMM y', 'es_ES').format(d),
          style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(detail),
      trailing: Text('vol ${s.totalVolume.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.outline)),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Fila editable de una serie (controllers + estado).
class _SetRow {
  int? id;
  int setIndex;
  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  double? rpe;

  _SetRow({
    this.id,
    required this.setIndex,
    String weight = '',
    String reps = '',
    this.rpe,
  })  : weightCtrl = TextEditingController(text: weight),
        repsCtrl = TextEditingController(text: reps);

  factory _SetRow.empty(int index) => _SetRow(setIndex: index);

  factory _SetRow.fromEntry(SetEntry e) => _SetRow(
        id: e.id,
        setIndex: e.setIndex,
        weight: e.weight != null ? _fmt(e.weight!) : '',
        reps: e.reps?.toString() ?? '',
        rpe: e.rpe,
      );

  double? get weight {
    final t = weightCtrl.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  int? get reps {
    final t = repsCtrl.text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  void dispose() {
    weightCtrl.dispose();
    repsCtrl.dispose();
  }
}
