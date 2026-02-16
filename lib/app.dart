import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_page.dart';
import 'features/profile/profile_page.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (ctx, state) => const LoginPage()),
        GoRoute(path: '/profile', builder: (ctx, state) => const ProfilePage()),
      ],
    );

    return MaterialApp.router(
      title: 'Campus Connect',
      theme: appTheme,
      routerConfig: _router,
    );
  }
}
