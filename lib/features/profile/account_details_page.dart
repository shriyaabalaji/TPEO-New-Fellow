import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/user_profile.dart';
import '../auth/auth_controller.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
              title: const Text('Account Details'),
            ),
            body: const Center(child: Text('Not signed in')),
          );
        }
        if (appUser.isDemo || fs == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
              title: const Text('Account Details'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Name'),
                  subtitle: Text(appUser.displayName.isNotEmpty ? appUser.displayName : 'Not set'),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(appUser.email.isNotEmpty ? appUser.email : 'Not set'),
                ),
              ],
            ),
          );
        }
        return StreamBuilder<UserProfile>(
          stream: fs.streamUserProfile(appUser.uid),
          builder: (context, snap) {
            final userProfile = snap.data;
            final displayName = userProfile?.displayName ?? appUser.displayName;
            final username = userProfile?.username ?? '';
            final email = appUser.email;

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
                title: const Text('Account Details'),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    title: const Text('Name'),
                    subtitle: Text(displayName.isNotEmpty ? displayName : 'Not set'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showEditNameDialog(context, ref, appUser.uid, displayName, fs),
                  ),
                  ListTile(
                    title: const Text('Username'),
                    subtitle: Text(username.isNotEmpty ? '@$username' : 'Not set'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showEditUsernameDialog(context, ref, appUser.uid, username, fs),
                  ),
                  ListTile(
                    title: const Text('Email'),
                    subtitle: Text(email.isNotEmpty ? email : 'Not set'),
                    trailing: const Icon(Icons.lock_outline),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
          title: const Text('Account Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/profile')),
          title: const Text('Account Details'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

}

void showEditNameDialog(
  BuildContext context,
  WidgetRef ref,
  String uid,
  String currentName,
  FirestoreService fs,
) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'First and last name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              await ref.read(authServiceProvider)?.reloadUser();
              try {
                await fs.updateUserProfile(uid: uid, displayName: name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString().toLowerCase().contains('permission') || e.toString().contains('PERMISSION_DENIED')
                      ? 'Permission denied. Make sure your email is verified and you\'re signed in with @my.utexas.edu. Try signing out and back in.'
                      : 'Failed: $e';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
}

void showEditUsernameDialog(
  BuildContext context,
  WidgetRef ref,
  String uid,
  String currentUsername,
  FirestoreService fs,
) {
    final controller = TextEditingController(text: currentUsername);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Without @',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final username = controller.text.trim();
              Navigator.pop(ctx);
              await ref.read(authServiceProvider)?.reloadUser();
              try {
                await fs.updateUserProfile(uid: uid, username: username.isEmpty ? null : username);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated')));
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString().toLowerCase().contains('permission') || e.toString().contains('PERMISSION_DENIED')
                      ? 'Permission denied. Make sure your email is verified and you\'re signed in with @my.utexas.edu. Try signing out and back in.'
                      : 'Failed: $e';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
}
