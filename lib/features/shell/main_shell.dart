import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _TabItem {
  const _TabItem(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem('/find', Icons.home_outlined, Icons.home, 'Find'),
    _TabItem('/appointments', Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments'),
    _TabItem('/profile', Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final currentIndex = _tabs.indexWhere((t) => loc.startsWith(t.path));
    final index = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(loc.startsWith(t.path) ? t.selectedIcon : t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
