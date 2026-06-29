import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repository.dart';
import '../settings_controller.dart';

/// Pantalla de configuracion (pestana): apariencia (tema), dias de entrenamiento
/// activos y copia de seguridad. La home recoge los cambios al reconstruirse al
/// volver a su pestana.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<WorkoutDay>> _days;

  @override
  void initState() {
    super.initState();
    _days = context.read<WorkoutRepository>().getDays();
  }

  Future<void> _toggleDay(WorkoutDay day, bool active) async {
    final repo = context.read<WorkoutRepository>();
    await repo.setDayActive(day.id, active);
    setState(() {
      _days = repo.getDays();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Exporta toda la configuracion y los datos a un fichero JSON.
  Future<void> _exportBackup() async {
    final repo = context.read<WorkoutRepository>();
    try {
      final data = await repo.exportData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

      // file_saver funciona igual en web (descarga), Android y escritorio.
      await FileSaver.instance.saveFile(
        name: 'plan_entrenamiento_$fecha',
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
      _snack(kIsWeb
          ? 'Copia de seguridad descargada'
          : 'Copia de seguridad guardada');
    } catch (e) {
      _snack('No se pudo exportar: $e');
    }
  }

  /// Importa una copia de seguridad desde un fichero JSON (reemplaza los datos).
  Future<void> _importBackup() async {
    final repo = context.read<WorkoutRepository>();
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Elegir copia de seguridad',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return; // cancelado
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _snack('No se pudo leer el fichero');
        return;
      }

      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importar copia'),
          content: const Text(
              'Esto REEMPLAZARA todos tus datos actuales (dias, ejercicios, '
              'series y preferencias) por los de la copia. No se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Importar')),
          ],
        ),
      );
      if (ok != true) return;

      final data = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      await repo.importData(data);
      if (!mounted) return;
      await context.read<SettingsController>().load(); // refresca tema/preferencias
      setState(() => _days = repo.getDays());
      _snack('Copia importada correctamente');
    } catch (e) {
      _snack('No se pudo importar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SectionTitle('Apariencia', icon: Icons.palette_outlined),
            const SizedBox(height: 8),
            const _ThemeModeSelector(),
            const SizedBox(height: 24),
            _SectionTitle('Dias de entrenamiento',
                icon: Icons.calendar_today_outlined),
            const SizedBox(height: 4),
            Text(
              'Marca los dias de la semana en los que entrenas. Los demas se '
              'mostraran como descanso.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                value: context.watch<SettingsController>().hideRestDays,
                onChanged: (v) =>
                    context.read<SettingsController>().setHideRestDays(v),
                title: const Text('Ocultar dias de descanso'),
                subtitle: const Text('No mostrarlos en la pantalla de inicio'),
                secondary: const Icon(Icons.visibility_off_outlined),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<WorkoutDay>>(
              future: _days,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final days = snap.data ?? [];
                return Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < days.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        SwitchListTile(
                          value: days[i].active,
                          onChanged: (v) => _toggleDay(days[i], v),
                          title: Text(days[i].name),
                          secondary: Icon(
                            days[i].active
                                ? Icons.fitness_center
                                : Icons.weekend_outlined,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionTitle('Copia de seguridad', icon: Icons.backup_outlined),
            const SizedBox(height: 4),
            Text(
              'Guarda o restaura toda tu configuracion y tu historial en un '
              'fichero. Util para no perder los datos o pasarlos a otro dispositivo.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Exportar'),
                    subtitle: const Text('Guardar copia en un fichero JSON'),
                    onTap: _exportBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Importar'),
                    subtitle: const Text('Restaurar desde un fichero (reemplaza)'),
                    onTap: _importBackup,
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

/// Selector de modo de tema: Sistema / Claro / Oscuro.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Oscuro'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) =>
                context.read<SettingsController>().setThemeMode(s.first),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }
}
