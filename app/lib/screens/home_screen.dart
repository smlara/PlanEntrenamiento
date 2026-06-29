import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import 'day_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Entrenamiento'),
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
          final days = snap.data ?? [];
          // weekday: 1=Lunes..7=Domingo  ->  position 0..6
          final todayPos = DateTime.now().weekday - 1;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _Header(),
              const SizedBox(height: 8),
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
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.fitness_center, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Elige el dia que vas a entrenar y registra tus series.',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
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
    return Card(
      color: isToday ? scheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isToday ? scheme.primary : null,
          foregroundColor: isToday ? scheme.onPrimary : null,
          child: Text(day.name.substring(0, 1)),
        ),
        title: Text(day.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: isToday ? const Text('Hoy') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DayScreen(day: day),
          ));
        },
      ),
    );
  }
}
