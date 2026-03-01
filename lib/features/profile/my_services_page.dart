import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/service.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

class MyServicesPage extends ConsumerWidget {
  const MyServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('My Services'),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(child: Text('Sign in to manage your services.'));
          }
          if (fs == null) {
            return const Center(child: Text('Firebase not configured.'));
          }
          return StreamBuilder(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final userProfile = userSnap.data;
              final activeId = userProfile?.activeProviderProfileId;
              if (activeId == null || activeId.isEmpty) {
                return const Center(child: Text('Create a provider profile from Profile first.'));
              }
              return StreamBuilder<List<Service>>(
                stream: fs.streamServices(activeId),
                builder: (context, listSnap) {
                  final list = listSnap.data ?? [];
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...list.map((s) => _ServiceCard(
                            service: s,
                            providerProfileId: activeId,
                            onTap: () => _showEditServiceDialog(context, ref, activeId, s),
                          )),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _showAddServiceDialog(context, ref, activeId),
                        icon: const Icon(Icons.add),
                        label: const Text('Add service'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref, String providerProfileId) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: r'$20');
    final durationCtrl = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service name')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price (e.g. \$25)')),
            const SizedBox(height: 12),
            TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = priceCtrl.text.trim();
              final duration = int.tryParse(durationCtrl.text.trim()) ?? 30;
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final fs = ref.read(firestoreServiceProvider);
              if (fs == null) return;
              try {
                await fs.addService(providerProfileId: providerProfileId, name: name, price: price, durationMinutes: duration);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service added')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref, String providerProfileId, Service s) {
    final nameCtrl = TextEditingController(text: s.name);
    final priceCtrl = TextEditingController(text: s.price);
    final durationCtrl = TextEditingController(text: '${s.durationMinutes}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service name')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price')),
            const SizedBox(height: 12),
            TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final fs = ref.read(firestoreServiceProvider);
              if (fs == null) return;
              try {
                await fs.deleteService(providerProfileId: providerProfileId, serviceId: s.serviceId);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service removed')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = priceCtrl.text.trim();
              final duration = int.tryParse(durationCtrl.text.trim()) ?? s.durationMinutes;
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final fs = ref.read(firestoreServiceProvider);
              if (fs == null) return;
              try {
                await fs.updateService(providerProfileId: providerProfileId, serviceId: s.serviceId, name: name, price: price, durationMinutes: duration);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service updated')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.providerProfileId, required this.onTap});

  final Service service;
  final String providerProfileId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = service.durationMinutes >= 60 ? '${service.durationMinutes ~/ 60} hr' : '${service.durationMinutes} min';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(service.name),
        subtitle: Text('${service.price} · $duration'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
