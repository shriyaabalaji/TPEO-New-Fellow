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

/// Consumer tabs: Home, Bookings, Chat, Profile.
const _consumerTabs = [
  _TabItem('/find', Icons.home_outlined, Icons.home, 'Home'),
  _TabItem('/appointments', Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
  _TabItem('/chat', Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
  _TabItem('/profile', Icons.person_outline, Icons.person, 'Profile'),
];

/// Provider tabs: Home, Bookings, Chat, Schedule, Profile.
const _providerTabs = [
  _TabItem('/find', Icons.home_outlined, Icons.home, 'Home'),
  _TabItem('/appointments', Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
  _TabItem('/chat', Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
  _TabItem('/profile/availability', Icons.schedule_outlined, Icons.schedule, 'Schedule'),
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
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final t = tabs[i];
                    final isSelected = i == index;
                    return Expanded(
                      child: InkWell(
                        onTap: () => context.go(tabs[i].path),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                loc.startsWith(t.path) ? t.selectedIcon : t.icon,
                                size: 22,
                                color: isSelected ? Colors.white : Colors.white54,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? Colors.white : Colors.white54,
                                ),
                              ),
                            ],
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
