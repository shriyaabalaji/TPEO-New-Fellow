import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/ui/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/auth/auth_redirect_notifier.dart';
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
import 'features/profile/availability_page.dart';
import 'features/profile/my_services_page.dart';
import 'features/profile/account_details_page.dart';
import 'features/profile/favorites_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/public_profile_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(authRedirectNotifierProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      if (authRefresh.shouldRedirectToLogin) {
        final path = state.matchedLocation;
        if (path != '/login') return '/login';
      }
      return null;
    },
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
          return BookingPage(
            providerId: id,
            initialServiceId: state.uri.queryParameters['serviceId'],
            initialServiceName: state.uri.queryParameters['serviceName'],
            initialPrice: state.uri.queryParameters['price'],
          );
        },
      ),
      GoRoute(path: '/profile/availability', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const AvailabilityPage()),
      GoRoute(path: '/profile/my-services', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const MyServicesPage()),
      GoRoute(path: '/profile/account', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const AccountDetailsPage()),
      GoRoute(path: '/profile/favorites', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const FavoritesPage()),
      GoRoute(path: '/profile/notifications', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/profile/public', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const PublicProfilePage()),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: "Hook'd Up",
      theme: appTheme,
      routerConfig: router,
    );
  }
}
