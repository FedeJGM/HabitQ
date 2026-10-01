import 'package:flutter/material.dart';

enum HabitQTab { home, chat, profile }

/// Bottom navigation with the Figma destinations (Inicio / Chat / Perfil)
/// and the lilac active pill (from `NavigationBarTheme.indicatorColor`).
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
