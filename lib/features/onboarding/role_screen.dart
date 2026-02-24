import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_provider.dart';

class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Which option best describes you?')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
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
              child: const Text('Both'),
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
