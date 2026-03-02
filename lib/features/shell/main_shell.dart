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
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(48, 12, 48, 4),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final t = tabs[i];
                    final isSelected = i == index;
                    return Expanded(
                      child: InkWell(
                        onTap: () => context.go(tabs[i].path),
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                loc.startsWith(t.path) ? t.selectedIcon : t.icon,
                                size: 28,
                                color: isSelected ? const Color(0xFF2D2D2D) : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
