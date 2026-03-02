import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/tag_options.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/provider_profile.dart';
import '../../models/user_profile.dart';
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
          return _buildProfileBody(context, ref, appUser, null, [], false);
        }
        if (fs == null) {
          return _buildProfileBody(context, ref, appUser, null, [], false);
        }
        return StreamBuilder<UserProfile>(
          stream: fs.streamUserProfile(appUser.uid),
          builder: (context, userSnap) {
            final userProfile = userSnap.data;
            return StreamBuilder<List<ProviderProfile>>(
              stream: fs.streamProviderProfilesByOwner(appUser.uid),
              builder: (context, providerSnap) {
                final providerList = providerSnap.data ?? [];
                final hasProviderProfile = providerList.isNotEmpty;
                final role = userProfile?.onboardingRole;
                final defaultToProvider = (role == 'provider' || role == 'both') && !hasProviderProfile;
                if (defaultToProvider && !ref.read(viewingAsProviderProvider)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(viewingAsProviderProvider.notifier).state = true;
                  });
                }
                return _buildProfileBody(context, ref, appUser, userProfile, providerList, hasProviderProfile);
              },
            );
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
    UserProfile? userProfile,
    List<ProviderProfile> providerList,
    bool hasProviderProfile,
  ) {
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final displayName = userProfile?.displayName ?? user.displayName;
    final photoUrl = userProfile?.photoUrl ?? user.photoUrl;
    final nameForAvatar = displayName.isNotEmpty ? displayName : '?';
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
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            nameForAvatar.substring(0, 1).toUpperCase(),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName.isNotEmpty ? displayName : 'Name',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (viewingAsProvider) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        const Text('5.0 (170 reviews)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
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
            Text('My Account', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ListTile(
              title: const Text('Account Details'),
              trailing: const Icon(Icons.chevron_right, size: 22),
              onTap: () => context.push('/profile/account'),
            ),
            ListTile(
              title: const Text('Favorites'),
              trailing: const Icon(Icons.chevron_right, size: 22),
              onTap: () => context.push('/profile/favorites'),
            ),
            ListTile(
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right, size: 22),
              onTap: () => context.push('/profile/notifications'),
            ),
            if (viewingAsProvider) ...[
              const SizedBox(height: 16),
              Text('Service Provider Details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ListTile(
                title: const Text('My Services'),
                trailing: const Icon(Icons.chevron_right, size: 22),
                onTap: () => context.push('/profile/my-services'),
              ),
              ListTile(
                title: const Text('Public Profile'),
                trailing: const Icon(Icons.chevron_right, size: 22),
                onTap: () => context.push('/profile/public'),
              ),
              ListTile(
                title: const Text('Availability'),
                trailing: const Icon(Icons.chevron_right, size: 22),
                onTap: () => context.push('/profile/availability'),
              ),
            ],
            if (!viewingAsProvider && hasProviderProfile) ...[
              const SizedBox(height: 16),
              Text('Profile View', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ListTile(
                title: const Text('Start Selling'),
                trailing: const Icon(Icons.chevron_right, size: 22),
                onTap: () => ref.read(viewingAsProviderProvider.notifier).state = true,
              ),
            ],
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

  Widget _buildProviderContent(BuildContext context, WidgetRef ref, AppUser user, List<ProviderProfile> providerList, bool hasProviderProfile) {
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
                    onTap: () => _showProviderOptions(context, ref, user.uid, p, fs),
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
    final selectedTags = <String>[];
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Provider Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Business name')),
                const SizedBox(height: 16),
                Text('Categories', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tagOptions.map((tag) {
                    final isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          if (isSelected) {
                            selectedTags.remove(tag);
                          } else {
                            selectedTags.add(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'tags': List<String>.from(selectedTags)}),
              child: const Text('Create'),
            ),
          ],
        ),
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
      await ref.read(authServiceProvider)?.reloadUser();
      final name = res['name'] as String? ?? '';
      final tags = (res['tags'] as List<String>? ?? []);
      try {
        final id = await fs.createProviderProfile(ownerUid: firebaseUser.uid, businessName: name, tags: tags);
        await fs.setActiveProviderProfile(uid: firebaseUser.uid, providerProfileId: id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider created')));
          ref.read(viewingAsProviderProvider.notifier).state = true;
        }
      } catch (e) {
        if (context.mounted) {
          final msg = e.toString().toLowerCase().contains('permission') || e.toString().contains('PERMISSION_DENIED')
              ? 'Permission denied. Make sure your email is verified and you\'re signed in with @utexas.edu. Try signing out and back in.'
              : 'Create failed: $e';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    });
  }

  void _showProviderOptions(
    BuildContext context,
    WidgetRef ref,
    String uid,
    ProviderProfile p,
    FirestoreService fs,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditProviderDialog(context, ref, uid, p, fs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Set as active'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await fs.setActiveProviderProfile(uid: uid, providerProfileId: p.providerProfileId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Active profile updated')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteProvider(context, ref, uid, p, fs);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProviderDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    ProviderProfile p,
    FirestoreService fs,
  ) {
    final nameCtrl = TextEditingController(text: p.businessName);
    final selectedTags = List<String>.from(p.tags);
    String? bannerUrl = p.bannerUrl;
    List<String> galleryUrls = List<String>.from(p.galleryUrls ?? []);
    final storage = ref.read(storageServiceProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit provider'),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Business name'),
                    ),
                    const SizedBox(height: 16),
                    Text('Banner image', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    if (bannerUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(bannerUrl!, height: 80, width: double.infinity, fit: BoxFit.cover),
                      ),
                    if (bannerUrl != null) const SizedBox(height: 4),
                    if (storage != null && storage.isAvailable)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate, size: 20),
                        label: Text(bannerUrl == null ? 'Add banner' : 'Change banner'),
                        onPressed: () async {
                          final xFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (xFile == null || !ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Uploading...')));
                          try {
                            final url = await storage.uploadProviderBanner(p.providerProfileId, File(xFile.path));
                            if (url != null && ctx.mounted) {
                              setState(() => bannerUrl = url);
                              await fs.updateProviderProfile(
                                providerProfileId: p.providerProfileId,
                                ownerUid: uid,
                                bannerUrl: url,
                              );
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Banner updated')),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    Text('Gallery', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    if (galleryUrls.isNotEmpty)
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: galleryUrls.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                galleryUrls[i],
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (galleryUrls.isNotEmpty) const SizedBox(height: 4),
                    if (storage != null && storage.isAvailable)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate, size: 20),
                        label: const Text('Add gallery photo'),
                        onPressed: () async {
                          final xFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (xFile == null || !ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Uploading...')));
                          try {
                            final url = await storage.uploadProviderGalleryImage(p.providerProfileId, File(xFile.path));
                            if (url != null && ctx.mounted) {
                              setState(() => galleryUrls.add(url));
                              await fs.updateProviderProfile(
                                providerProfileId: p.providerProfileId,
                                ownerUid: uid,
                                galleryUrls: galleryUrls,
                              );
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Photo added')),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    Text('Categories', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagOptions.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              if (isSelected) {
                                selectedTags.remove(tag);
                              } else {
                                selectedTags.add(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await fs.updateProviderProfile(
                    providerProfileId: p.providerProfileId,
                    ownerUid: uid,
                    businessName: name,
                    tags: List<String>.from(selectedTags),
                    bannerUrl: bannerUrl,
                    galleryUrls: galleryUrls,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Provider updated')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteProvider(
    BuildContext context,
    WidgetRef ref,
    String uid,
    ProviderProfile p,
    FirestoreService fs,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete provider?'),
        content: Text(
          'This will remove "${p.businessName}". Services and availability for this profile will be lost. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await fs.deleteProviderProfile(
                  providerProfileId: p.providerProfileId,
                  ownerUid: uid,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Provider deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
