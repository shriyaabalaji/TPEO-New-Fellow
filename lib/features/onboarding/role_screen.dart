import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_progress.dart';
import 'onboarding_provider.dart';

class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  static const int stepIndex = 0;
  static const int totalSteps = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting Started'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
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
              'Which option best describes you?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            _RoleButton(
              label: 'Service Provider',
              onTap: () {
                ref.read(onboardingRoleProvider.notifier).state = 'provider';
                context.go('/onboarding/name');
              },
            ),
            const SizedBox(height: 16),
            _RoleButton(
              label: 'Customer',
              onTap: () {
                ref.read(onboardingRoleProvider.notifier).state = 'customer';
                context.go('/onboarding/name');
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ref.read(onboardingRoleProvider.notifier).state = 'both';
                context.go('/onboarding/name');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        child: Text(label),
      ),
    );
  }
}
