import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    Widget buildUserAvatar(String? photoUrl) {
      final normalized = (photoUrl ?? '').trim();
      final ok = normalized.startsWith('http://') || normalized.startsWith('https://');
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.grey[200],
        backgroundImage: ok ? NetworkImage(normalized) : null,
        onBackgroundImageError: ok ? (_, __) {} : null,
        child: !ok ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
      );
    }

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: buildSubpageAppBar(context, title: 'Public Profile'),
            body: const Center(child: Text('Not signed in')),
          );
        }

        if (appUser.isDemo) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: buildSubpageAppBar(context, title: 'Public Profile'),
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
            backgroundColor: Colors.white,
            appBar: buildSubpageAppBar(context, title: 'Public Profile'),
            body: const Center(
              child: Text('Firebase not configured. Run: flutterfire configure'),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: buildSubpageAppBar(context, title: 'Public Profile'),
          body: StreamBuilder<UserProfile>(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final userPhotoUrl = userSnap.data?.photoUrl ?? appUser.photoUrl;
              return StreamBuilder(
                stream: fs.streamProviderProfilesByOwner(appUser.uid),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: buildUserAvatar(userPhotoUrl)),
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
                        Center(child: buildUserAvatar(userPhotoUrl)),
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
              );
            },
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: buildSubpageAppBar(context, title: 'Public Profile'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: buildSubpageAppBar(context, title: 'Public Profile'),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
