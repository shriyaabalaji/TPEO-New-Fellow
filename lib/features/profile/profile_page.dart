import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';
import 'view_mode_provider.dart';
import '../find/mock_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) return const Scaffold(body: Center(child: Text('Not signed in')));
        if (appUser.isDemo) {
          return _buildProfileBody(context, ref, appUser, [], false);
        }
        if (fs == null) {
          return _buildProfileBody(context, ref, appUser, [], false);
        }
        return StreamBuilder<List<dynamic>>(
          stream: fs.streamProviderProfilesByOwner(appUser.uid),
          builder: (context, snap) {
            final providerList = snap.data ?? [];
            final hasProviderProfile = providerList.isNotEmpty;
            return _buildProfileBody(context, ref, appUser, providerList, hasProviderProfile);
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Auth error: $e'))),
    );
  }

  Widget _buildProfileBody(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    List<dynamic> providerList,
    bool hasProviderProfile,
  ) {
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/profile/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/profile/account'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text((user.displayName.isNotEmpty ? user.displayName : '?').substring(0, 1).toUpperCase()) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName.isNotEmpty ? user.displayName : user.email, style: Theme.of(context).textTheme.titleLarge),
                      if (viewingAsProvider) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            const Text('5.0 (170 reviews)'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('551k followers · 33 following'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('View as', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Consumer'), icon: Icon(Icons.person)),
                    ButtonSegment(value: true, label: Text('Provider'), icon: Icon(Icons.store)),
                  ],
                  selected: {viewingAsProvider},
                  onSelectionChanged: (s) {
                    final wantProvider = s.first;
                    if (wantProvider && !hasProviderProfile) {
                      if (user.isDemo) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Demo mode'),
                            content: const Text('Sign in with Google to create a provider profile and list your services.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Start listing services'),
                            content: const Text('Create a provider profile to list your services and receive bookings.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCreateProviderDialog(context, ref);
                                },
                                child: const Text('Get started'),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      ref.read(viewingAsProviderProvider.notifier).state = wantProvider;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (viewingAsProvider) _buildProviderContent(context, ref, user, providerList, hasProviderProfile) else _buildConsumerContent(context),
            const SizedBox(height: 24),
            const Divider(),
            Text('My Account', style: Theme.of(context).textTheme.titleSmall),
            ListTile(title: const Text('Account Details'), leading: const Icon(Icons.person_outline), onTap: () => context.push('/profile/account')),
            ListTile(title: const Text('Favorites'), leading: const Icon(Icons.favorite_border), onTap: () => context.push('/profile/favorites')),
            ListTile(title: const Text('Notifications'), leading: const Icon(Icons.notifications_outlined), onTap: () => context.push('/profile/notifications')),
            if (viewingAsProvider) ...[
              const SizedBox(height: 16),
              Text('Service Provider Details', style: Theme.of(context).textTheme.titleSmall),
              ListTile(title: const Text('My Services'), leading: const Icon(Icons.list_alt), onTap: () => context.push('/profile/my-services')),
              ListTile(title: const Text('Public Profile'), leading: const Icon(Icons.visibility), onTap: () => context.push('/profile/public')),
              ListTile(title: const Text('Availability'), leading: const Icon(Icons.calendar_today), onTap: () => context.push('/profile/availability')),
            ],
            if (!viewingAsProvider && hasProviderProfile)
              ListTile(
                title: const Text('Start Selling'),
                leading: const Icon(Icons.store),
                onTap: () => ref.read(viewingAsProviderProvider.notifier).state = true,
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                if (user.isDemo) {
                  await ref.read(demoModeProvider.notifier).exitDemo();
                  if (context.mounted) context.go('/login');
                } else {
                  await ref.read(authServiceProvider)?.signOut();
                  await ref.read(demoModeProvider.notifier).exitDemo();
                  if (context.mounted) context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumerContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Businesses you follow', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mockProviders.take(4).length,
            itemBuilder: (_, i) {
              final p = mockProviders.elementAt(i);
              return SizedBox(
                width: 120,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => context.push('/provider/${p.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: Container(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(p.businessName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderContent(BuildContext context, WidgetRef ref, AppUser user, List<dynamic> providerList, bool hasProviderProfile) {
    if (user.isDemo) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Sign in to create a provider profile and manage services.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      );
    }
    final fs = ref.watch(firestoreServiceProvider);
    if (fs == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Firebase not configured. Provider features unavailable.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bio / status placeholder'),
        const SizedBox(height: 8),
        Text('Pricing · Services', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => context.push('/provider/me'),
          child: const Text('Preview as customer'),
        ),
        const SizedBox(height: 16),
        if (providerList.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your provider profiles', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showCreateProviderDialog(context, ref),
                child: const Text('Create Provider Account'),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your provider profiles', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...providerList.map((p) => ListTile(
                    title: Text(p.businessName),
                    subtitle: Text(p.providerProfileId),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  )),
              OutlinedButton(
                onPressed: () => _showCreateProviderDialog(context, ref),
                child: const Text('Create Provider Account'),
              ),
            ],
          ),
      ],
    );
  }

  void _showCreateProviderDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Provider Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Business name')),
            const SizedBox(height: 12),
            TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'Tags (comma separated)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text, 'tags': tagsCtrl.text}),
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((res) async {
      if (res == null) return;
      final firebaseUser = ref.read(authStateProvider).valueOrNull;
      if (firebaseUser == null) return;
      final fs = ref.read(firestoreServiceProvider);
      if (fs == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firebase not configured. Cannot create provider.')),
          );
        }
        return;
      }
      final name = res['name'] as String? ?? '';
      final tags = (res['tags'] as String? ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      try {
        await fs.createProviderProfile(ownerUid: firebaseUser.uid, businessName: name, tags: tags);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider created')));
          ref.read(viewingAsProviderProvider.notifier).state = true;
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    });
  }
}
