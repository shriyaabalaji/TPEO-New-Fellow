import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/tag_options.dart';
import '../auth/auth_controller.dart';
import 'provider_account_controller.dart';
import 'view_mode_provider.dart';

/// Business setup page: add your one business (provider profile).
/// Shown when a service provider has no business yet (e.g. after onboarding).
class BusinessSetupPage extends ConsumerStatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  ConsumerState<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends ConsumerState<BusinessSetupPage> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _selectedTags = <String>[];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final firebaseUser = ref.read(authStateProvider).valueOrNull;
    final fs = ref.read(firestoreServiceProvider);
    if (firebaseUser == null || fs == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in and Firebase are required.')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider)?.reloadUser();
      final id = await fs.createProviderProfile(
        ownerUid: firebaseUser.uid,
        businessName: name,
        tags: _selectedTags.isEmpty ? null : List<String>.from(_selectedTags),
      );
      await fs.setActiveProviderProfile(uid: firebaseUser.uid, providerProfileId: id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business successfully added')),
        );
        ref.read(viewingAsProviderProvider.notifier).state = true;
        context.go('/profile');
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message.isEmpty ? 'You already have a business.' : e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase().contains('permission') || e.toString().contains('PERMISSION_DENIED')
            ? 'Permission denied. Try signing out and back in.'
            : 'Failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add your business',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Every service provider has one business. You can add multiple services from My Services later.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a business name';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Categories (optional)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tagOptions.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _addBusiness,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add Business'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
