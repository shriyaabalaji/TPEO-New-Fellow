import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import '../find/mock_providers.dart';
import 'provider_account_controller.dart';
import '../../core/firestore/firestore_service.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const Text(
          'Saved Services',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Sign in to see your saved services.'));
          }
          if (appUser.isDemo) {
            return _SavedGrid(providers: _mockAsList(), uid: null, fs: null);
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
                  return _SavedGrid(providers: favorites, uid: appUser.uid, fs: fs);
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
}

class _SavedGrid extends StatelessWidget {
  const _SavedGrid({
    required this.providers,
    required this.uid,
    required this.fs,
  });

  final List<ProviderProfile> providers;
  final String? uid;
  final FirestoreService? fs;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No saved services yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on a provider to save them here.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            '${providers.length} Saved',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            itemCount: providers.length,
            itemBuilder: (_, i) => _SavedCard(
              provider: providers[i],
              uid: uid,
              fs: fs,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.provider,
    required this.uid,
    required this.fs,
  });

  final ProviderProfile provider;
  final String? uid;
  final FirestoreService? fs;

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.bannerUrl ??
        (provider.galleryUrls != null && provider.galleryUrls!.isNotEmpty
            ? provider.galleryUrls!.first
            : null);

    return GestureDetector(
      onTap: () => context.push('/provider/${provider.providerProfileId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with heart overlay
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey[200]),
                          )
                        : Container(color: Colors.grey[200]),
                  ),
                ),
                if (uid != null && fs != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await fs!.removeFavorite(uid!, provider.providerProfileId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Removed from saved')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, size: 18, color: Colors.black87),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.businessName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.black87),
              const SizedBox(width: 3),
              Text(
                '${provider.ratingAvg.toStringAsFixed(1)} (${provider.reviewCount})',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Prices Vary',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
