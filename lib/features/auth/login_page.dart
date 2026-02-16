import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/ut_email_gate.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../profile/profile_page.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final authState = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Connect')),
      body: authState.when(
        data: (user) {
          if (user != null) {
            // basic gate: ensure email verified & UT domain
            final email = user.email;
            if (!(user.emailVerified && isUtEmail(email))) {
              // sign out and show error
              auth.signOut();
              return Center(child: Text('You must sign in with a verified @utexas.edu account.'));
            }
            // navigate to profile
            Future.microtask(() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfilePage())));
            return const SizedBox.shrink();
          }
          return Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
              onPressed: () async {
                try {
                  final cred = await auth.signInWithGoogle();
                  if (cred == null) return;
                  final fbUser = cred.user;
                  if (fbUser == null) return;
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
                }
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Auth error: $e')),
      ),
    );
  }
}
