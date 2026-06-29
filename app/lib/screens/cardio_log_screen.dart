import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';

/// Estilos de natacion disponibles en el desplegable.
const List<String> _swimStyles = ['Crol', 'Espalda', 'Braza', 'Mariposa'];

/// Pantalla de registro de un ejercicio de cardio (bici, natacion o cinta).
///
/// A diferencia de fuerza, cada sesion es una sola entrada (no varias series) y
/// los campos dependen del tipo. Guarda automaticamente al editar y muestra el
/// historico y una grafica de progresion con la metrica mas relevante.
class CardioLogScreen extends StatefulWidget {
  const CardioLogScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<CardioLogScreen> createState() => _CardioLogScreenState();
}

class _CardioLogScreenState extends State<CardioLogScreen> {
  late WorkoutRepository _repo;
  DateTime _date = DateTime.now();

  // Controllers de los campos (solo se muestran los del tipo).
  final _durationCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();
  final _inclineCtrl = TextEditingController();
  final _lapsCtrl = TextEditingController();
  String? _style;
  double? _rpe;

  int? _entryId; // id de la entrada del dia (si existe)
  List<SessionSummary> _sessions = [];
  bool _loading = true;

  ExerciseKind get _kind => widget.exercise.kind;
  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkoutRepository>();
    _reload();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _levelCtrl.dispose();
    _distanceCtrl.dispose();
    _speedCtrl.dispose();
    _inclineCtrl.dispose();
    _lapsCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final sets = await _repo.getSetsForDate(widget.exercise.id, _dateKey);
    final sessions = await _repo.getSessions(widget.exercise.id);
    if (sets.isNotEmpty) {
      _fill(sets.first);
    } else {
      // Precarga la ultima sesion como sugerencia (sin id: aun no guardado).
      final last =
          await _repo.getLastSession(widget.exercise.id, before: _dateKey);
      _fill(last != null && last.isNotEmpty ? last.first : null, keepId: false);
    }
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  void _fill(SetEntry? e, {bool keepId = true}) {
    _entryId = keepId ? e?.id : null;
    _durationCtrl.text = e?.durationMin != null ? _fmt(e!.durationMin!) : '';
    _levelCtrl.text = e?.level?.toString() ?? '';
    _distanceCtrl.text = e?.distance != null ? _fmt(e!.distance!) : '';
    _speedCtrl.text = e?.speed != null ? _fmt(e!.speed!) : '';
    _inclineCtrl.text = e?.incline != null ? _fmt(e!.incline!) : '';
    _lapsCtrl.text = e?.laps?.toString() ?? '';
    _style = e?.style;
    _rpe = e?.rpe;
  }

  Future<void> _save() async {
    final entry = SetEntry(
      id: _entryId,
      exerciseId: widget.exercise.id,
      date: _dateKey,
      setIndex: 1,
      rpe: _rpe,
      durationMin: _parseDouble(_durationCtrl.text),
      distance: _parseDouble(_distanceCtrl.text),
      level: _parseInt(_levelCtrl.text),
      speed: _parseDouble(_speedCtrl.text),
      incline: _parseDouble(_inclineCtrl.text),
      laps: _parseInt(_lapsCtrl.text),
      style: _style,
    );
    final id = await _repo.upsertSet(entry);
    _entryId = id;
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

  Future<void> _deleteSession(SessionSummary s) async {
    await _repo.deleteSession(widget.exercise.id, s.date);
    if (s.date == _dateKey) _fill(null, keepId: false);
    await _reload();
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
                const SizedBox(height: 12),
                _fieldsForKind(),
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
      ex.kind.label,
      if (ex.puesto != null && ex.puesto!.isNotEmpty) 'Puesto: ${ex.puesto}',
    ];
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

  /// Campos a registrar segun el tipo de cardio.
  Widget _fieldsForKind() {
    final fields = switch (_kind) {
      ExerciseKind.bike => [
          _numField(_durationCtrl, 'Tiempo (min)'),
          _intField(_levelCtrl, 'Nivel'),
          _numField(_distanceCtrl, 'Distancia (km)'),
        ],
      ExerciseKind.swim => [
          _intField(_lapsCtrl, 'Largos'),
          _styleField(),
          _numField(_durationCtrl, 'Tiempo (min)'),
        ],
      ExerciseKind.treadmill => [
          _numField(_durationCtrl, 'Tiempo (min)'),
          _numField(_distanceCtrl, 'Distancia (km)'),
          _numField(_speedCtrl, 'Velocidad (km/h)'),
          _numField(_inclineCtrl, 'Inclinacion (%)'),
        ],
      ExerciseKind.strength => const <Widget>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in fields) ...[f, const SizedBox(height: 12)],
        _rpeField(),
      ],
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: _decoration(label),
        onChanged: (_) => _save(),
      );

  Widget _intField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _decoration(label),
        onChanged: (_) => _save(),
      );

  Widget _styleField() => DropdownButtonFormField<String?>(
        initialValue: _style,
        decoration: _decoration('Estilo'),
        items: [
          const DropdownMenuItem(value: null, child: Text('-')),
          for (final s in _swimStyles)
            DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) {
          setState(() => _style = v);
          _save();
        },
      );

  Widget _rpeField() => DropdownButtonFormField<double?>(
        initialValue: _rpe,
        decoration: _decoration('RPE (esfuerzo)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('-')),
          for (final v in const [6.0, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10])
            DropdownMenuItem(value: v.toDouble(), child: Text(_fmt(v.toDouble()))),
        ],
        onChanged: (v) {
          setState(() => _rpe = v);
          _save();
        },
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  // ---- Progresion ----

  /// Unidad/etiqueta de la metrica graficada segun el tipo.
  String get _metricLabel => switch (_kind) {
        ExerciseKind.bike =>
          _sessions.any((s) => s.totalDistance > 0) ? 'distancia (km)' : 'tiempo (min)',
        ExerciseKind.swim => 'largos',
        ExerciseKind.treadmill => 'distancia (km)',
        ExerciseKind.strength => '',
      };

  Widget _progressSection() {
    final ordered = [..._sessions]..sort((a, b) => a.date.compareTo(b.date));
    final withMetric =
        ordered.where((s) => s.metricFor(_kind) > 0).toList();
    if (withMetric.length < 2) {
      return _sectionCard(
        'Progresion',
        const Text('Registra al menos 2 sesiones para ver la grafica.'),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < withMetric.length; i++)
        FlSpot(i.toDouble(), withMetric[i].metricFor(_kind)),
    ];
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      'Progresion ($_metricLabel)',
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
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 36),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (withMetric.length / 4).ceilToDouble().clamp(1, 999),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= withMetric.length) {
                      return const SizedBox.shrink();
                    }
                    final d = DateTime.parse(withMetric[i].date);
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

  // ---- Historial ----

  Widget _historySection() {
    if (_sessions.isEmpty) {
      return _sectionCard('Historial', const Text('Aun no hay registros.'));
    }
    return _sectionCard(
      'Historial',
      Column(children: [for (final s in _sessions) _historyTile(s)]),
    );
  }

  Widget _historyTile(SessionSummary s) {
    final d = DateTime.parse(s.date);
    final isCurrent = s.date == _dateKey;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event,
          color: isCurrent ? Theme.of(context).colorScheme.primary : null),
      title: Text(DateFormat('EEE d MMM y', 'es_ES').format(d),
          style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(_detail(s)),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20),
        tooltip: 'Borrar sesion',
        onPressed: () => _deleteSession(s),
      ),
    );
  }

  /// Resumen legible de la sesion segun el tipo.
  String _detail(SessionSummary s) {
    final e = s.sets.first;
    final parts = <String>[];
    switch (_kind) {
      case ExerciseKind.bike:
        if (e.durationMin != null) parts.add('${_fmt(e.durationMin!)} min');
        if (e.level != null) parts.add('nivel ${e.level}');
        if (e.distance != null) parts.add('${_fmt(e.distance!)} km');
      case ExerciseKind.swim:
        if (e.laps != null) parts.add('${e.laps} largos');
        if (e.style != null) parts.add(e.style!);
        if (e.durationMin != null) parts.add('${_fmt(e.durationMin!)} min');
      case ExerciseKind.treadmill:
        if (e.durationMin != null) parts.add('${_fmt(e.durationMin!)} min');
        if (e.distance != null) parts.add('${_fmt(e.distance!)} km');
        if (e.speed != null) parts.add('${_fmt(e.speed!)} km/h');
        if (e.incline != null) parts.add('${_fmt(e.incline!)}%');
      case ExerciseKind.strength:
        break;
    }
    if (e.rpe != null) parts.add('@${_fmt(e.rpe!)}');
    return parts.isEmpty ? '(sin datos)' : parts.join('   ·   ');
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

double? _parseDouble(String t) {
  final s = t.trim().replaceAll(',', '.');
  return s.isEmpty ? null : double.tryParse(s);
}

int? _parseInt(String t) {
  final s = t.trim();
  return s.isEmpty ? null : int.tryParse(s);
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}
