import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/ui/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/main_shell.dart';
import 'features/find/find_page.dart';
import 'features/appointments/appointments_page.dart';
import 'features/profile/profile_page.dart';
import 'features/onboarding/role_screen.dart';
import 'features/onboarding/name_screen.dart';
import 'features/onboarding/username_screen.dart';
import 'features/onboarding/interests_screen.dart';
import 'features/find/provider_detail_page.dart';
import 'features/booking/booking_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/onboarding/role',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const RoleScreen(),
      ),
      GoRoute(
        path: '/onboarding/name',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NameScreen(),
      ),
      GoRoute(
        path: '/onboarding/username',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const UsernameScreen(),
      ),
      GoRoute(
        path: '/onboarding/interests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const InterestsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/find', builder: (_, __) => const FindPage()),
          GoRoute(path: '/appointments', builder: (_, __) => const AppointmentsPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/provider/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProviderDetailPage(providerId: id);
        },
      ),
      GoRoute(
        path: '/booking',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final id = state.uri.queryParameters['providerId'] ?? '';
          return BookingPage(providerId: id);
        },
      ),
    ],
  );

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'UTServe',
      theme: appTheme,
      routerConfig: _router,
    );
  }
}
