import 'package:flutter/material.dart';

import 'biometrics_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Contenedor principal con navegacion por pestanas, adaptativa:
/// barra inferior en movil (ancho < 600) y rail lateral en escritorio.
///
/// Cada pestana es un `Scaffold` propio (mantiene su AppBar). La pagina se
/// construye fresca al cambiar de pestana para que Inicio refleje los dias
/// activos y Objetivos recalcule el progreso al volver.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _destinations = [
    _Dest('Inicio', Icons.home_outlined, Icons.home),
    _Dest('Biometricos', Icons.monitor_heart_outlined, Icons.monitor_heart),
    _Dest('Objetivos', Icons.flag_outlined, Icons.flag),
    _Dest('Ajustes', Icons.settings_outlined, Icons.settings),
  ];

  Widget _pageFor(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const BiometricsScreen(),
        2 => const GoalsScreen(),
        _ => const SettingsScreen(),
      };

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final page = _pageFor(_index);
    final wide = MediaQuery.sizeOf(context).width >= 600;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Dest(this.label, this.icon, this.selectedIcon);
}
