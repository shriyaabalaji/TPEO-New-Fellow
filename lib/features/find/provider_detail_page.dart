import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../models/user_profile.dart';
import '../../widgets/image_lightbox.dart';
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
          if (appUser == null || appUser.isDemo || fs == null) {
            return _emptyScaffold(context, 'Sign in to view your provider profile.');
          }
          return StreamBuilder(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final activeId = userSnap.data?.activeProviderProfileId;
              if (activeId == null || activeId.isEmpty) {
                return _emptyScaffold(context, 'No provider profile yet.');
              }
              return StreamBuilder<ProviderProfile?>(
                stream: fs.streamProviderProfile(activeId),
                builder: (context, profileSnap) {
                  if (profileSnap.data == null) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  return _DetailBody(
                      profile: profileSnap.data!,
                      effectiveProfileId: activeId);
                },
              );
            },
          );
        },
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) => _emptyScaffold(context, 'Error: $e'),
      );
    }

    if (fs == null) {
      final mock = mockProviderById(providerId);
      return _DetailBody(
        profile: mock != null
            ? ProviderProfile(
                providerProfileId: mock.id,
                ownerUid: '',
                businessName: mock.businessName,
                tags: mock.tags,
                ratingAvg: mock.rating,
                reviewCount: mock.reviewCount)
            : null,
        effectiveProfileId: providerId,
      );
    }

    return StreamBuilder<ProviderProfile?>(
      stream: fs.streamProviderProfile(providerId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null && !snap.hasData) {
          final mock = mockProviderById(providerId);
          return _DetailBody(
            profile: mock != null
                ? ProviderProfile(
                    providerProfileId: mock.id,
                    ownerUid: '',
                    businessName: mock.businessName,
                    tags: mock.tags,
                    ratingAvg: mock.rating,
                    reviewCount: mock.reviewCount)
                : null,
            effectiveProfileId: providerId,
          );
        }
        return _DetailBody(
            profile: snap.data, effectiveProfileId: providerId);
      },
    );
  }

  Widget _emptyScaffold(BuildContext context, String msg) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/find')),
              ),
            ),
            Expanded(child: Center(child: Text(msg))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail body
// ---------------------------------------------------------------------------
class _DetailBody extends ConsumerWidget {
  const _DetailBody(
      {required this.profile, required this.effectiveProfileId});

  final ProviderProfile? profile;
  final String effectiveProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/find')),
                ),
              ),
              const Expanded(
                  child: Center(child: Text('Provider not found'))),
            ],
          ),
        ),
      );
    }
    final p = profile!;
    final fs = ref.watch(firestoreServiceProvider);
    final bannerUrl = p.bannerUrl ??
        (p.galleryUrls?.isNotEmpty == true ? p.galleryUrls!.first : null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner + overlaid back/heart
            Stack(
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: bannerUrl != null && bannerUrl.isNotEmpty
                      ? GestureDetector(
                          onTap: () => showImageLightbox(context,
                              Image.network(bannerUrl, fit: BoxFit.contain)),
                          child: Image.network(bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.grey.shade200)),
                        )
                      : Container(color: Colors.grey.shade200),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/find'),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 16,
                  child: _FavoriteCircleButton(
                      providerProfileId: effectiveProfileId),
                ),
              ],
            ),

            // Provider info row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GestureDetector(
                onTap: () =>
                    context.push('/provider/$effectiveProfileId/about'),
                child: Row(
                  children: [
                    _ProviderAvatar(ownerUid: p.ownerUid, radius: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OwnerNameLabel(ownerUid: p.ownerUid),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Colors.black),
                              const SizedBox(width: 3),
                              Text(
                                '${p.ratingAvg.toStringAsFixed(1)} (${p.reviewCount})',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Row(
                            children: [
                              Icon(Icons.bolt,
                                  size: 14, color: Colors.black54),
                              SizedBox(width: 3),
                              Text('Active Today',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Business name
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                p.businessName,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black),
              ),
            ),

            // About text
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _ExpandableText(
                text: p.about != null && p.about!.isNotEmpty
                    ? p.about!
                    : 'Quality service for UT students. Book a slot that works for you.',
                maxLines: 3,
              ),
            ),

            // Book Now + Chat buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.push(
                          '/booking?providerId=$effectiveProfileId'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Book Now',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openChat(context, ref, effectiveProfileId, p.ownerUid),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD0D0D0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline,
                          size: 18, color: Colors.black),
                      label: const Text('Chat',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),

            // Pricing + Gallery (single services stream for both)
            if (fs == null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildPricingFallback(context),
              ),
            ] else
              StreamBuilder<List<Service>>(
                stream: fs.streamServices(effectiveProfileId),
                builder: (context, snap) {
                  final services = snap.data ?? [];

                  // Merge provider-level gallery + all service galleries
                  final allGalleryUrls = [
                    ...?p.galleryUrls,
                    for (final s in services) ...?s.galleryUrls,
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: _buildPricingSection(context, services),
                      ),

                      // Gallery
                      if (allGalleryUrls.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Gallery',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black)),
                              GestureDetector(
                                onTap: () {
                                  final images = allGalleryUrls
                                      .map((u) => Image.network(u,
                                          fit: BoxFit.contain))
                                      .toList();
                                  showGalleryLightbox(context,
                                      images: images, initialIndex: 0);
                                },
                                child: const Text('See All',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black54,
                                        decoration:
                                            TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            itemCount: allGalleryUrls.length,
                            itemBuilder: (_, i) {
                              final url = allGalleryUrls[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: GestureDetector(
                                    onTap: () {
                                      final images = allGalleryUrls
                                          .map((u) => Image.network(u,
                                              fit: BoxFit.contain))
                                          .toList();
                                      showGalleryLightbox(context,
                                          images: images, initialIndex: i);
                                    },
                                    child: Image.network(url,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                                width: 100,
                                                height: 100,
                                                color:
                                                    Colors.grey.shade200)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

            // Reviews
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reviews',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  GestureDetector(
                    onTap: () {},
                    child: const Text('See All',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (fs == null)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(
                  'Reviews will appear here once customers leave feedback.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              )
            else
              StreamBuilder<List<Appointment>>(
                stream: fs.streamAppointmentsByProviderProfile(effectiveProfileId),
                builder: (context, snap) {
                  final all = snap.data ?? [];
                  final reviewed = all
                      .where((a) => (a.reviewRating ?? 0) >= 1)
                      .toList()
                    ..sort((a, b) => (b.reviewedAt ?? DateTime(1970))
                        .compareTo(a.reviewedAt ?? DateTime(1970)));
                  if (reviewed.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Text(
                        'No reviews yet.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final a in reviewed.take(5))
                        _ReviewCard(
                          name: a.reviewerDisplayName ?? 'Customer',
                          date: _formatRelativeReviewDate(a.reviewedAt),
                          rating: a.reviewRating ?? 0,
                          text: (a.reviewComment ?? '').trim().isEmpty
                              ? 'Rated this booking.'
                              : a.reviewComment!.trim(),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingFallback(BuildContext context) {
    return Row(
      children: [
        const Text('Pricing',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD0D0D0)),
          ),
          child: const Text('Prices Vary',
              style: TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildPricingSection(
      BuildContext context, List<Service> services) {
    String priceLabel = 'Prices Vary';
    if (services.isNotEmpty) {
      final prices = services
          .map((s) {
            final cleaned = s.price.replaceAll(RegExp(r'[^\d.]'), '');
            return double.tryParse(cleaned);
          })
          .where((p) => p != null)
          .cast<double>()
          .toList();
      if (prices.isNotEmpty) {
        prices.sort();
        final min = prices.first.toInt();
        final max = prices.last.toInt();
        priceLabel = min == max ? '\$$min' : '\$$min-$max';
      }
    }

    final pricingDesc = services.isNotEmpty
        ? services.map((s) {
            final line = '${s.name} (${s.price})';
            if (s.reviewCount > 0) {
              return '$line · ${s.ratingAvg.toStringAsFixed(1)} (${s.reviewCount})';
            }
            return line;
          }).join(' · ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Pricing',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD0D0D0)),
              ),
              child: Text(priceLabel,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87)),
            ),
          ],
        ),
        if (pricingDesc != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: _ExpandableText(text: pricingDesc, maxLines: 3),
          ),
        ],
      ],
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref,
      String providerProfileId, String providerOwnerUid) async {
    final appUser = ref.read(effectiveUserProvider).valueOrNull;
    final fs = ref.read(firestoreServiceProvider);
    if (appUser == null || appUser.isDemo || fs == null || providerOwnerUid.isEmpty) {
      return;
    }
    if (appUser.uid == providerOwnerUid) return;
    try {
      final chatId = await fs.getOrCreateChat(
        consumerUid: appUser.uid,
        providerProfileId: providerProfileId,
        providerOwnerUid: providerOwnerUid,
      );
      if (context.mounted) context.push('/chat/$chatId');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }
}

class _FavoriteCircleButton extends ConsumerWidget {
  const _FavoriteCircleButton({required this.providerProfileId});
  final String providerProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(effectiveUserProvider).valueOrNull;
    final fs = ref.watch(firestoreServiceProvider);
    if (appUser == null || appUser.isDemo || fs == null) {
      return _CircleIconButton(
          icon: Icons.favorite_border, onTap: () {});
    }
    return StreamBuilder(
      stream: fs.streamUserProfile(appUser.uid),
      builder: (context, snap) {
        final favoriteIds = snap.data?.favoriteProviderIds ?? [];
        final isFav = favoriteIds.contains(providerProfileId);
        return GestureDetector(
          onTap: () async {
            try {
              if (isFav) {
                await fs.removeFavorite(appUser.uid, providerProfileId);
              } else {
                await fs.addFavorite(appUser.uid, providerProfileId);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4)
              ],
            ),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isFav ? Colors.red : Colors.black,
            ),
          ),
        );
      },
    );
  }
}

class _ProviderAvatar extends ConsumerWidget {
  const _ProviderAvatar({required this.ownerUid, this.radius = 28});
  final String ownerUid;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    if (fs == null || ownerUid.isEmpty) {
      return CircleAvatar(
          radius: radius, child: Icon(Icons.person, size: radius));
    }
    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(ownerUid),
      builder: (context, snap) {
        final photoUrl = snap.data?.photoUrl;
        return CircleAvatar(
          radius: radius,
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? NetworkImage(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Icon(Icons.person, size: radius)
              : null,
        );
      },
    );
  }
}

class _OwnerNameLabel extends ConsumerWidget {
  const _OwnerNameLabel({required this.ownerUid});
  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    if (fs == null || ownerUid.isEmpty) {
      return const Text('Provider',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black));
    }
    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(ownerUid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? 'Provider';
        return Text(name,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black));
      },
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text, this.maxLines = 3});
  final String text;
  final int maxLines;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(
              text: widget.text,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : widget.maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            if (isOverflowing)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded ? 'Less' : 'More',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _formatRelativeReviewDate(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.date,
    required this.rating,
    required this.text,
  });
  final String name;
  final String date;
  final int rating;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            const SizedBox(height: 4),
            Row(
              children: [
                ...List.generate(
                    rating,
                    (_) => const Icon(Icons.star,
                        size: 14, color: Colors.black)),
                const SizedBox(width: 6),
                Text(date,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 6),
            Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
