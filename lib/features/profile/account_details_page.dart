import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/effective_user_provider.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              title: const Text('Account Details'),
            ),
            body: const Center(child: Text('Not signed in')),
          );
        }
        final displayName = appUser.displayName.isNotEmpty ? appUser.displayName : 'Not set';
        final email = appUser.email.isNotEmpty ? appUser.email : 'Not set';
        final username = appUser.email.contains('@')
            ? appUser.email.split('@').first
            : '—';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
            title: const Text('Account Details'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Name'),
                subtitle: Text(displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Username'),
                subtitle: Text('@$username'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Email'),
                subtitle: Text(email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          title: const Text('Account Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          title: const Text('Account Details'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
