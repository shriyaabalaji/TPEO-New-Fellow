import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../profile/provider_account_controller.dart';
import 'mock_providers.dart';

final findSearchQueryProvider = StateProvider<String>((ref) => '');
final findSelectedCategoryProvider = StateProvider<String?>((ref) => null);

class FindPage extends ConsumerWidget {
  const FindPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    final searchQuery = ref.watch(findSearchQueryProvider);
    final selectedCategory = ref.watch(findSelectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for people, items and brands',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => ref.read(findSearchQueryProvider.notifier).state = v.trim(),
            ),
          ),
        ),
      ),
      body: fs == null
          ? _buildBody(context, ref, _filterList(_mockAsList(), searchQuery, selectedCategory))
          : StreamBuilder<List<ProviderProfile>>(
              stream: fs.streamAllProviderProfiles(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                final fullList = list.isEmpty ? _mockAsList() : list;
                return _buildBody(context, ref, _filterList(fullList, searchQuery, selectedCategory));
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

  Widget _buildBody(BuildContext context, WidgetRef ref, List<ProviderProfile> providers) {
    final selectedCategory = ref.watch(findSelectedCategoryProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Search by category',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mockCategories.map((c) {
                final isSelected = selectedCategory == c;
                return FilterChip(
                  showCheckmark: true,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForCategory(c),
                        size: 20,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(c),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(findSelectedCategoryProvider.notifier).state = isSelected ? null : c;
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Top Picks for You',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          providers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No providers match your search.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: providers.length,
                  itemBuilder: (_, i) {
                    final p = providers[i];
                    return _ProviderProfileCard(
                      profile: p,
                      onTap: () => context.push('/provider/${p.providerProfileId}'),
                    );
                  },
                ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

IconData _iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'nails':
      return Icons.face_retouching_natural;
    case 'hair':
      return Icons.content_cut;
    case 'photography':
      return Icons.camera_alt;
    case 'tutoring':
      return Icons.school;
    case 'vintage':
      return Icons.checkroom;
    default:
      return Icons.category;
  }
}

class _ProviderProfileCard extends StatelessWidget {
  const _ProviderProfileCard({required this.profile, required this.onTap});

  final ProviderProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(color: Colors.grey.shade300),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                  Wrap(
                    spacing: 4,
                    children: profile.tags.take(2).map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('${profile.ratingAvg} (${profile.reviewCount})', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const Text('From —', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
