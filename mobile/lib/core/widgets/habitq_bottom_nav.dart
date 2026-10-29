import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'bounce_in.dart';

enum HabitQTab { home, activity, stats, chat, profile }

/// Bottom navigation (Inicio / Actividad / Estadísticas / Chat / Perfil) with the lilac
/// active pill (from `NavigationBarTheme.indicatorColor`).
class HabitQBottomNav extends StatelessWidget {
  const HabitQBottomNav({super.key, required this.current, required this.onSelected});

  final HabitQTab current;
  final ValueChanged<HabitQTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFCECECE))),
      ),
      child: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (index) => onSelected(HabitQTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.home_rounded),
            selectedIcon: BounceIn(child: Icon(Symbols.home_rounded, fill: 1)),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Symbols.task_alt_rounded),
            selectedIcon: BounceIn(child: Icon(Symbols.task_alt_rounded, fill: 1)),
            label: 'Actividad',
          ),
          NavigationDestination(
            icon: Icon(Symbols.bar_chart_rounded),
            selectedIcon: BounceIn(child: Icon(Symbols.bar_chart_rounded, fill: 1)),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Symbols.insights_rounded),
            selectedIcon: BounceIn(child: Icon(Symbols.insights_rounded, fill: 1)),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Symbols.explore_rounded),
            selectedIcon: BounceIn(child: Icon(Symbols.explore_rounded, fill: 1)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
