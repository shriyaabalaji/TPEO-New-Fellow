import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/provider_profile.dart';
import '../../models/user_profile.dart';
import '../auth/auth_controller.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';
import 'view_mode_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) return const Scaffold(body: Center(child: Text('Not signed in')));
        if (appUser.isDemo || fs == null) {
          return _ProfileBody(user: appUser, userProfile: null, providerList: const [], hasProviderProfile: false);
        }
        return StreamBuilder<UserProfile>(
          stream: fs.streamUserProfile(appUser.uid),
          builder: (context, userSnap) {
            return StreamBuilder<List<ProviderProfile>>(
              stream: fs.streamProviderProfilesByOwner(appUser.uid),
              builder: (context, providerSnap) {
                final providerList = providerSnap.data ?? [];
                final hasProvider = providerList.isNotEmpty;
                final role = userSnap.data?.onboardingRole;
                final defaultToProvider = (role == 'provider' || role == 'both') && !hasProvider;
                if (defaultToProvider && !ref.read(viewingAsProviderProvider)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(viewingAsProviderProvider.notifier).state = true;
                  });
                }
                return _ProfileBody(
                  user: appUser,
                  userProfile: userSnap.data,
                  providerList: providerList,
                  hasProviderProfile: hasProvider,
                );
              },
            );
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.user,
    required this.userProfile,
    required this.providerList,
    required this.hasProviderProfile,
  });

  final AppUser user;
  final UserProfile? userProfile;
  final List<ProviderProfile> providerList;
  final bool hasProviderProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final displayName = userProfile?.displayName ?? user.displayName;
    final photoUrl = userProfile?.photoUrl ?? user.photoUrl;
    final shortName = _shortenName(displayName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner + avatar
            SizedBox(
              height: 220,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: const Color(0xFFF2F2F2),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              shortName.isNotEmpty ? shortName : 'Name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),

            const SizedBox(height: 16),

            // Customer / Seller toggle
            _RoleToggle(
              viewingAsProvider: viewingAsProvider,
              hasProviderProfile: hasProviderProfile,
              isDemo: user.isDemo,
              onChanged: (wantProvider) {
                if (wantProvider && !hasProviderProfile) {
                  if (user.isDemo) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Demo mode'),
                        content: const Text('Sign in to set up your business.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  } else {
                    context.push('/profile/business-setup');
                  }
                } else {
                  ref.read(viewingAsProviderProvider.notifier).state = wantProvider;
                }
              },
            ),

            const SizedBox(height: 28),

            // My Account — seller + customer share container style.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _AccountLinksBox(
                    items: viewingAsProvider
                        ? [
                            _AccountLinkItem(
                              icon: Icons.person_outline,
                              label: 'Account Details',
                              onTap: () => context.push('/profile/account'),
                            ),
                            _AccountLinkItem(
                              icon: Icons.favorite_border,
                              label: 'Edit Services',
                              onTap: () => context.push('/profile/my-services'),
                            ),
                            _AccountLinkItem(
                              icon: Icons.star_border,
                              label: 'Your Reviews',
                              onTap: () => context.push('/profile/reviews'),
                            ),
                            _AccountLinkItem(
                              icon: Icons.logout,
                              label: 'Sign out',
                              onTap: () => _signOut(context, ref),
                            ),
                          ]
                        : [
                            _AccountLinkItem(
                              icon: Icons.person_outline,
                              label: 'Account Details',
                              onTap: () => context.push('/profile/account'),
                            ),
                            _AccountLinkItem(
                              icon: Icons.favorite_border,
                              label: 'Saved Services',
                              onTap: () => context.push('/profile/favorites'),
                            ),
                            _AccountLinkItem(
                              icon: Icons.logout,
                              label: 'Sign out',
                              onTap: () => _signOut(context, ref),
                            ),
                          ],
                  ),
                ],
              ),
            ),

            // Start selling CTA (consumer view, no provider profile yet)
            if (!viewingAsProvider && !hasProviderProfile) ...[
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Text(
                      'Have a service to provide?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Become a provider and support\nyour campus community!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 240,
                      child: ElevatedButton(
                        onPressed: () {
                          if (user.isDemo) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Demo mode'),
                                content: const Text('Sign in to set up your business.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                              ),
                            );
                          } else {
                            context.push('/profile/business-setup');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F1F1),
                          foregroundColor: const Color(0xFF1A1A1A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Start selling',
                          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 30 / 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    if (user.isDemo) {
      await ref.read(demoModeProvider.notifier).exitDemo();
      if (context.mounted) context.go('/login');
      return;
    }
    await ref.read(authServiceProvider)?.signOut();
    await ref.read(demoModeProvider.notifier).exitDemo();
    if (context.mounted) context.go('/login');
  }

  String _shortenName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return fullName;
    return '${parts.first} ${parts.last[0]}.';
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({
    required this.viewingAsProvider,
    required this.hasProviderProfile,
    required this.isDemo,
    required this.onChanged,
  });

  final bool viewingAsProvider;
  final bool hasProviderProfile;
  final bool isDemo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip('Customer', !viewingAsProvider, () => onChanged(false)),
          _toggleChip('Seller', viewingAsProvider, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// One row inside a grouped account card (mock: icon, label, chevron).
class _AccountLinkItem {
  const _AccountLinkItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Rounded rectangle with thin dark border; rows separated by hairline dividers.
class _AccountLinksBox extends StatelessWidget {
  const _AccountLinksBox({required this.items});

  final List<_AccountLinkItem> items;

  static const _borderColor = Color(0xFF1A1A1A);
  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade300,
              ),
            _AccountLinkRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AccountLinkRow extends StatelessWidget {
  const _AccountLinkRow({required this.item});

  final _AccountLinkItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(item.icon, size: 22, color: Colors.black87),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
