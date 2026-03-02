import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../profile/provider_account_controller.dart';
import '../profile/view_mode_provider.dart';

class _TabItem {
  const _TabItem(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Consumer tabs: Home, Bookings, Profile. Provider can switch to consumer on Profile.
const _consumerTabs = [
  _TabItem('/find', Icons.home_outlined, Icons.home, 'Home'),
  _TabItem('/appointments', Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
  _TabItem('/profile', Icons.person_outline, Icons.person, 'Profile'),
];

/// Provider tabs: Appointments, Availability, Profile (no Find — switch to consumer for that).
const _providerTabs = [
  _TabItem('/appointments', Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments'),
  _TabItem('/profile/availability', Icons.schedule_outlined, Icons.schedule, 'Availability'),
  _TabItem('/profile', Icons.person_outline, Icons.person, 'Profile'),
];

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final providerList = ref.watch(currentUserProviderProfilesProvider).valueOrNull ?? [];
    final hasProviderProfile = providerList.isNotEmpty;
    final useProviderNav = viewingAsProvider && hasProviderProfile;

    final tabs = useProviderNav ? _providerTabs : _consumerTabs;
    final currentIndex = tabs.indexWhere((t) => loc.startsWith(t.path));
    final index = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.go(tabs[i].path),
        items: tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(loc.startsWith(t.path) ? t.selectedIcon : t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
