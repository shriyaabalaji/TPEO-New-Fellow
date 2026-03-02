import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/tag_options.dart';
import '../auth/auth_controller.dart';
import '../profile/provider_account_controller.dart';
import 'onboarding_progress.dart';
import 'onboarding_provider.dart';

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  static const int stepIndex = 2;
  static const int totalSteps = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingInterestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting Started'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/name'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: OnboardingProgressLines(currentStep: stepIndex, totalSteps: totalSteps),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Which services spark your interest?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This will help you discover more relevant services. Choose all that apply.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagOptions.map((tag) {
                final isSelected = selected.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (v) {
                    final list = List<String>.from(ref.read(onboardingInterestsProvider));
                    if (v) {
                      list.add(tag);
                    } else {
                      list.remove(tag);
                    }
                    ref.read(onboardingInterestsProvider.notifier).state = list;
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                final fs = ref.read(firestoreServiceProvider);
                final auth = ref.read(authServiceProvider);
                if (uid != null && fs != null) {
                  await auth?.reloadUserAndRefreshToken();
                  final first = ref.read(onboardingFirstNameProvider).trim();
                  final last = ref.read(onboardingLastNameProvider).trim();
                  final displayName = '$first $last'.trim();
                  final username = ref.read(onboardingUsernameProvider).trim();
                  final role = ref.read(onboardingRoleProvider);
                  try {
                    await fs.updateUserProfile(
                      uid: uid,
                      displayName: displayName.isNotEmpty ? displayName : null,
                      username: username.isNotEmpty ? username : null,
                      onboardingRole: role,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      final msg = e.toString().toLowerCase().contains('permission') || e.toString().contains('PERMISSION_DENIED')
                          ? 'Permission denied. Make sure your email is verified and you\'re signed in with @my.utexas.edu. Try signing out and back in.'
                          : 'Failed to save profile: $e';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    }
                    return;
                  }
                }
                await setOnboardingDone();
                if (context.mounted) context.go('/find');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
