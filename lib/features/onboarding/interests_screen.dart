import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/tag_options.dart';
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleBackButton(
                  onPressed: () => context.go('/onboarding/photo')),
              const SizedBox(height: 24),
              const _OnboardingHeader(),
              const SizedBox(height: 24),
              OnboardingStepHeader(
                currentStep: stepIndex,
                totalSteps: totalSteps,
              ),
              const SizedBox(height: 28),
              Text(
                'Which Services Spark Your Interest?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will help you discover more relevant services. Choose all that apply.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _TagGrid(
                    tags: tagOptions,
                    selected: selected,
                    onToggle: (tag) {
                      final list = List<String>.from(
                          ref.read(onboardingInterestsProvider));
                      if (list.contains(tag)) {
                        list.remove(tag);
                      } else {
                        list.add(tag);
                      }
                      ref.read(onboardingInterestsProvider.notifier).state =
                          list;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ContinueButton(
                onPressed: () async {
                  final uid =
                      ref.read(authStateProvider).valueOrNull?.uid;
                  final fs = ref.read(firestoreServiceProvider);
                  final auth = ref.read(authServiceProvider);
                  if (uid != null && fs != null) {
                    await auth?.reloadUserAndRefreshToken();
                    final first =
                        ref.read(onboardingFirstNameProvider).trim();
                    final last =
                        ref.read(onboardingLastNameProvider).trim();
                    final displayName = '$first $last'.trim();
                    final username =
                        ref.read(onboardingUsernameProvider).trim();
                    final role = ref.read(onboardingRoleProvider);
                    try {
                      await fs.updateUserProfile(
                        uid: uid,
                        displayName:
                            displayName.isNotEmpty ? displayName : null,
                        username:
                            username.isNotEmpty ? username : null,
                        onboardingRole: role,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        final msg = e
                                    .toString()
                                    .toLowerCase()
                                    .contains('permission') ||
                                e
                                    .toString()
                                    .contains('PERMISSION_DENIED')
                            ? 'Permission denied. Make sure your email is verified and you\'re signed in with @utexas.edu. Try signing out and back in.'
                            : 'Failed to save profile: $e';
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      }
                      return;
                    }
                  }
                  await setOnboardingDone();
                  if (!context.mounted) return;
                  final role = ref.read(onboardingRoleProvider);
                  if ((role == 'provider' || role == 'both') &&
                      uid != null &&
                      fs != null) {
                    final profiles =
                        await fs.streamProviderProfilesByOwner(uid).first;
                    if (profiles.isEmpty) {
                      context.go('/profile/business-setup');
                      return;
                    }
                  }
                  context.go('/find');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagGrid extends StatelessWidget {
  const _TagGrid({
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<String> tags;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        final isSelected = selected.contains(tag);
        return GestureDetector(
          onTap: () => onToggle(tag),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.black : const Color(0xFFD0D0D0),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Getting Started',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer Profile',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.black : const Color(0xFFB0B0B0),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.white70,
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: enabled ? Colors.white : Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
