import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/storage/storage_service.dart';
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/profile')),
        title: const Text('My Services'),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(
                child: Text('Sign in to manage your services.'));
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
                return const Center(
                    child: Text(
                        'Create a provider profile from Profile first.'));
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
                            onTap: () => _showEditServiceDialog(
                                context, ref, activeId, s),
                          )),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showAddServiceDialog(context, ref, activeId),
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

  void _showAddServiceDialog(
      BuildContext context, WidgetRef ref, String providerProfileId) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: r'$20');
    final durationCtrl = TextEditingController(text: '30');
    File? bannerFile;
    final storage = ref.read(storageServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Service name')),
                const SizedBox(height: 12),
                TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                        labelText: r'Price (e.g. $25)')),
                const SizedBox(height: 12),
                TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Duration (minutes)')),
                const SizedBox(height: 16),
                Text('Service Banner',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (bannerFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(bannerFile!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                if (storage != null && storage.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 20),
                      label: Text(bannerFile == null
                          ? 'Add banner'
                          : 'Change banner'),
                      onPressed: () async {
                        final xFile = await ImagePicker().pickImage(
                            source: ImageSource.gallery, imageQuality: 85);
                        if (xFile != null && ctx.mounted) {
                          setState(() => bannerFile = File(xFile.path));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = priceCtrl.text.trim();
                final duration =
                    int.tryParse(durationCtrl.text.trim()) ?? 30;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final fs = ref.read(firestoreServiceProvider);
                if (fs == null) return;
                try {
                  final serviceId = await fs.addService(
                    providerProfileId: providerProfileId,
                    name: name,
                    price: price,
                    durationMinutes: duration,
                  );
                  if (bannerFile != null &&
                      storage != null &&
                      storage.isAvailable) {
                    final bannerUrl = await storage.uploadServiceBanner(
                        providerProfileId, serviceId, bannerFile!);
                    if (bannerUrl != null) {
                      await fs.updateService(
                        providerProfileId: providerProfileId,
                        serviceId: serviceId,
                        name: name,
                        price: price,
                        durationMinutes: duration,
                        bannerUrl: bannerUrl,
                      );
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Service successfully added')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref,
      String providerProfileId, Service s) {
    final nameCtrl = TextEditingController(text: s.name);
    final priceCtrl = TextEditingController(text: s.price);
    final durationCtrl = TextEditingController(text: '${s.durationMinutes}');
    File? bannerFile;
    String? existingBannerUrl = s.bannerUrl;
    final storage = ref.read(storageServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Service name')),
                const SizedBox(height: 12),
                TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Price')),
                const SizedBox(height: 12),
                TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Duration (minutes)')),
                const SizedBox(height: 16),
                Text('Service Banner',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (bannerFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(bannerFile!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  )
                else if (existingBannerUrl != null &&
                    existingBannerUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(existingBannerUrl,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                if (storage != null && storage.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 20),
                      label: Text(
                          bannerFile == null && existingBannerUrl == null
                              ? 'Add banner'
                              : 'Change banner'),
                      onPressed: () async {
                        final xFile = await ImagePicker().pickImage(
                            source: ImageSource.gallery, imageQuality: 85);
                        if (xFile != null && ctx.mounted) {
                          setState(() => bannerFile = File(xFile.path));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final fs = ref.read(firestoreServiceProvider);
                if (fs == null) return;
                try {
                  await fs.deleteService(
                      providerProfileId: providerProfileId,
                      serviceId: s.serviceId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Service successfully deleted')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: Text('Delete',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = priceCtrl.text.trim();
                final duration =
                    int.tryParse(durationCtrl.text.trim()) ??
                        s.durationMinutes;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final fs = ref.read(firestoreServiceProvider);
                if (fs == null) return;
                try {
                  String? bannerUrl = existingBannerUrl;
                  if (bannerFile != null &&
                      storage != null &&
                      storage.isAvailable) {
                    bannerUrl = await storage.uploadServiceBanner(
                        providerProfileId, s.serviceId, bannerFile!);
                  }
                  await fs.updateService(
                    providerProfileId: providerProfileId,
                    serviceId: s.serviceId,
                    name: name,
                    price: price,
                    durationMinutes: duration,
                    bannerUrl: bannerUrl,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Service successfully updated')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard(
      {required this.service,
      required this.providerProfileId,
      required this.onTap});

  final Service service;
  final String providerProfileId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = service.durationMinutes >= 60
        ? '${service.durationMinutes ~/ 60} hr'
        : '${service.durationMinutes} min';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (service.bannerUrl != null && service.bannerUrl!.isNotEmpty)
              Image.network(
                service.bannerUrl!,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 120, color: Colors.grey.shade200),
              )
            else
              Container(
                height: 80,
                color: Colors.grey.shade100,
                child: Icon(Icons.image_outlined,
                    size: 32, color: Colors.grey.shade400),
              ),
            ListTile(
              title: Text(service.name),
              subtitle: Text('${service.price} · $duration'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
