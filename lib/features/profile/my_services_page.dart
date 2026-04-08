import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/storage/storage_service.dart';
import '../../core/ui/page_title.dart';
import '../../models/service.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

final Set<String> _openedInitialEditServiceIds = <String>{};

class MyServicesPage extends ConsumerWidget {
  const MyServicesPage({super.key, this.initialEditServiceId});

  final String? initialEditServiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(context, title: 'My Services'),
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
                  final initialServiceId = initialEditServiceId;
                  if (initialServiceId != null &&
                      !_openedInitialEditServiceIds.contains(initialServiceId)) {
                    Service? serviceToEdit;
                    for (final s in list) {
                      if (s.serviceId == initialServiceId) {
                        serviceToEdit = s;
                        break;
                      }
                    }
                    if (serviceToEdit != null) {
                      _openedInitialEditServiceIds.add(initialServiceId);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _openServiceEditorPage(
                          context,
                          ref,
                          providerProfileId: activeId,
                          service: serviceToEdit,
                        );
                      });
                    }
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...list.map((s) => _ServiceCard(
                            service: s,
                            providerProfileId: activeId,
                            onTap: () => _openServiceEditorPage(
                              context,
                              ref,
                              providerProfileId: activeId,
                              service: s,
                            ),
                          )),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _openServiceEditorPage(
                          context,
                          ref,
                          providerProfileId: activeId,
                        ),
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

  Future<void> _openServiceEditorPage(
    BuildContext context,
    WidgetRef ref, {
    required String providerProfileId,
    Service? service,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ServiceEditorPage(
          providerProfileId: providerProfileId,
          service: service,
        ),
      ),
    );
  }

}

class _ServiceEditorPage extends ConsumerStatefulWidget {
  const _ServiceEditorPage({
    required this.providerProfileId,
    this.service,
  });

  final String providerProfileId;
  final Service? service;

  @override
  ConsumerState<_ServiceEditorPage> createState() => _ServiceEditorPageState();
}

class _ServiceEditorPageState extends ConsumerState<_ServiceEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _pricingDescCtrl;
  late final TextEditingController _durationCtrl;

  File? _bannerFile;
  List<File> _galleryFiles = [];
  bool _saving = false;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _priceCtrl = TextEditingController(text: s?.price ?? '');
    _pricingDescCtrl = TextEditingController(text: s?.pricingDescription ?? '');
    _durationCtrl = TextEditingController(
      text: s != null ? '${s.durationMinutes}' : '30',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _pricingDescCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final xFile =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile != null && mounted) {
      setState(() => _bannerFile = File(xFile.path));
    }
  }

  Future<void> _pickGallery() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (!mounted || files.isEmpty) return;
    setState(() {
      _galleryFiles = [
        ..._galleryFiles,
        ...files.map((x) => File(x.path)),
      ];
      if (_galleryFiles.length > 7) {
        _galleryFiles = _galleryFiles.take(7).toList();
      }
    });
  }

  Future<void> _save() async {
    final fs = ref.read(firestoreServiceProvider);
    final storage = ref.read(storageServiceProvider);
    if (fs == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final price = _priceCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;

    setState(() => _saving = true);
    try {
      String? bannerUrl = widget.service?.bannerUrl;
      var galleryUrls = List<String>.from(widget.service?.galleryUrls ?? <String>[]);

      if (_isEdit) {
        if (_bannerFile != null && storage != null && storage.isAvailable) {
          bannerUrl = await storage.uploadServiceBanner(
            widget.providerProfileId,
            widget.service!.serviceId,
            _bannerFile!,
          );
        }
        if (_galleryFiles.isNotEmpty && storage != null && storage.isAvailable) {
          for (final file in _galleryFiles) {
            final url = await storage.uploadProviderGalleryImage(
              widget.providerProfileId,
              file,
              name: 'service-${widget.service!.serviceId}-${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            if (url != null) galleryUrls.add(url);
          }
        }
        await fs.updateService(
          providerProfileId: widget.providerProfileId,
          serviceId: widget.service!.serviceId,
          name: name,
          price: price,
          durationMinutes: duration,
          bannerUrl: bannerUrl,
          description: _descCtrl.text.trim(),
          pricingDescription: _pricingDescCtrl.text.trim(),
          galleryUrls: galleryUrls.take(7).toList(),
        );
      } else {
        final serviceId = await fs.addService(
          providerProfileId: widget.providerProfileId,
          name: name,
          price: price,
          durationMinutes: duration,
          description: _descCtrl.text.trim(),
          pricingDescription: _pricingDescCtrl.text.trim(),
        );

        if (_bannerFile != null && storage != null && storage.isAvailable) {
          bannerUrl = await storage.uploadServiceBanner(
            widget.providerProfileId,
            serviceId,
            _bannerFile!,
          );
        }

        if (_galleryFiles.isNotEmpty && storage != null && storage.isAvailable) {
          for (final file in _galleryFiles) {
            final url = await storage.uploadProviderGalleryImage(
              widget.providerProfileId,
              file,
              name: 'service-$serviceId-${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            if (url != null) galleryUrls.add(url);
          }
        }

        await fs.updateService(
          providerProfileId: widget.providerProfileId,
          serviceId: serviceId,
          name: name,
          price: price,
          durationMinutes: duration,
          bannerUrl: bannerUrl,
          description: _descCtrl.text.trim(),
          pricingDescription: _pricingDescCtrl.text.trim(),
          galleryUrls: galleryUrls.take(7).toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Service updated' : 'Service added')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingGalleryCount = widget.service?.galleryUrls?.length ?? 0;
    final totalGalleryCount = (existingGalleryCount + _galleryFiles.length).clamp(0, 7);
    final currentBanner = widget.service?.bannerUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SubpageCircleBackButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: primaryPageTitle(_isEdit ? 'Edit Service' : 'Create Service'),
        titleSpacing: 4,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text('Banner Photo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 145,
                  width: double.infinity,
                  child: _bannerFile != null
                      ? Image.file(_bannerFile!, fit: BoxFit.cover)
                      : (currentBanner != null && currentBanner.isNotEmpty)
                          ? Image.network(currentBanner, fit: BoxFit.cover)
                          : Container(color: const Color(0xFFF3F3F3)),
                ),
                ElevatedButton.icon(
                  onPressed: _pickBanner,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Upload Photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F343A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Service Name'),
          _RoundedInput(controller: _nameCtrl, hint: 'xxx'),
          const SizedBox(height: 12),
          _FieldLabel(label: 'Service Description'),
          _RoundedInput(controller: _descCtrl, hint: 'xxx', maxLines: 3),
          const SizedBox(height: 12),
          _FieldLabel(label: 'Pricing Range'),
          _RoundedInput(controller: _priceCtrl, hint: 'xxx'),
          const SizedBox(height: 12),
          _FieldLabel(label: 'Pricing Description'),
          _RoundedInput(controller: _pricingDescCtrl, hint: 'xxx'),
          const SizedBox(height: 12),
          _FieldLabel(label: 'Duration (minutes)'),
          _RoundedInput(
            controller: _durationCtrl,
            hint: '30',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Gallery Photos', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('($totalGalleryCount/7)', style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: totalGalleryCount >= 7 ? null : _pickGallery,
              icon: const Icon(Icons.add),
              label: const Text('Upload Photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F343A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save' : 'Create Service'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _RoundedInput extends StatelessWidget {
  const _RoundedInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black87),
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
              isThreeLine: service.reviewCount > 0,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${service.price} · $duration'),
                  if (service.reviewCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amber[800]),
                        const SizedBox(width: 4),
                        Text(
                          '${service.ratingAvg.toStringAsFixed(1)} (${service.reviewCount} reviews)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
