import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/user_profile.dart';
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
          return _scaffold(context, body: const Center(child: Text('Not signed in')));
        }
        if (appUser.isDemo || fs == null) {
          return _scaffold(
            context,
            body: _AccountForm(
              displayName: appUser.displayName,
              photoUrl: appUser.photoUrl,
              uid: null,
              fs: null,
            ),
          );
        }
        return StreamBuilder<UserProfile>(
          stream: fs.streamUserProfile(appUser.uid),
          builder: (context, snap) {
            final userProfile = snap.data;
            return _scaffold(
              context,
              body: _AccountForm(
                displayName: userProfile?.displayName ?? appUser.displayName,
                photoUrl: userProfile?.photoUrl ?? appUser.photoUrl,
                uid: appUser.uid,
                fs: fs,
              ),
            );
          },
        );
      },
      loading: () => _scaffold(context, body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => _scaffold(context, body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _scaffold(BuildContext context, {required Widget body}) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const Text(
          'Account Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: body,
    );
  }
}

class _AccountForm extends ConsumerWidget {
  const _AccountForm({
    required this.displayName,
    required this.photoUrl,
    required this.uid,
    required this.fs,
  });

  final String displayName;
  final String? photoUrl;
  final String? uid;
  final FirestoreService? fs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = displayName.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Profile photo
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 48, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: uid != null && fs != null
                          ? () => _pickPhoto(context, ref)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Edit Profile',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // First Name
          _ReadonlyField(
            label: 'First Name',
            value: firstName,
            onTap: uid != null && fs != null
                ? () => _showEditNameDialog(context, ref, uid!, displayName, fs!)
                : null,
          ),

          const SizedBox(height: 20),

          // Last Name
          _ReadonlyField(
            label: 'Last Name',
            value: lastName,
            onTap: uid != null && fs != null
                ? () => _showEditNameDialog(context, ref, uid!, displayName, fs!)
                : null,
          ),

          const SizedBox(height: 32),

          // Stats
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Appointments Attended',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '0',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Total Late Cancellations (< 24h)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '0',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    if (uid == null || fs == null) return;
    final storage = ref.read(storageServiceProvider);
    if (storage == null || !storage.isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo upload not available')),
        );
      }
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading photo...')));
    try {
      final url = await storage.uploadUserAvatar(uid!, File(xFile.path));
      if (url == null || !context.mounted) return;
      await fs!.updateUserProfile(uid: uid!, photoUrl: url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String currentName,
    FirestoreService fs,
  ) {
    final parts = currentName.trim().split(' ');
    final firstCtrl = TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    final lastCtrl = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstCtrl,
              decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastCtrl,
              decoration: const InputDecoration(labelText: 'Last name', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final first = firstCtrl.text.trim();
              final last = lastCtrl.text.trim();
              final name = last.isNotEmpty ? '$first $last' : first;
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              try {
                await fs.updateUserProfile(uid: uid, displayName: name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
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
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value.isNotEmpty ? value : '—',
              style: TextStyle(
                fontSize: 15,
                color: value.isNotEmpty ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
