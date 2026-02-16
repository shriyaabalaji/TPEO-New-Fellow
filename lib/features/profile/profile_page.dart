import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_controller.dart';
import '../../core/firestore/firestore_service.dart';
import '../../features/profile/provider_account_controller.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final fs = ref.watch(firestoreServiceProvider);
    return authState.when(
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('Not signed in')));
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${user.displayName ?? user.email}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async => ref.read(authServiceProvider).signOut(),
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) {
                      final nameCtrl = TextEditingController();
                      final tagsCtrl = TextEditingController();
                      return AlertDialog(
                        title: const Text('Create Provider Account'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Business name')),
                            TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'Tags (comma separated)')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.of(ctx).pop({'name': nameCtrl.text, 'tags': tagsCtrl.text}), child: const Text('Create')),
                        ],
                      );
                    });
                    if (res == null) return;
                    final name = res['name'] as String? ?? '';
                    final tags = (res['tags'] as String? ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    try {
                      await ref.read(firestoreServiceProvider).createProviderProfile(ownerUid: user.uid, businessName: name, tags: tags);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider created')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
                    }
                  },
                  child: const Text('Create Provider Account'),
                ),
                const SizedBox(height: 16),
                const Text('Your provider profiles:'),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<dynamic>>(
                    stream: fs.streamProviderProfilesByOwner(user.uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                      final list = snap.data ?? [];
                      if (list.isEmpty) return const Text('No provider profiles yet');
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final p = list[i];
                          return ListTile(
                            title: Text(p.businessName),
                            subtitle: Text('id: ${p.providerProfileId}'),
                            onTap: () async {
                              try {
                                await fs.setActiveProviderProfile(uid: user.uid, providerProfileId: p.providerProfileId);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active provider set')));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Set active failed: $e')));
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Auth error: $e'))),
    );
  }
}
