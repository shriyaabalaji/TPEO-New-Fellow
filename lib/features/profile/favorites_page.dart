import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import '../find/mock_providers.dart';
import 'provider_account_controller.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Favorites'),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Sign in to see your favorites.'));
          }
          if (appUser.isDemo) {
            return _buildGrid(context, ref, _mockAsList(), null, null);
          }
          if (fs == null) {
            return const Center(child: Text('Firebase not configured.'));
          }
          return StreamBuilder(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final favoriteIds = userSnap.data?.favoriteProviderIds ?? [];
              return StreamBuilder<List<ProviderProfile>>(
                stream: fs.streamAllProviderProfiles(),
                builder: (context, providersSnap) {
                  final all = providersSnap.data ?? [];
                  final favorites = all.where((p) => favoriteIds.contains(p.providerProfileId)).toList();
                  return _buildGrid(context, ref, favorites, appUser.uid, fs);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<ProviderProfile> _mockAsList() {
    return mockProviders
        .map((m) => ProviderProfile(
              providerProfileId: m.id,
              ownerUid: '',
              businessName: m.businessName,
              tags: m.tags,
              ratingAvg: m.rating,
              reviewCount: m.reviewCount,
            ))
        .toList();
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<ProviderProfile> providers, String? uid, dynamic fs) {
    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No favorites yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              uid != null ? 'Tap the heart on a provider to add them here.' : 'Demo: add favorites when signed in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: providers.length,
      itemBuilder: (_, i) {
        final p = providers[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/provider/${p.providerProfileId}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Container(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (uid != null && fs != null)
                        IconButton(
                          icon: const Icon(Icons.favorite),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () async {
                            try {
                              await fs.removeFavorite(uid, p.providerProfileId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
