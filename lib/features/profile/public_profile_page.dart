import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
              title: const Text('Public Profile'),
            ),
            body: const Center(child: Text('Not signed in')),
          );
        }

        if (appUser.isDemo) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
              title: const Text('Public Profile'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CircleAvatar(radius: 48)),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Demo Store',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sign in to create your own provider profile and see how customers will see you.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.go('/profile'), child: const Text('Done')),
                ],
              ),
            ),
          );
        }

        if (fs == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
              title: const Text('Public Profile'),
            ),
            body: const Center(
              child: Text('Firebase not configured. Run: flutterfire configure'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
            title: const Text('Public Profile'),
          ),
          body: StreamBuilder(
            stream: fs.streamProviderProfilesByOwner(appUser.uid),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: CircleAvatar(radius: 48)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No provider profile yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create a provider profile from your Profile tab to see how customers will see you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/profile'),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
              }

              // Use first profile as "active" for preview if we don't have activeProviderProfileId from user doc
              final profile = list.first;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: CircleAvatar(radius: 48)),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        profile.businessName,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.ratingAvg.toStringAsFixed(1)} (${profile.reviewCount} reviews)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (profile.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.tags
                            .map((t) => Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 12)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'This is how customers see your profile. Add a bio, services, and photos to stand out.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/profile'),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
          title: const Text('Public Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
          title: const Text('Public Profile'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
