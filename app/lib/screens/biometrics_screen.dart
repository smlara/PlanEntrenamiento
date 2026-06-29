import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../settings_controller.dart';

/// Pestana de datos biometricos: peso actual, altura e IMC calculado.
/// Los valores se persisten en `settings` via [SettingsController].
class BiometricsScreen extends StatefulWidget {
  const BiometricsScreen({super.key});

  @override
  State<BiometricsScreen> createState() => _BiometricsScreenState();
}

class _BiometricsScreenState extends State<BiometricsScreen> {
  late final TextEditingController _weight;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    _weight = TextEditingController(
        text: s.weightKg != null ? _fmt(s.weightKg!) : '');
    _height = TextEditingController(
        text: s.heightCm != null ? _fmt(s.heightCm!) : '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  double? _parse(String t) {
    final s = t.trim().replaceAll(',', '.');
    return s.isEmpty ? null : double.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final controller = context.read<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Datos biometricos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Peso actual',
              suffixText: 'kg',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
            onChanged: (v) => controller.setWeightKg(_parse(v)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Altura',
              suffixText: 'cm',
              prefixIcon: Icon(Icons.height),
            ),
            onChanged: (v) => controller.setHeightCm(_parse(v)),
          ),
          const SizedBox(height: 24),
          _BmiCard(bmi: settings.bmi),
        ],
      ),
    );
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.bmi});
  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bmi == null) {
      return Card(
        color: scheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.calculate_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text('Introduce peso y altura para calcular tu IMC.'),
              ),
            ],
          ),
        ),
      );
    }
    final (label, color) = _classify(bmi!, scheme);
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMC',
                    style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(bmi!.toStringAsFixed(1),
                    style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 32,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Clasificacion estandar del IMC (OMS).
  (String, Color) _classify(double bmi, ColorScheme scheme) {
    if (bmi < 18.5) return ('Bajo peso', Colors.orange.shade700);
    if (bmi < 25) return ('Normal', Colors.green.shade600);
    if (bmi < 30) return ('Sobrepeso', Colors.orange.shade800);
    return ('Obesidad', scheme.error);
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}
