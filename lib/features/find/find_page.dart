import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/tag_options.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import '../profile/view_mode_provider.dart';
import '../shell/bottom_nav_visibility_provider.dart';
import 'mock_providers.dart';

// ---------------------------------------------------------------------------
// State providers
// ---------------------------------------------------------------------------
final findSearchQueryProvider = StateProvider<String>((ref) => '');
final findSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final findPriceSortProvider = StateProvider<String?>((ref) => null);
final findMinRatingProvider = StateProvider<double?>((ref) => null);
final findShowFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// FindPage
// ---------------------------------------------------------------------------
class FindPage extends ConsumerWidget {
  const FindPage({super.key});

  bool _hasActiveFilters(WidgetRef ref) {
    return ref.watch(findSelectedCategoryProvider) != null ||
        ref.watch(findPriceSortProvider) != null ||
        ref.watch(findMinRatingProvider) != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    final searchQuery = ref.watch(findSearchQueryProvider);
    final selectedCategory = ref.watch(findSelectedCategoryProvider);
    final effectiveUser = ref.watch(effectiveUserProvider).valueOrNull;
    final minRating = ref.watch(findMinRatingProvider);
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final providerList = ref.watch(currentUserProviderProfilesProvider).valueOrNull ?? [];
    final useProviderHome = viewingAsProvider && providerList.isNotEmpty;

    if (useProviderHome) {
      return _ProviderHomeBody(
        fs: fs,
        effectiveUser: effectiveUser,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: fs == null
          ? _buildBody(
              context,
              ref,
              _applyServiceFilters(
                  _mockServicesAsList(), searchQuery, selectedCategory, minRating),
              null,
              null,
              fs,
            )
          : StreamBuilder<List<ProviderProfile>>(
              stream: fs.streamAllProviderProfiles(),
              builder: (context, provSnap) {
                return StreamBuilder<List<Service>>(
                  stream: fs.streamAllServices(),
                  builder: (context, snap) {
                    final raw = snap.data ?? [];
                    final providerById = {
                      for (final p in (provSnap.data ?? []))
                        p.providerProfileId: p
                    };
                    final joined = raw.map((s) {
                      final p = providerById[s.providerProfileId];
                      return p != null
                          ? s.withProvider(
                              businessName: p.businessName,
                              tags: p.tags)
                          : s;
                    }).toList();
                    final fullList = joined.isEmpty ? _mockServicesAsList() : joined;
                    final filtered = _applyServiceFilters(
                        fullList, searchQuery, selectedCategory, minRating);
                    final uid = effectiveUser != null && !effectiveUser.isDemo
                        ? effectiveUser.uid
                        : null;
                    return uid != null
                        ? StreamBuilder<UserProfile?>(
                            stream: fs.streamUserProfile(uid),
                            builder: (context, userSnap) {
                              final favIds =
                                  userSnap.data?.favoriteProviderIds ?? [];
                              final showFavOnly =
                                  ref.watch(findShowFavoritesOnlyProvider);
                              final results = showFavOnly
                                  ? filtered
                                      .where((s) => favIds
                                          .contains(s.providerProfileId))
                                      .toList()
                                  : filtered;
                              return _buildBody(
                                  context, ref, results, favIds, uid, fs);
                            },
                          )
                        : _buildBody(context, ref, filtered, null, null, fs);
                  },
                );
              },
            ),
    );
  }

  List<Service> _applyServiceFilters(List<Service> list, String query,
      String? category, double? minRating) {
    var out = list;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      out = out.where((s) {
        if (s.name.toLowerCase().contains(q)) return true;
        if (s.businessName != null &&
            s.businessName!.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }
    if (category != null && category.isNotEmpty) {
      final cat = category.toLowerCase();
      out = out
          .where((s) =>
              s.providerTags.any((t) => t.toLowerCase() == cat))
          .toList();
    }
    if (minRating != null) {
      out = out.where((s) => s.ratingAvg >= minRating).toList();
    }
    return out;
  }

  List<Service> _mockServicesAsList() {
    final services = <Service>[];
    mockServicesByProvider.forEach((providerId, mockServices) {
      final provider = mockProviderById(providerId);
      for (var i = 0; i < mockServices.length; i++) {
        final ms = mockServices[i];
        final mp = mockProviders.firstWhere(
          (p) => p.id == providerId,
          orElse: () => const MockProvider(id: '', businessName: '', tags: []),
        );
        services.add(Service(
          serviceId: '${providerId}_$i',
          providerProfileId: providerId,
          name: ms.name,
          price: ms.price,
          durationMinutes: 60,
          ratingAvg: mp.rating,
          reviewCount: mp.reviewCount,
          businessName: provider?.businessName,
          providerTags: provider?.tags ?? [],
        ));
      }
    });
    return services;
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Service> services,
    List<String>? favoriteIds,
    String? currentUid,
    dynamic fs,
  ) {
    final showFavoritesOnly = ref.watch(findShowFavoritesOnlyProvider);
    final hasFilters = _hasActiveFilters(ref);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Top bar: [back?] search + heart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (hasFilters) ...[
                  _CircleButton(
                    icon: Icons.arrow_back,
                    onTap: () {
                      ref.read(findSelectedCategoryProvider.notifier).state =
                          null;
                      ref.read(findPriceSortProvider.notifier).state = null;
                      ref.read(findMinRatingProvider.notifier).state = null;
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: const Color(0xFFD0D0D0), width: 1),
                    ),
                    child: TextField(
                      onChanged: (v) => ref
                          .read(findSearchQueryProvider.notifier)
                          .state = v.trim(),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle:
                            TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
                        prefixIcon: Icon(Icons.search,
                            size: 20, color: Color(0xFF9E9E9E)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        filled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _CircleButton(
                  icon: showFavoritesOnly
                      ? Icons.favorite
                      : Icons.favorite_border,
                  iconColor: showFavoritesOnly ? Colors.red : Colors.black,
                  onTap: () {
                    if (currentUid != null) {
                      ref
                          .read(findShowFavoritesOnlyProvider.notifier)
                          .state = !showFavoritesOnly;
                    } else {
                      context.push('/profile/favorites');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filtered mode: filter icon + chips + results count
          // Unfiltered mode: "Search By Category" + chips + "Top Picks for You"
          if (hasFilters) ...[
            _FilterChipsBar(
              ref: ref,
              resultCount: services.length,
              onOpenFilters: () => _showFilterSheet(context, ref),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Search By Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: tagOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tag = tagOptions[i];
                  return GestureDetector(
                    onTap: () {
                      ref.read(findSelectedCategoryProvider.notifier).state =
                          tag;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Top Picks for You',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Grid
          Expanded(
            child: services.isEmpty
                ? Center(
                    child: Text(
                      showFavoritesOnly
                          ? 'No favorited services. Tap the heart to show all.'
                          : 'No services match your search.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.black54),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: services.length,
                    itemBuilder: (_, i) {
                      final s = services[i];
                      final isFav =
                          favoriteIds?.contains(s.providerProfileId) ?? false;
                      return _ServiceCard(
                        service: s,
                        isFavorite: isFav,
                        onTap: () =>
                            context.push('/provider/${s.providerProfileId}'),
                        onFavoriteTap: fs != null && currentUid != null
                            ? () => _toggleFavorite(ref, fs!, currentUid,
                                s.providerProfileId, isFav, context)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
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
      } else {
        await fs.addFavorite(uid, providerId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Could not update favorites: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}')),
        );
      }
    }
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) async {
    ref.read(bottomNavVisibleProvider.notifier).state = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _FilterSheet(ref: ref),
      );
    } finally {
      ref.read(bottomNavVisibleProvider.notifier).state = true;
    }
  }
}

class _ProviderHomeBody extends ConsumerWidget {
  const _ProviderHomeBody({
    required this.fs,
    required this.effectiveUser,
  });

  final FirestoreService? fs;
  final AppUser? effectiveUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (effectiveUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Sign in to view your services.')),
      );
    }

    if (fs == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Firebase not configured.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: fs!.streamUserProfile(effectiveUser!.uid),
          builder: (context, userSnap) {
            final activeId = userSnap.data?.activeProviderProfileId;
            if (activeId == null || activeId.isEmpty) {
              return const Center(
                child: Text('Create a provider profile from Profile first.'),
              );
            }

            return StreamBuilder<List<Service>>(
              stream: fs!.streamServices(activeId),
              builder: (context, serviceSnap) {
                final services = serviceSnap.data ?? [];
                final displayName =
                    (userSnap.data?.displayName ?? effectiveUser!.displayName).trim();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    _ProviderGreetingHeader(
                      user: effectiveUser!,
                      greetingName: _firstNameFromDisplayName(displayName),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'Your Services',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/profile/my-services'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Service'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFCECECE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (services.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'No services yet. Tap Add Service to create your first service.',
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.73,
                        ),
                        itemCount: services.length,
                        itemBuilder: (_, i) => _ProviderServiceCard(
                          service: services[i],
                          onEditTap: () => context.push(
                            '/profile/my-services?serviceId=${services[i].serviceId}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProviderGreetingHeader extends StatelessWidget {
  const _ProviderGreetingHeader({
    required this.user,
    required this.greetingName,
  });

  final AppUser user;
  final String greetingName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F3F3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE2E2E2),
            backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                ? NetworkImage(user.photoUrl!)
                : null,
            child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hello, $greetingName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String _firstNameFromDisplayName(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 'there';
  final withoutEmailSuffix = text.contains('@') ? text.split('@').first : text;
  final parts = withoutEmailSuffix.split(RegExp(r'\s+'));
  final first = parts.first.trim();
  if (first.isEmpty) return 'there';
  return first[0].toUpperCase() + first.substring(1);
}

class _ProviderServiceCard extends StatelessWidget {
  const _ProviderServiceCard({
    required this.service,
    required this.onEditTap,
  });

  final Service service;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final priceLabel = service.price.isEmpty ? 'Prices Vary' : service.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: service.bannerUrl != null && service.bannerUrl!.isNotEmpty
                    ? Image.network(
                        service.bannerUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade200),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: Colors.grey.shade500,
                        ),
                      ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: onEditTap,
                  child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit,
                      size: 16, color: Colors.white),
                ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          service.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const Row(
          children: [
            Icon(Icons.star, size: 14, color: Colors.black),
            SizedBox(width: 4),
            Text('5.0 (37)',
                style: TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          priceLabel,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Circular icon button (back / heart)
// ---------------------------------------------------------------------------
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips bar (shown when filters are active)
// ---------------------------------------------------------------------------
class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({
    required this.ref,
    required this.resultCount,
    required this.onOpenFilters,
  });
  final WidgetRef ref;
  final int resultCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(findSelectedCategoryProvider);
    final priceSort = ref.watch(findPriceSortProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onOpenFilters,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFD0D0D0), width: 1),
                  ),
                  child:
                      const Icon(Icons.tune, size: 18, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              if (category != null)
                _ActiveChip(
                  label: 'Category',
                  onTap: onOpenFilters,
                ),
              if (priceSort != null) ...[
                const SizedBox(width: 8),
                _ActiveChip(
                  label: 'Price',
                  onTap: onOpenFilters,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$resultCount results',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bottom sheet (multi-page)
// ---------------------------------------------------------------------------
enum _FilterPage { main, category, ratings }

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  _FilterPage _page = _FilterPage.main;
  late String? _category;
  late String? _priceSort;
  late double? _minRating;

  @override
  void initState() {
    super.initState();
    _category = widget.ref.read(findSelectedCategoryProvider);
    _priceSort = widget.ref.read(findPriceSortProvider);
    _minRating = widget.ref.read(findMinRatingProvider);
  }

  void _apply() {
    widget.ref.read(findSelectedCategoryProvider.notifier).state = _category;
    widget.ref.read(findPriceSortProvider.notifier).state = _priceSort;
    widget.ref.read(findMinRatingProvider.notifier).state = _minRating;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_page == _FilterPage.main) _buildMainPage(),
            if (_page == _FilterPage.category) _buildCategoryPage(),
            if (_page == _FilterPage.ratings) _buildRatingsPage(),
          ],
        ),
      ),
    );
  }

  // ---- Main filter page ----
  Widget _buildMainPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filters',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black)),
        const SizedBox(height: 20),
        _FilterRow(
          label: 'Category',
          trailing: const Icon(Icons.chevron_right,
              size: 20, color: Colors.black54),
          onTap: () => setState(() => _page = _FilterPage.category),
        ),
        const SizedBox(height: 4),
        _FilterRow(
          label: 'Ratings',
          trailing: const Icon(Icons.chevron_right,
              size: 20, color: Colors.black54),
          onTap: () => setState(() => _page = _FilterPage.ratings),
        ),
        const SizedBox(height: 4),
        _FilterRow(
          label: 'Price: Low to High',
          trailing: _RadioDot(selected: _priceSort == 'low'),
          onTap: () => setState(
              () => _priceSort = _priceSort == 'low' ? null : 'low'),
        ),
        const SizedBox(height: 4),
        _FilterRow(
          label: 'Price: High to Low',
          trailing: _RadioDot(selected: _priceSort == 'high'),
          onTap: () => setState(
              () => _priceSort = _priceSort == 'high' ? null : 'high'),
        ),
        const SizedBox(height: 24),
        _FilterResultsButton(onTap: _apply),
      ],
    );
  }

  // ---- Category sub-page ----
  Widget _buildCategoryPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _page = _FilterPage.main),
              child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
            ),
            const SizedBox(width: 12),
            const Text('Filters',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        const SizedBox(height: 16),
        ...tagOptions.map((tag) {
          final isSelected = _category == tag;
          return _FilterRow(
            label: tag,
            trailing: _CheckboxIcon(checked: isSelected),
            onTap: () => setState(
                () => _category = isSelected ? null : tag),
          );
        }),
        const SizedBox(height: 24),
        _FilterResultsButton(onTap: _apply),
      ],
    );
  }

  // ---- Ratings sub-page ----
  Widget _buildRatingsPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _page = _FilterPage.main),
              child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
            ),
            const SizedBox(width: 12),
            const Text('Filter by Ratings',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        const SizedBox(height: 16),
        _FilterRow(
          label: '4.5 ★ & Up',
          trailing: _RadioDot(selected: _minRating == 4.5),
          onTap: () => setState(
              () => _minRating = _minRating == 4.5 ? null : 4.5),
        ),
        const SizedBox(height: 4),
        _FilterRow(
          label: '4.0 ★ & Up',
          trailing: _RadioDot(selected: _minRating == 4.0),
          onTap: () => setState(
              () => _minRating = _minRating == 4.0 ? null : 4.0),
        ),
        const SizedBox(height: 4),
        _FilterRow(
          label: 'All Ratings',
          trailing: _RadioDot(selected: _minRating == null),
          onTap: () => setState(() => _minRating = null),
        ),
        const SizedBox(height: 24),
        _FilterResultsButton(onTap: _apply),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, color: Colors.black)),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFD0D0D0),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.black),
              ),
            )
          : null,
    );
  }
}

class _CheckboxIcon extends StatelessWidget {
  const _CheckboxIcon({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? Colors.black : const Color(0xFFD0D0D0),
          width: 2,
        ),
        color: checked ? Colors.black : Colors.transparent,
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _FilterResultsButton extends StatelessWidget {
  const _FilterResultsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Filter Results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service card (customer home grid)
// ---------------------------------------------------------------------------
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
  });

  final Service service;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = service.bannerUrl ??
        (service.galleryUrls?.isNotEmpty == true
            ? service.galleryUrls!.first
            : null);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: bannerUrl != null && bannerUrl.isNotEmpty
                      ? Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade200),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Icon(Icons.design_services_outlined,
                              size: 40, color: Colors.grey.shade400),
                        ),
                ),
                if (onFavoriteTap != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavorite ? Colors.red : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (service.businessName != null && service.businessName!.isNotEmpty)
            Text(
              service.businessName!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.black),
              const SizedBox(width: 4),
              Text(
                '${service.ratingAvg.toStringAsFixed(1)} (${service.reviewCount})',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const Spacer(),
              Text(
                service.price,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider card
// ---------------------------------------------------------------------------
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.profile,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
    this.fs,
  });

  final ProviderProfile profile;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final FirestoreService? fs;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = profile.bannerUrl ??
        (profile.galleryUrls?.isNotEmpty == true
            ? profile.galleryUrls!.first
            : null);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: bannerUrl != null && bannerUrl.isNotEmpty
                      ? Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade200),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Icon(Icons.store_outlined,
                              size: 40, color: Colors.grey.shade400),
                        ),
                ),
                if (onFavoriteTap != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: isFavorite ? Colors.red : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.businessName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.black),
              const SizedBox(width: 4),
              Text(
                '${profile.ratingAvg.toStringAsFixed(1)} (${profile.reviewCount})',
                style:
                    const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _PriceLabel(profile: profile, fs: fs),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.profile, this.fs});
  final ProviderProfile profile;
  final FirestoreService? fs;

  @override
  Widget build(BuildContext context) {
    if (fs == null) {
      return const Text('Prices Vary',
          style: TextStyle(fontSize: 12, color: Colors.black54));
    }
    return StreamBuilder<List<Service>>(
      stream: fs!.streamServices(profile.providerProfileId),
      builder: (context, snap) {
        final services = snap.data ?? [];
        if (services.isEmpty) {
          return const Text('Prices Vary',
              style: TextStyle(fontSize: 12, color: Colors.black54));
        }
        final prices = services
            .map((s) => _parsePrice(s.price))
            .where((p) => p != null)
            .cast<double>()
            .toList();
        if (prices.isEmpty) {
          return const Text('Prices Vary',
              style: TextStyle(fontSize: 12, color: Colors.black54));
        }
        prices.sort();
        final min = prices.first.toInt();
        final max = prices.last.toInt();
        final label = min == max ? '\$$min' : '\$$min-$max';
        return Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54));
      },
    );
  }

  double? _parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }
}
