import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/tag_options.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import 'mock_providers.dart';

final findSearchQueryProvider = StateProvider<String>((ref) => '');
final findSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final findPriceSortProvider = StateProvider<String?>((ref) => null); // 'low' | 'high' for filter sheet

class FindPage extends ConsumerWidget {
  const FindPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    final searchQuery = ref.watch(findSearchQueryProvider);
    final selectedCategory = ref.watch(findSelectedCategoryProvider);
    final effectiveUser = ref.watch(effectiveUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: fs == null
          ? _buildBody(
              context,
              ref,
              _filterList(_mockAsList(), searchQuery, selectedCategory),
              null,
              null,
              fs,
            )
          : StreamBuilder<List<ProviderProfile>>(
              stream: fs.streamAllProviderProfiles(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                final fullList = list.isEmpty ? _mockAsList() : list;
                final filtered = _filterList(fullList, searchQuery, selectedCategory);
                final uid = effectiveUser != null && !effectiveUser.isDemo ? effectiveUser.uid : null;
                return uid != null
                    ? StreamBuilder<UserProfile?>(
                        stream: fs.streamUserProfile(uid),
                        builder: (context, userSnap) {
                          final favIds = userSnap.data?.favoriteProviderIds ?? [];
                          return _buildBody(context, ref, filtered, favIds, uid, fs);
                        },
                      )
                    : _buildBody(context, ref, filtered, null, null, fs);
              },
            ),
    );
  }

  List<ProviderProfile> _filterList(List<ProviderProfile> list, String query, String? category) {
    var out = list;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      out = out.where((p) {
        if (p.businessName.toLowerCase().contains(q)) return true;
        return p.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((p) => p.tags.any((t) => t.toLowerCase() == category.toLowerCase())).toList();
    }
    return out;
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

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<ProviderProfile> providers,
    List<String>? favoriteIds,
    String? currentUid,
    dynamic fs,
  ) {
    final selectedCategory = ref.watch(findSelectedCategoryProvider);
    final hasFilter = selectedCategory != null && selectedCategory.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar + heart
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => ref.read(findSearchQueryProvider.notifier).state = v.trim(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () => context.push('/profile/favorites'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        // Category row: "Search By Category" + horizontal chips, or selected chip + results + filter icon
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search By Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 10),
              if (!hasFilter)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tagOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = tagOptions[i];
                      return ActionChip(
                        label: Text(c),
                        onPressed: () => ref.read(findSelectedCategoryProvider.notifier).state = c,
                        backgroundColor: const Color(0xFFF5F5F5),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    },
                  ),
                )
              else
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showFilterSheet(context, ref, selectedCategory),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    Chip(
                      label: Text(selectedCategory),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => ref.read(findSelectedCategoryProvider.notifier).state = null,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${providers.length} results',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // "Top Picks for You" + grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Top Picks for You',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: providers.isEmpty
              ? Center(
                  child: Text(
                    'No providers match your search.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: providers.length,
                  itemBuilder: (_, i) {
                    final p = providers[i];
                    final isFav = favoriteIds?.contains(p.providerProfileId) ?? false;
                    return _ProviderProfileCard(
                      profile: p,
                      isFavorite: isFav,
                      onTap: () => context.push('/provider/${p.providerProfileId}'),
                      onFavoriteTap: fs != null && currentUid != null
                          ? () => _toggleFavorite(ref, fs!, currentUid, p.providerProfileId, isFav, context)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(
    WidgetRef ref,
    FirestoreService fs,
    String uid,
    String providerId,
    bool currentlyFav,
    BuildContext context,
  ) async {
    try {
      if (currentlyFav) {
        await fs.removeFavorite(uid, providerId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
        }
      } else {
        await fs.addFavorite(uid, providerId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update favorites: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}')),
        );
      }
    }
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref, String? selectedCategory) {
    final priceLow = ref.read(findPriceSortProvider) == 'low';
    final priceHigh = ref.read(findPriceSortProvider) == 'high';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filters',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              _FilterRow(label: 'Category', value: selectedCategory ?? 'Any', onTap: () => Navigator.pop(ctx)),
              const SizedBox(height: 12),
              _FilterRow(label: 'Ratings', value: 'Any', onTap: () {}),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Price: Low to High', style: TextStyle(color: Colors.white)),
                value: priceLow,
                activeColor: Theme.of(ctx).colorScheme.primary,
                onChanged: (v) => setState(() {
                  ref.read(findPriceSortProvider.notifier).state = v == true ? 'low' : null;
                }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Price: High to Low', style: TextStyle(color: Colors.white)),
                value: priceHigh,
                activeColor: Theme.of(ctx).colorScheme.primary,
                onChanged: (v) => setState(() {
                  ref.read(findPriceSortProvider.notifier).state = v == true ? 'high' : null;
                }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Filter Results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label', style: const TextStyle(color: Colors.white70)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderProfileCard extends StatelessWidget {
  const _ProviderProfileCard({
    required this.profile,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
  });

  final ProviderProfile profile;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey.shade300),
                  if (onFavoriteTap != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onFavoriteTap,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.businessName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.ratingAvg.toStringAsFixed(1)} (${profile.reviewCount})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prices vary',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
