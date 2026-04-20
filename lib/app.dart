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
import 'features/onboarding/photo_screen.dart';
import 'features/onboarding/interests_screen.dart';
import 'features/find/provider_detail_page.dart';
import 'features/find/provider_about_page.dart';
import 'features/booking/booking_page.dart';
import 'features/profile/availability_page.dart';
import 'features/profile/my_services_page.dart';
import 'features/profile/account_details_page.dart';
import 'features/profile/favorites_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/public_profile_page.dart';
import 'features/profile/reviews_page.dart';
import 'features/profile/business_setup_page.dart';
import 'features/profile/business_profile_page.dart';
import 'features/profile/team_members_page.dart';
import 'features/chat/chat_list_page.dart';
import 'features/chat/chat_detail_page.dart';
import 'core/notifications/appointment_reminder_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _buildShellSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 220),
  );
}

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
        path: '/onboarding/photo',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const PhotoScreen(),
      ),
      GoRoute(
        path: '/onboarding/interests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const InterestsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/find',
            pageBuilder: (_, state) => _buildShellSlidePage(
              state: state,
              child: const FindPage(),
            ),
          ),
          GoRoute(
            path: '/appointments',
            pageBuilder: (_, state) => _buildShellSlidePage(
              state: state,
              child: const AppointmentsPage(),
            ),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (_, state) => _buildShellSlidePage(
              state: state,
              child: const ChatListPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => _buildShellSlidePage(
              state: state,
              child: const ProfilePage(),
            ),
          ),
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
        path: '/provider/:id/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProviderAboutPage(providerId: id);
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
      GoRoute(
        path: '/booking/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final params = state.uri.queryParameters;
          return BookingPage(
            providerId: params['providerId'] ?? '',
            initialServiceId: params['serviceId'],
            initialServiceName: params['serviceName'],
            initialPrice: params['price'],
            editAppointmentId: params['appointmentId'],
            initialSlotLabel: params['slotLabel'],
            initialNotes: params['notes'],
          );
        },
      ),
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final chatId = state.pathParameters['chatId'] ?? '';
          return ChatDetailPage(chatId: chatId);
        },
      ),
      GoRoute(path: '/profile/availability', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const AvailabilityPage()),
      GoRoute(
        path: '/profile/my-services',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => MyServicesPage(
          initialEditServiceId: state.uri.queryParameters['serviceId'],
        ),
      ),
      GoRoute(path: '/profile/account', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const AccountDetailsPage()),
      GoRoute(path: '/profile/favorites', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const FavoritesPage()),
      GoRoute(path: '/profile/notifications', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/profile/public', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const PublicProfilePage()),
      GoRoute(path: '/profile/reviews', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const ReviewsPage()),
      GoRoute(path: '/profile/business-setup', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const BusinessSetupPage()),
      GoRoute(path: '/profile/business', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const BusinessProfilePage()),
      GoRoute(path: '/profile/team', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const TeamMembersPage()),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appointmentReminderProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: "Hook'd Up",
      theme: appTheme,
      routerConfig: router,
    );
  }
}
