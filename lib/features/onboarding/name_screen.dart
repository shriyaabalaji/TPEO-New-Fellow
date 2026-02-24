import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_provider.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting Started'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/role'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              "What's your name?",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _first,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _last,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ref.read(onboardingFirstNameProvider.notifier).state = _first.text.trim();
                ref.read(onboardingLastNameProvider.notifier).state = _last.text.trim();
                context.go('/onboarding/username');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
