import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import '../settings_controller.dart';
import 'day_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<WorkoutDay>> _days;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<WorkoutRepository>();
    _days = repo.getDays();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (changed == true && mounted) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/icon/logo.png', height: 30, width: 30),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text('Plan de Entrenamiento',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configuracion',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: FutureBuilder<List<WorkoutDay>>(
        future: _days,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            debugPrint('HomeScreen getDays ERROR: ${snap.error}');
            debugPrintStack(stackTrace: snap.stackTrace);
            return Center(child: Text('Error: ${snap.error}'));
          }
          final allDays = snap.data ?? [];
          // weekday: 1=Lunes..7=Domingo  ->  position 0..6
          final todayPos = DateTime.now().weekday - 1;
          final hideRest = context.watch<SettingsController>().hideRestDays;
          final days =
              hideRest ? allDays.where((d) => d.active).toList() : allDays;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _Header(),
              const SizedBox(height: 8),
              if (days.isEmpty)
                const _EmptyDays()
              else
                for (final day in days)
                  _DayCard(day: day, isToday: day.position == todayPos),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoy = DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(DateTime.now());
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.fitness_center),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(hoy),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige el dia y registra tus series.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Estado vacio: cuando se ocultan los descansos y no hay dias de entrenamiento.
class _EmptyDays extends StatelessWidget {
  const _EmptyDays();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No hay dias de entrenamiento marcados.\n'
            'Activalos en Configuracion.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, this.isToday = false});
  final WorkoutDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRest = !day.active;

    final Color? cardColor = isToday
        ? scheme.primaryContainer
        : (isRest ? scheme.surfaceContainerLow : null);

    final Color titleColor = isRest && !isToday
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Card(
      color: cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isToday
              ? scheme.primary
              : (isRest ? scheme.surfaceContainerHighest : scheme.secondaryContainer),
          foregroundColor: isToday
              ? scheme.onPrimary
              : (isRest ? scheme.onSurfaceVariant : scheme.onSecondaryContainer),
          child: Icon(isRest ? Icons.weekend_outlined : Icons.fitness_center),
        ),
        title: Text(
          day.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          isToday
              ? (isRest ? 'Hoy · Descanso' : 'Hoy · Entrenamiento')
              : (isRest ? 'Descanso' : 'Entrenamiento'),
          style: TextStyle(
            color: isToday ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DayScreen(day: day),
          ));
        },
      ),
    );
  }
}
