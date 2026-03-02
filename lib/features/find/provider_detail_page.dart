import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import 'mock_providers.dart';

class ProviderDetailPage extends ConsumerWidget {
  const ProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    if (providerId == 'me') {
      return effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return Scaffold(
              appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')),
              body: const Center(child: Text('Sign in to view your provider profile.')),
            );
          }
          if (fs == null) {
            return Scaffold(
              appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')),
              body: const Center(child: Text('Firebase not configured.')),
            );
          }
          return StreamBuilder(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final userProfile = userSnap.data;
              final activeId = userProfile?.activeProviderProfileId;
              if (activeId == null || activeId.isEmpty) {
                return Scaffold(
                  appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')),
                  body: const Center(child: Text('No provider profile yet. Create one from Profile.')),
                );
              }
              return StreamBuilder<ProviderProfile?>(
                stream: fs.streamProviderProfile(activeId),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  return _ProviderDetailBody(profile: profile, effectiveProfileId: activeId);
                },
              );
            },
          );
        },
        loading: () => Scaffold(appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')), body: const Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')), body: Center(child: Text('Error: $e'))),
      );
    }

    if (fs == null) {
      final mock = mockProviderById(providerId);
      return _ProviderDetailBody(
        profile: mock != null
            ? ProviderProfile(providerProfileId: mock.id, ownerUid: '', businessName: mock.businessName, tags: mock.tags, ratingAvg: mock.rating, reviewCount: mock.reviewCount)
            : null,
        effectiveProfileId: providerId,
      );
    }

    return StreamBuilder<ProviderProfile?>(
      stream: fs.streamProviderProfile(providerId),
      builder: (context, snap) {
        final profile = snap.data;
        if (snap.connectionState == ConnectionState.waiting && profile == null) {
          return Scaffold(appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')), body: const Center(child: CircularProgressIndicator()));
        }
        if (profile == null && !snap.hasData) {
          final mock = mockProviderById(providerId);
          return _ProviderDetailBody(
            profile: mock != null
                ? ProviderProfile(providerProfileId: mock.id, ownerUid: '', businessName: mock.businessName, tags: mock.tags, ratingAvg: mock.rating, reviewCount: mock.reviewCount)
                : null,
            effectiveProfileId: providerId,
          );
        }
        return _ProviderDetailBody(profile: profile, effectiveProfileId: providerId);
      },
    );
  }
}

class _ProviderDetailBody extends ConsumerWidget {
  const _ProviderDetailBody({required this.profile, required this.effectiveProfileId});

  final ProviderProfile? profile;
  final String effectiveProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')), title: const Text('Provider')),
        body: const Center(child: Text('Provider not found')),
      );
    }
    final p = profile!;
    final name = p.businessName;
    final rating = p.ratingAvg;
    final reviewCount = p.reviewCount;
    final tags = p.tags;
    final fs = ref.watch(firestoreServiceProvider);
    final ownerUid = p.ownerUid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/find')),
        title: const Text('Provider'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Builder(
                builder: (context) {
                  final url = p.bannerUrl?.isNotEmpty == true
                      ? p.bannerUrl!
                      : (p.galleryUrls?.isNotEmpty == true ? p.galleryUrls!.first : null);
                  if (url == null) return Container(color: Colors.grey.shade300);
                  return GestureDetector(
                    onTap: () => _showImageLightbox(context, url),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ProviderAvatar(ownerUid: ownerUid),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text('Austin, TX', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: tags.map((t) => Chip(label: Text(t), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.zero)).toList(),
                        ),
                      ],
                    ),
                  ),
                  _FavoriteButton(providerProfileId: effectiveProfileId),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/booking?providerId=$effectiveProfileId'),
                  child: const Text('Book Now'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.star, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('$rating ($reviewCount reviews)', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 12),
                  ...['\$', '\$\$', '\$\$\$'].map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero),
                          onPressed: () {},
                          child: Text(p),
                        ),
                      )),
                ],
              ),
            ),
            if (p.galleryUrls != null && p.galleryUrls!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Gallery', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: p.galleryUrls!.length,
                  itemBuilder: (_, i) {
                    final url = p.galleryUrls![i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () => _showImageLightbox(_, url),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reviews', style: Theme.of(context).textTheme.titleSmall),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ),
            const ListTile(title: Text('Great service!'), subtitle: Text('Would book again.')),
            const ListTile(title: Text('On time and professional'), subtitle: Text('Highly recommend.')),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('About', style: Theme.of(context).textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                p.about != null && p.about!.isNotEmpty
                    ? p.about!
                    : 'Quality service for UT students. Book a slot that works for you.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Services offered', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            fs == null
                ? _buildServicesList(context, effectiveProfileId, null)
                : StreamBuilder<List<Service>>(
                    stream: fs.streamServices(effectiveProfileId),
                    builder: (context, snap) => _buildServicesList(context, effectiveProfileId, snap.data),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList(BuildContext context, String providerId, List<Service>? services) {
    if (services != null && services.isNotEmpty) {
      return Column(
        children: services.map((s) {
          final dur = s.durationMinutes >= 60 ? '${s.durationMinutes ~/ 60} hr' : '${s.durationMinutes} min';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(s.name),
                subtitle: Text('${s.price} · $dur'),
                onTap: () {
                  final uri = Uri(
                    path: '/booking',
                    queryParameters: {
                      'providerId': providerId,
                      'serviceId': s.serviceId,
                      'serviceName': s.name,
                      'price': s.price,
                    },
                  );
                  context.push(uri.toString());
                },
              ),
            ),
          );
        }).toList(),
      );
    }
    final mock = mockServicesByProvider[providerId] ?? [const MockService('Service', r'$20', '1 hr')];
    return Column(
      children: mock.map((s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(s.name),
                subtitle: Text('${s.price} · ${s.duration}'),
                onTap: () => context.push('/booking?providerId=$providerId'),
              ),
            ),
          )).toList(),
    );
  }
}

class _ProviderAvatar extends ConsumerWidget {
  const _ProviderAvatar({required this.ownerUid});

  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    if (fs == null || ownerUid.isEmpty) {
      return const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28));
    }

    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(ownerUid),
      builder: (context, snap) {
        final photoUrl = snap.data?.photoUrl;
        return CircleAvatar(
          radius: 28,
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 28) : null,
        );
      },
    );
  }
}

void _showImageLightbox(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.providerProfileId});

  final String providerProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(effectiveUserProvider).valueOrNull;
    final fs = ref.watch(firestoreServiceProvider);
    if (appUser == null || appUser.isDemo || fs == null) {
      return IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {});
    }
    return StreamBuilder(
      stream: fs.streamUserProfile(appUser.uid),
      builder: (context, snap) {
        final favoriteIds = snap.data?.favoriteProviderIds ?? [];
        final isFav = favoriteIds.contains(providerProfileId);
        return IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
          onPressed: () async {
            try {
              if (isFav) {
                await fs.removeFavorite(appUser.uid, providerProfileId);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
              } else {
                await fs.addFavorite(appUser.uid, providerProfileId);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites')));
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          },
        );
      },
    );
  }
}
