import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root-Tab-Shell — hält den Navigation-State pro Tab (siehe
/// docs/05-navigation-structure.md, §1: 5 Tabs, Favoriten bewusst kein
/// eigener Tab, sondern über Profil erreichbar).
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _TabDestination(
      label: 'Home',
      icon: Icons.home_rounded,
      outlineIcon: Icons.home_outlined,
    ),
    _TabDestination(
      label: 'Suche',
      icon: Icons.search_rounded,
      outlineIcon: Icons.search_outlined,
    ),
    _TabDestination(
      label: 'Karte',
      icon: Icons.map_rounded,
      outlineIcon: Icons.map_outlined,
    ),
    _TabDestination(
      label: 'Kalender',
      icon: Icons.calendar_month_rounded,
      outlineIcon: Icons.calendar_month_outlined,
    ),
    _TabDestination(
      label: 'Profil',
      icon: Icons.person_rounded,
      outlineIcon: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: Icon(_destinations[i].outlineIcon),
              selectedIcon: Icon(_destinations[i].icon),
              label: _destinations[i].label,
            ),
        ],
      ),
    );
  }
}

class _TabDestination {
  const _TabDestination({
    required this.label,
    required this.icon,
    required this.outlineIcon,
  });
  final String label;
  final IconData icon;
  final IconData outlineIcon;
}
