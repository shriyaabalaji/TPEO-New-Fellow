import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/tag_options.dart';
import '../../widgets/image_lightbox.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import 'mock_providers.dart';

final findSearchQueryProvider = StateProvider<String>((ref) => '');
final findSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final findPriceSortProvider = StateProvider<String?>((ref) => null); // 'low' | 'high' for filter sheet
final findShowFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

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
                          final showFavOnly = ref.watch(findShowFavoritesOnlyProvider);
                          final list = showFavOnly
                              ? filtered.where((p) => favIds.contains(p.providerProfileId)).toList()
                              : filtered;
                          return _buildBody(context, ref, list, favIds, uid, fs);
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
    final showFavoritesOnly = ref.watch(findShowFavoritesOnlyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar + heart (top right: toggle show only favorites)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(hasFilter ? Icons.filter_list : Icons.search, size: 22),
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
                icon: Icon(showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
                onPressed: () {
                  if (currentUid != null) {
                    ref.read(findShowFavoritesOnlyProvider.notifier).state = !showFavoritesOnly;
                  } else {
                    context.push('/profile/favorites');
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                color: showFavoritesOnly ? Colors.red : null,
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
                    Builder(
                      builder: (btnContext) => IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () => _showFilterDropdown(btnContext, context, ref, selectedCategory),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
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
                    showFavoritesOnly
                        ? 'No favorited businesses. Tap the heart to show all.'
                        : 'No providers match your search.',
                    textAlign: TextAlign.center,
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

  void _showFilterDropdown(
    BuildContext buttonContext,
    BuildContext scaffoldContext,
    WidgetRef ref,
    String? selectedCategory,
  ) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenWidth = MediaQuery.sizeOf(scaffoldContext).width;
    const menuWidth = 280.0;
    final left = (screenWidth - menuWidth) / 2;
    final top = pos.dy + size.height + 8;

    showDialog<void>(
      context: scaffoldContext,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: _FilterDropdownContent(
                selectedCategory: selectedCategory,
                ref: ref,
                onDismiss: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdownContent extends StatelessWidget {
  const _FilterDropdownContent({
    required this.selectedCategory,
    required this.ref,
    required this.onDismiss,
  });

  final String? selectedCategory;
  final WidgetRef ref;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final priceLow = ref.read(findPriceSortProvider) == 'low';
    final priceHigh = ref.read(findPriceSortProvider) == 'high';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterDropdownRow(
              label: 'Category',
              value: selectedCategory ?? 'Any',
              onTap: onDismiss,
            ),
            const SizedBox(height: 12),
            _FilterDropdownRow(label: 'Ratings', value: 'Any', onTap: () {}),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text('Price: Low to High', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              value: priceLow,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() {
                ref.read(findPriceSortProvider.notifier).state = v == true ? 'low' : null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text('Price: High to Low', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              value: priceHigh,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() {
                ref.read(findPriceSortProvider.notifier).state = v == true ? 'high' : null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onDismiss,
                child: const Text('Filter Results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdownRow extends StatelessWidget {
  const _FilterDropdownRow({required this.label, required this.value, required this.onTap});

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
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
            Row(
              children: [
                Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
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

  Widget _buildCardImage(BuildContext context, ProviderProfile profile) {
    final url = profile.bannerUrl ?? (profile.galleryUrls?.isNotEmpty == true ? profile.galleryUrls!.first : null);
    if (url == null || url.isEmpty) {
      return Container(color: Colors.grey.shade300);
    }
    return GestureDetector(
      onTap: () => showImageLightbox(context, Image.network(url, fit: BoxFit.contain)),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
      ),
    );
  }

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
                  _buildCardImage(context, profile),
                  if (onFavoriteTap != null)
                    Positioned(
                      bottom: 8,
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

