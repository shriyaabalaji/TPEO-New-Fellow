import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../../core/calendar/calendar_providers.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';
import 'view_mode_provider.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final pageTitle =
        viewingAsProvider ? 'Seller Account Details' : 'Customer Account Details';

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null) {
          return _scaffold(
            context,
            title: pageTitle,
            body: const Center(child: Text('Not signed in')),
          );
        }
        if (appUser.isDemo || fs == null) {
          return _scaffold(
            context,
            title: pageTitle,
            body:             _AccountForm(
              displayName: appUser.displayName,
              photoUrl: appUser.photoUrl,
              uid: null,
              fs: null,
              calendarGoogleEmail: null,
            ),
          );
        }
        return StreamBuilder<UserProfile>(
          stream: fs.streamUserProfile(appUser.uid),
          builder: (context, snap) {
            final userProfile = snap.data;
            return _scaffold(
              context,
              title: pageTitle,
              body: _AccountForm(
                displayName: userProfile?.displayName ?? appUser.displayName,
                photoUrl: userProfile?.photoUrl ?? appUser.photoUrl,
                uid: appUser.uid,
                fs: fs,
                calendarGoogleEmail: userProfile?.calendarGoogleEmail,
              ),
            );
          },
        );
      },
      loading: () => _scaffold(
        context,
        title: pageTitle,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _scaffold(
        context,
        title: pageTitle,
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _scaffold(BuildContext context, {required String title, required Widget body}) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(context, title: title),
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
    this.calendarGoogleEmail,
  });

  final String displayName;
  final String? photoUrl;
  final String? uid;
  final FirestoreService? fs;
  final String? calendarGoogleEmail;

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
            child: SizedBox(
              width: 112,
              height: 112,
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
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

          if (uid != null && fs != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Google Calendar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with a personal Google account to add bookings to that calendar. Your campus login stays the same.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
            ),
            const SizedBox(height: 12),
            if ((calendarGoogleEmail ?? '').isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _connectGoogleCalendar(context, ref, uid!, fs!),
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  label: const Text('Connect Google Calendar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      calendarGoogleEmail!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _disconnectGoogleCalendar(context, ref, uid!, fs!),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],

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

  Future<void> _connectGoogleCalendar(
    BuildContext context,
    WidgetRef ref,
    String uid,
    FirestoreService fs,
  ) async {
    final cal = ref.read(googleCalendarServiceProvider);
    try {
      final account = await cal.signInAndAuthorize();
      final email = account.email;
      if (email.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No email on Google account')),
          );
        }
        return;
      }
      await fs.setCalendarGoogleConnection(uid: uid, googleEmail: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar connected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect: $e')),
        );
      }
    }
  }

  Future<void> _disconnectGoogleCalendar(
    BuildContext context,
    WidgetRef ref,
    String uid,
    FirestoreService fs,
  ) async {
    try {
      await ref.read(googleCalendarServiceProvider).disconnect();
      await fs.clearCalendarGoogleConnection(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar disconnected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not disconnect: $e')),
        );
      }
    }
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
