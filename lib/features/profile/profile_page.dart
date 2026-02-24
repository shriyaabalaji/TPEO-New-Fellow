import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import 'provider_account_controller.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'view_mode_provider.dart';
import '../find/mock_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final fs = ref.watch(firestoreServiceProvider);
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('Not signed in')));
        return StreamBuilder<List<dynamic>>(
          stream: fs.streamProviderProfilesByOwner(user.uid),
          builder: (context, snap) {
            final providerList = snap.data ?? [];
            final hasProviderProfile = providerList.isNotEmpty;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                actions: [
                  IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
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
                          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          child: user.photoURL == null ? Text((user.displayName ?? '?').substring(0, 1).toUpperCase()) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName ?? user.email ?? 'User', style: Theme.of(context).textTheme.titleLarge),
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
                                        _showCreateProviderDialog(context, ref, user);
                                      },
                                      child: const Text('Get started'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ref.read(viewingAsProviderProvider.notifier).state = wantProvider;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (viewingAsProvider) _buildProviderContent(context, ref, user) else _buildConsumerContent(context),
                    const SizedBox(height: 24),
                    const Divider(),
                    Text('My Account', style: Theme.of(context).textTheme.titleSmall),
                    ListTile(title: const Text('Account Details'), leading: const Icon(Icons.person_outline), onTap: () {}),
                    ListTile(title: const Text('Favorites'), leading: const Icon(Icons.favorite_border), onTap: () {}),
                    ListTile(title: const Text('Notifications'), leading: const Icon(Icons.notifications_outlined), onTap: () {}),
                    if (viewingAsProvider) ...[
                      const SizedBox(height: 16),
                      Text('Service Provider Details', style: Theme.of(context).textTheme.titleSmall),
                      ListTile(title: const Text('My Services'), leading: const Icon(Icons.list_alt), onTap: () {}),
                      ListTile(title: const Text('Public Profile'), leading: const Icon(Icons.visibility), onTap: () {}),
                      ListTile(title: const Text('Availability'), leading: const Icon(Icons.calendar_today), onTap: () {}),
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
                        await ref.read(authServiceProvider)?.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Auth error: $e'))),
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

  Widget _buildProviderContent(BuildContext context, WidgetRef ref, fb.User user) {
    final fs = ref.watch(firestoreServiceProvider);
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
        StreamBuilder<List<dynamic>>(
          stream: fs.streamProviderProfilesByOwner(user.uid),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your provider profiles', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...list.map((p) => ListTile(
                      title: Text(p.businessName),
                      subtitle: Text(p.providerProfileId),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    )),
                OutlinedButton(
                  onPressed: () => _showCreateProviderDialog(context, ref, user),
                  child: const Text('Create Provider Account'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showCreateProviderDialog(BuildContext context, WidgetRef ref, fb.User user) {
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
      final name = res['name'] as String? ?? '';
      final tags = (res['tags'] as String? ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      try {
        await ref.read(firestoreServiceProvider).createProviderProfile(ownerUid: user.uid, businessName: name, tags: tags);
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
