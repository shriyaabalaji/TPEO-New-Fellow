import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/tag_options.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/provider_profile.dart';
import '../../widgets/image_lightbox.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

/// Business Profile page: view and edit the service provider's single business.
class BusinessProfilePage extends ConsumerWidget {
  const BusinessProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);
    final profilesAsync = ref.watch(currentUserProviderProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(child: Text('Sign in to manage your business.'));
          }
          if (fs == null) {
            return const Center(child: Text('Firebase not configured.'));
          }
          return profilesAsync.when(
            data: (profiles) {
              if (profiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('You don\'t have a business yet.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/profile/business-setup'),
                        child: const Text('Set up your business'),
                      ),
                    ],
                  ),
                );
              }
              final business = profiles.single;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (business.bannerUrl != null && business.bannerUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () => showImageLightbox(
                            context,
                            Image.network(business.bannerUrl!, fit: BoxFit.contain),
                          ),
                          child: Image.network(
                            business.bannerUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.store,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      business.businessName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (business.about != null && business.about!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        business.about!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (business.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: business.tags.map((t) => Chip(label: Text(t))).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showEditBusinessDialog(context, ref, appUser.uid, business, fs),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Business Profile'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/profile/team'),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Edit Team'),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

void _showEditBusinessDialog(
  BuildContext context,
  WidgetRef ref,
  String uid,
  ProviderProfile p,
  FirestoreService fs,
) {
  final nameCtrl = TextEditingController(text: p.businessName);
  var selectedTags = List<String>.from(p.tags);
  String? bannerUrl = p.bannerUrl;
  File? bannerFile;
  List<String> galleryUrls = List<String>.from(p.galleryUrls ?? []);
  final aboutCtrl = TextEditingController(text: p.about ?? '');
  final newGalleryFiles = <File>[];
  final storage = ref.read(storageServiceProvider);

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Edit Business Profile'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Business name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('Banner', style: Theme.of(context).textTheme.titleSmall),
                if (bannerFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(bannerFile!, height: 80, width: double.infinity, fit: BoxFit.cover),
                  )
                else if (bannerUrl != null && bannerUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(bannerUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
                  ),
                if (storage != null && storage.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 20),
                      label: Text(bannerUrl == null && bannerFile == null ? 'Add banner' : 'Change banner'),
                      onPressed: () async {
                        final xFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (xFile != null && ctx.mounted) setState(() => bannerFile = File(xFile.path));
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Text('About', style: Theme.of(context).textTheme.titleSmall),
                TextField(
                  controller: aboutCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tell customers about your business.',
                    border: OutlineInputBorder(),
                  ),
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
                            selectedTags = List.from(selectedTags)..remove(tag);
                          } else {
                            selectedTags = List.from(selectedTags)..add(tag);
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                String? bannerUrlToSave = bannerUrl;
                if (bannerFile != null && storage != null && storage.isAvailable) {
                  bannerUrlToSave = await storage.uploadProviderBanner(p.providerProfileId, bannerFile!);
                }
                final updatedGalleryUrls = List<String>.from(galleryUrls);
                if (storage != null && storage.isAvailable && newGalleryFiles.isNotEmpty) {
                  for (final f in newGalleryFiles) {
                    final url = await storage.uploadProviderGalleryImage(p.providerProfileId, f);
                    if (url != null) updatedGalleryUrls.add(url);
                  }
                }
                await fs.updateProviderProfile(
                  providerProfileId: p.providerProfileId,
                  ownerUid: uid,
                  businessName: name,
                  tags: selectedTags,
                  bannerUrl: bannerUrlToSave,
                  galleryUrls: updatedGalleryUrls,
                  about: aboutCtrl.text.trim().isEmpty ? null : aboutCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business successfully updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
