import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import 'mock_providers.dart';

class ProviderAboutPage extends ConsumerWidget {
  const ProviderAboutPage({super.key, required this.providerId});
  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);

    if (fs == null) {
      final mock = mockProviderById(providerId);
      return _AboutBody(
        profile: mock != null
            ? ProviderProfile(
                providerProfileId: mock.id,
                ownerUid: '',
                businessName: mock.businessName,
                tags: mock.tags,
                ratingAvg: mock.rating,
                reviewCount: mock.reviewCount)
            : null,
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
        return _AboutBody(profile: snap.data);
      },
    );
  }
}

class _AboutBody extends ConsumerWidget {
  const _AboutBody({required this.profile});
  final ProviderProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(providerProfileId: '', ownerUid: ''),
              const Expanded(
                  child: Center(child: Text('Provider not found'))),
            ],
          ),
        ),
      );
    }

    final p = profile!;
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: back + Contact
              _TopBar(
                  providerProfileId: p.providerProfileId,
                  ownerUid: p.ownerUid),

              // Avatar, name, rating, active
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _ProviderAvatar(ownerUid: p.ownerUid, radius: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OwnerName(ownerUid: p.ownerUid),
                          const SizedBox(height: 4),
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
                          const SizedBox(height: 4),
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

              // Tags
              if (p.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      );
                    }).toList(),
                  ),
                ),

              // About Me
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: const Text('About Me',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _ExpandableText(
                  text: p.about != null && p.about!.isNotEmpty
                      ? p.about!
                      : 'Quality service for UT students.',
                  maxLines: 4,
                ),
              ),

              // Services section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: const Text('Services',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black)),
              ),
              const SizedBox(height: 12),
              fs == null
                  ? _buildMockServices(context, p)
                  : StreamBuilder<List<Service>>(
                      stream: fs.streamServices(p.providerProfileId),
                      builder: (context, snap) {
                        final services = snap.data ?? [];
                        if (services.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text('No services listed yet.',
                                style: TextStyle(color: Colors.black54)),
                          );
                        }
                        return _buildServicesGrid(
                            context, services, p);
                      },
                    ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockServices(BuildContext context, ProviderProfile p) {
    final mockServices = mockServicesByProvider[p.providerProfileId];
    if (mockServices == null || mockServices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child:
            Text('No services listed yet.', style: TextStyle(color: Colors.black54)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: mockServices.length,
        itemBuilder: (_, i) {
          final s = mockServices[i];
          return _ServiceCard(
            name: s.name,
            price: s.price,
            bannerUrl: null,
            rating: p.ratingAvg,
            reviewCount: p.reviewCount,
          );
        },
      ),
    );
  }

  Widget _buildServicesGrid(
      BuildContext context, List<Service> services, ProviderProfile p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: services.length,
        itemBuilder: (_, i) {
          final s = services[i];
          return _ServiceCard(
            name: s.name,
            price: s.price,
            bannerUrl: s.bannerUrl,
            rating: p.ratingAvg,
            reviewCount: p.reviewCount,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar with back + Contact
// ---------------------------------------------------------------------------
class _TopBar extends ConsumerWidget {
  const _TopBar(
      {required this.providerProfileId, required this.ownerUid});
  final String providerProfileId;
  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/find'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0xFFD0D0D0), width: 1),
              ),
              child: const Icon(Icons.arrow_back,
                  size: 20, color: Colors.black),
            ),
          ),
          GestureDetector(
            onTap: () => _openChat(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFD0D0D0), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text('Contact',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final appUser = ref.read(effectiveUserProvider).valueOrNull;
    final fs = ref.read(firestoreServiceProvider);
    if (appUser == null ||
        appUser.isDemo ||
        fs == null ||
        ownerUid.isEmpty) return;
    if (appUser.uid == ownerUid) return;
    try {
      final chatId = await fs.getOrCreateChat(
        consumerUid: appUser.uid,
        providerProfileId: providerProfileId,
        providerOwnerUid: ownerUid,
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
// Service card (same style as home page cards)
// ---------------------------------------------------------------------------
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.name,
    required this.price,
    required this.bannerUrl,
    required this.rating,
    required this.reviewCount,
  });

  final String name;
  final String price;
  final String? bannerUrl;
  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: bannerUrl != null && bannerUrl!.isNotEmpty
                    ? Image.network(bannerUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade200))
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image_outlined,
                            size: 36, color: Colors.grey.shade400)),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border,
                      size: 14, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.star, size: 12, color: Colors.black),
            const SizedBox(width: 3),
            Text('${rating.toStringAsFixed(1)} ($reviewCount)',
                style:
                    const TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        ),
        Text(price,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
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

class _OwnerName extends ConsumerWidget {
  const _OwnerName({required this.ownerUid});
  final String ownerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreServiceProvider);
    if (fs == null || ownerUid.isEmpty) {
      return const Text('Provider',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black));
    }
    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(ownerUid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? 'Provider';
        return Text(name,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.4),
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
