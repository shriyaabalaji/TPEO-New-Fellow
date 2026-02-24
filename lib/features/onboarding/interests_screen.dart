import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_provider.dart';

const _interestOptions = [
  'Nails', 'Hair', 'Photography', 'Tutoring', 'Fitness',
  'Art', 'Music', 'Tech', 'Writing', 'Design', 'Other',
];

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingInterestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting Started'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/username'),
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
              children: _interestOptions.map((tag) {
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
