import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';
import '../../core/auth/ut_email_gate.dart';
import '../../core/firebase_init.dart';
import '../onboarding/onboarding_provider.dart';
import 'effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

final _loginRedirectDoneProvider = StateProvider<bool>((ref) => false);

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final authState = ref.watch(authStateProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final redirectDone = ref.watch(_loginRedirectDoneProvider);

    ref.listen(authStateProvider, (prev, next) {
      if (next.valueOrNull == null) ref.read(_loginRedirectDoneProvider.notifier).state = false;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Hook'd Up"), backgroundColor: Colors.white),
      body: authState.when(
        data: (user) {
            if (user != null) {
            final email = user.email;
            if (!(user.emailVerified && isUtEmail(email))) {
              auth?.signOut();
              return Center(child: Text('You must sign in with a verified @utexas.edu account.'));
            }
            if (!redirectDone && onboardingDone.hasValue) {
              ref.read(_loginRedirectDoneProvider.notifier).state = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go(onboardingDone.value! ? '/find' : '/onboarding/role');
              });
            }
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Hook'd Up", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('UT-only services', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                  onPressed: () async {
                    if (!firebaseInitialized) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Firebase not configured. Run: flutterfire configure')),
                        );
                      }
                      return;
                    }
                    try {
                      final cred = await auth?.signInWithGoogle();
                      if (cred == null) return;
                      final user = cred.user;
                      if (user == null) return;
                      final fs = ref.read(firestoreServiceProvider);
                      if (fs != null) {
                        try {
                          await fs.upsertUserProfile(user);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile sync failed: $e')));
                          }
                        }
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await ref.read(demoModeProvider.notifier).enterDemo();
                    if (context.mounted) context.go('/onboarding/role');
                  },
                  child: const Text('Skip (demo)'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Auth error: $e')),
      ),
    );
  }
}
